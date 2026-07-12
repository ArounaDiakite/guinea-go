from bson import ObjectId
from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.utils import utc_now
from app.modules.transport.bookings.repository import BookingRepository
from app.modules.transport.bookings.schemas import BookingCreate
from app.modules.transport.seats.repository import SeatRepository
from app.modules.transport.trips.repository import TripRepository


class SeatAlreadyReservedException(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail="This seat is already reserved for this trip.",
        )


class BookingService:
    def __init__(self):
        self.repository = BookingRepository()
        self.trip_repository = TripRepository()
        self.seat_repository = SeatRepository()

    async def create_booking(self, trip_id: str, data: BookingCreate, passenger_id: str):
        trip = await self.trip_repository.get_by_id(trip_id)

        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found.")

        seat = await self.seat_repository.get_by_id(data.seat_id)

        if not seat:
            raise HTTPException(status_code=404, detail="Seat not found.")

        if seat["bus_id"] != trip["bus_id"]:
            raise HTTPException(
                status_code=400,
                detail="This seat does not belong to this trip's bus.",
            )

        if seat["status"] == "MAINTENANCE":
            raise HTTPException(
                status_code=400,
                detail="This seat is under maintenance and cannot be booked.",
            )

        now = utc_now()
        booking_id = ObjectId()

        # The atomic compare-and-swap: whoever wins this claims the seat
        # for this specific trip. No read-then-write window here.
        claimed = await self.repository.claim_seat(trip_id, data.seat_id, booking_id, now)

        if claimed is None:
            raise SeatAlreadyReservedException()

        booking_doc = {
            "_id": booking_id,
            "trip_id": trip_id,
            "seat_id": data.seat_id,
            "passenger_id": passenger_id,
            "status": "CONFIRMED",
            "price_paid": trip["price"],
        }
        booking_doc.update(BaseDocument.create())

        try:
            booking = await self.repository.create(booking_doc)
        except Exception:
            # The seat claim succeeded but recording the booking failed -
            # release the claim so the seat doesn't get stuck RESERVED
            # with no booking behind it.
            await self.repository.release_seat(trip_id, data.seat_id, str(booking_id), utc_now())
            raise

        await self.trip_repository.increment_booked_seats(trip_id)

        return self._format(booking)

    async def cancel_booking(self, booking_id: str, passenger_id: str):
        booking = await self.repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        if booking["passenger_id"] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] == "CANCELLED":
            raise HTTPException(status_code=400, detail="Booking is already cancelled.")

        now = utc_now()

        await self.repository.release_seat(
            booking["trip_id"], booking["seat_id"], str(booking["_id"]), now
        )

        updated = await self.repository.update_status(
            booking_id,
            {"status": "CANCELLED", **BaseDocument.update()},
        )

        await self.trip_repository.decrement_booked_seats(booking["trip_id"])

        return self._format(updated)

    async def get_my_bookings(self, passenger_id: str, page: int, limit: int):
        bookings = await self.repository.get_by_passenger(passenger_id, page, limit)
        return [self._format(booking) for booking in bookings]

    def _format(self, booking):
        return {
            "id": str(booking["_id"]),
            "trip_id": booking["trip_id"],
            "seat_id": booking["seat_id"],
            "passenger_id": booking["passenger_id"],
            "status": booking["status"],
            "price_paid": booking["price_paid"],
            "created_at": booking.get("created_at"),
            "updated_at": booking.get("updated_at"),
        }
