import secrets

from bson import ObjectId
from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError

from app.common.base_model import BaseDocument
from app.core.constants import UserRole
from app.core.utils import utc_now
from app.identity.users.repository import UserRepository
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.bookings.repository import BookingRepository
from app.modules.transport.drivers.repository import DriverRepository
from app.modules.transport.seats.repository import SeatRepository
from app.modules.transport.tickets.repository import TicketRepository
from app.modules.transport.trips.repository import TripRepository

# Ambiguous-looking characters (0/O, 1/I) stripped, since this is also
# meant to be readable off the ticket screen if the QR scan ever fails.
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_CODE_LENGTH = 10


def _generate_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


class TicketService:
    def __init__(self):
        self.repository = TicketRepository()
        self.booking_repository = BookingRepository()
        self.trip_repository = TripRepository()
        self.driver_repository = DriverRepository()
        self.company_repository = CompanyRepository()
        self.user_repository = UserRepository()
        self.seat_repository = SeatRepository()

    async def issue_for_booking(self, booking: dict):
        """Called once a booking transitions to CONFIRMED (see
        payments/service.py::complete_sandbox_payment) - not exposed
        through any route. Idempotent: a booking that already has a
        ticket (e.g. this got called twice for the same confirmation)
        just returns the existing one instead of issuing a second."""
        booking_id = str(booking["_id"])
        existing = await self.repository.get_by_booking(booking_id)

        if existing:
            return existing

        code = _generate_code()

        # 32^10 keyspace - a collision is vanishingly unlikely, but
        # checked and retried rather than trusted blindly, since `code`
        # carries a unique index.
        for _ in range(3):
            if not await self.repository.get_by_code(code):
                break
            code = _generate_code()

        ticket_doc = {
            "_id": ObjectId(),
            "booking_id": booking_id,
            "trip_id": booking["trip_id"],
            "seat_id": booking["seat_id"],
            "passenger_id": booking["passenger_id"],
            "code": code,
            "status": "VALID",
            "used_at": None,
        }
        ticket_doc.update(BaseDocument.create())

        try:
            return await self.repository.create(ticket_doc)
        except DuplicateKeyError:
            # Another concurrent call already issued this booking's
            # ticket (or a code collision survived the retries above,
            # in which case booking_id's own unique index is what
            # actually saved us) - either way, the record that matters
            # is whichever one is now on file for this booking.
            return await self.repository.get_by_booking(booking_id)

    async def get_ticket_for_booking(self, booking_id: str, passenger_id: str):
        booking = await self.booking_repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        if booking["passenger_id"] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] != "CONFIRMED":
            raise HTTPException(
                status_code=400,
                detail="This booking is not confirmed yet - no ticket has been issued.",
            )

        ticket = await self.repository.get_by_booking(booking_id)

        if not ticket:
            raise HTTPException(status_code=404, detail="No ticket found for this booking.")

        return self._format(ticket)

    async def validate_ticket(self, code: str, current_user_id: str, current_user_role: str):
        ticket = await self.repository.get_by_code(code)

        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found.")

        trip = await self.trip_repository.get_by_id(ticket["trip_id"])

        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found for this ticket.")

        await self._ensure_can_validate(trip, current_user_id, current_user_role)

        if ticket["status"] == "USED":
            raise HTTPException(status_code=400, detail="This ticket has already been used.")

        if ticket["status"] == "CANCELLED":
            raise HTTPException(status_code=400, detail="This ticket has been cancelled.")

        validated = await self.repository.transition_status_if(
            str(ticket["_id"]),
            "VALID",
            {"status": "USED", "used_at": utc_now(), **BaseDocument.update()},
        )

        if not validated:
            raise HTTPException(status_code=400, detail="This ticket has already been used.")

        validated_ticket = await self.repository.get_by_id(str(ticket["_id"]))
        passenger = await self.user_repository.get_by_id(validated_ticket["passenger_id"])
        seat = await self.seat_repository.get_by_id(validated_ticket["seat_id"])

        return {
            **self._format(validated_ticket),
            "passenger_name": f"{passenger['first_name']} {passenger['last_name']}" if passenger else "?",
            "seat_number": seat["seat_number"] if seat else "?",
        }

    async def _ensure_can_validate(self, trip: dict, user_id: str, role: str):
        """A driver or company_owner may only validate tickets for
        trips run by their own company - not scoped by require_role
        alone, which only checks the role itself."""
        if role == UserRole.SYSTEM_ADMINISTRATOR:
            return

        if role == UserRole.COMPANY_OWNER:
            company = await self.company_repository.get_by_id(trip["company_id"])

            if company and company["owner_id"] == user_id:
                return

        elif role == UserRole.DRIVER:
            driver = await self.driver_repository.get_by_user_id(user_id)

            if driver and driver["company_id"] == trip["company_id"]:
                return

        raise HTTPException(
            status_code=403,
            detail="You are not allowed to validate tickets for this trip.",
        )

    def _format(self, ticket):
        return {
            "id": str(ticket["_id"]),
            "booking_id": ticket["booking_id"],
            "trip_id": ticket["trip_id"],
            "seat_id": ticket["seat_id"],
            "passenger_id": ticket["passenger_id"],
            "code": ticket["code"],
            "status": ticket["status"],
            "used_at": ticket.get("used_at"),
            "created_at": ticket.get("created_at"),
            "updated_at": ticket.get("updated_at"),
        }
