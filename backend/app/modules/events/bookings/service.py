from datetime import timedelta

from bson import ObjectId
from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.config import settings
from app.core.utils import utc_now
from app.modules.events.bookings.repository import EventBookingRepository
from app.modules.events.bookings.schemas import EventBookingCreate
from app.modules.events.ticket_types.repository import TicketTypeRepository


class TicketsNotAvailableException(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail="Not enough tickets available for this request.",
        )


class EventBookingService:
    def __init__(self):
        self.repository = EventBookingRepository()
        self.ticket_type_repository = TicketTypeRepository()

    async def create_booking(self, ticket_type_id: str, data: EventBookingCreate, passenger_id: str):
        ticket_type = await self.ticket_type_repository.get_by_id(ticket_type_id)

        if not ticket_type:
            raise HTTPException(status_code=404, detail="Ticket type not found.")

        # Release any abandoned PENDING_PAYMENT holds on this ticket type
        # before attempting a new claim - same lazy-expiration approach
        # as transport/hotels (no background worker).
        await self.expire_stale_bookings(ticket_type_id)

        now = utc_now()
        booking_id = ObjectId()

        # The atomic guarantee: a single compare-and-decrement on the
        # ticket type's own quantity_available field. Unlike seats or
        # room-nights, a ticket has no identity before purchase - it's
        # pure inventory - so there's nothing to claim per-unit; the
        # counter itself is the thing being atomically checked and
        # decremented in one document operation.
        claimed = await self.ticket_type_repository.claim_tickets(ticket_type_id, data.quantity)

        if not claimed:
            raise TicketsNotAvailableException()

        # Price is computed and stored on the booking now, so it stays
        # historically accurate even if the ticket type's base_price
        # changes later.
        price_paid = round(ticket_type["base_price"] * data.quantity, 2)

        booking_doc = {
            "_id": booking_id,
            "event_id": ticket_type["event_id"],
            "ticket_type_id": ticket_type_id,
            "passenger_id": passenger_id,
            "quantity": data.quantity,
            "price_paid": price_paid,
            "status": "PENDING_PAYMENT",
            "expires_at": now + timedelta(minutes=settings.BOOKING_PAYMENT_TIMEOUT_MINUTES),
        }
        booking_doc.update(BaseDocument.create())

        try:
            booking = await self.repository.create(booking_doc)
        except Exception:
            # Tickets were claimed but recording the booking failed -
            # release them so they don't stay stuck unavailable.
            await self.ticket_type_repository.release_tickets(ticket_type_id, data.quantity)
            raise

        return self._format(booking)

    async def cancel_booking(self, booking_id: str, passenger_id: str):
        booking = await self.repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        if booking["passenger_id"] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] in ("CANCELLED", "EXPIRED"):
            raise HTTPException(
                status_code=400,
                detail=f"Booking is already {booking['status'].lower()}.",
            )

        cancelled = await self.repository.transition_status_if(
            booking_id,
            ["PENDING_PAYMENT", "CONFIRMED"],
            {"status": "CANCELLED", **BaseDocument.update()},
        )

        if not cancelled:
            raise HTTPException(status_code=400, detail="Booking is already cancelled or expired.")

        await self.ticket_type_repository.release_tickets(booking["ticket_type_id"], booking["quantity"])

        return self._format(await self.repository.get_by_id(booking_id))

    async def expire_stale_bookings(self, ticket_type_id: str):
        stale_bookings = await self.repository.get_stale_pending_bookings(ticket_type_id, utc_now())

        for booking in stale_bookings:
            booking_id = str(booking["_id"])

            expired = await self.repository.transition_status_if(
                booking_id,
                "PENDING_PAYMENT",
                {"status": "EXPIRED", **BaseDocument.update()},
            )

            if not expired:
                continue

            await self.ticket_type_repository.release_tickets(
                booking["ticket_type_id"], booking["quantity"]
            )

    async def get_my_bookings(self, passenger_id: str, page: int, limit: int):
        bookings = await self.repository.get_by_passenger(passenger_id, page, limit)
        return [self._format(booking) for booking in bookings]

    def _format(self, booking):
        return {
            "id": str(booking["_id"]),
            "event_id": booking["event_id"],
            "ticket_type_id": booking["ticket_type_id"],
            "passenger_id": booking["passenger_id"],
            "quantity": booking["quantity"],
            "price_paid": booking["price_paid"],
            "status": booking["status"],
            "expires_at": booking.get("expires_at"),
            "created_at": booking.get("created_at"),
            "updated_at": booking.get("updated_at"),
        }
