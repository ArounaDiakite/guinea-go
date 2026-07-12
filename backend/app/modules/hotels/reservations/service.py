from datetime import datetime, time, timedelta

from bson import ObjectId
from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.config import settings
from app.core.utils import utc_now
from app.modules.hotels.reservations.repository import HotelBookingRepository
from app.modules.hotels.reservations.schemas import HotelBookingCreate
from app.modules.hotels.rooms.repository import RoomRepository


class RoomNotAvailableException(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail="This room is not available for the requested dates.",
        )


class HotelBookingService:
    def __init__(self):
        self.repository = HotelBookingRepository()
        self.room_repository = RoomRepository()

    async def create_booking(self, room_id: str, data: HotelBookingCreate, passenger_id: str):
        room = await self.room_repository.get_by_id(room_id)

        if not room:
            raise HTTPException(status_code=404, detail="Room not found.")

        if room["status"] == "MAINTENANCE":
            raise HTTPException(
                status_code=400,
                detail="This room is under maintenance and cannot be booked.",
            )

        # Release any abandoned PENDING_PAYMENT holds on this room before
        # checking availability - same lazy-expiration approach as
        # transport (no background worker).
        await self.expire_stale_bookings(room_id)

        if await self.repository.has_overlap(room_id, data.check_in, data.check_out):
            raise RoomNotAvailableException()

        nights = (data.check_out - data.check_in).days
        now = utc_now()
        booking_id = ObjectId()

        # The atomic guarantee: claim every night in the stay via the
        # room_nights unique index. If any single night is already taken
        # (including a race that slipped past has_overlap above), this
        # fails and nothing is left claimed.
        claimed = await self.repository.claim_nights(room_id, data.check_in, data.check_out, booking_id)

        if not claimed:
            raise RoomNotAvailableException()

        # Price is computed and stored on the booking now, so it stays
        # historically accurate even if the room's base_price changes later.
        price_paid = round(room["base_price"] * nights, 2)

        booking_doc = {
            "_id": booking_id,
            "hotel_id": room["hotel_id"],
            "room_id": room_id,
            "passenger_id": passenger_id,
            "check_in": datetime.combine(data.check_in, time.min),
            "check_out": datetime.combine(data.check_out, time.min),
            "nights": nights,
            "price_paid": price_paid,
            "status": "PENDING_PAYMENT",
            "expires_at": now + timedelta(minutes=settings.BOOKING_PAYMENT_TIMEOUT_MINUTES),
        }
        booking_doc.update(BaseDocument.create())

        try:
            booking = await self.repository.create(booking_doc)
        except Exception:
            # The nights were claimed but recording the booking failed -
            # release them so the room doesn't stay stuck unavailable.
            await self.repository.release_nights(str(booking_id))
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

        await self.repository.release_nights(str(booking["_id"]))

        return self._format(await self.repository.get_by_id(booking_id))

    async def expire_stale_bookings(self, room_id: str):
        stale_bookings = await self.repository.get_stale_pending_bookings(room_id, utc_now())

        for booking in stale_bookings:
            booking_id = str(booking["_id"])

            expired = await self.repository.transition_status_if(
                booking_id,
                "PENDING_PAYMENT",
                {"status": "EXPIRED", **BaseDocument.update()},
            )

            if not expired:
                continue

            await self.repository.release_nights(booking_id)

    async def get_my_bookings(self, passenger_id: str, page: int, limit: int):
        bookings = await self.repository.get_by_passenger(passenger_id, page, limit)
        return [self._format(booking) for booking in bookings]

    def _format(self, booking):
        return {
            "id": str(booking["_id"]),
            "hotel_id": booking["hotel_id"],
            "room_id": booking["room_id"],
            "passenger_id": booking["passenger_id"],
            "check_in": booking["check_in"].date(),
            "check_out": booking["check_out"].date(),
            "nights": booking["nights"],
            "price_paid": booking["price_paid"],
            "status": booking["status"],
            "expires_at": booking.get("expires_at"),
            "created_at": booking.get("created_at"),
            "updated_at": booking.get("updated_at"),
        }
