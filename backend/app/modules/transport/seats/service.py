from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.bookings.repository import BookingRepository
from app.modules.transport.buses.repository import BusRepository
from app.modules.transport.seats.repository import SeatRepository
from app.modules.transport.seats.schemas import SeatStatus, SeatType
from app.modules.transport.trips.repository import TripRepository


class SeatService:
    def __init__(self):
        self.repository = SeatRepository()
        self.bus_repository = BusRepository()
        self.company_repository = CompanyRepository()
        self.trip_repository = TripRepository()
        self.booking_repository = BookingRepository()

    async def generate_seats(self, bus_id: str, user_id: str):
        bus = await self.bus_repository.get_by_id(bus_id)

        if not bus:
            raise HTTPException(status_code=404, detail="Bus not found.")

        company = await self.company_repository.get_by_id(bus["company_id"])

        if not company or company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        existing_seats = await self.repository.get_by_bus(bus_id)

        if existing_seats:
            raise HTTPException(
                status_code=400,
                detail="Seats have already been generated for this bus.",
            )

        seats = []

        for position in range(1, bus["seat_capacity"] + 1):
            seat = {
                "bus_id": bus_id,
                "company_id": bus["company_id"],
                "position": position,
                "seat_number": str(position),
                "seat_type": self._seat_type_for_position(position).value,
                "status": SeatStatus.AVAILABLE.value,
            }
            seat.update(BaseDocument.create())
            seats.append(seat)

        created_seats = await self.repository.create_many(seats)

        return [self._format(seat) for seat in created_seats]

    def _seat_type_for_position(self, position: int) -> SeatType:
        # Simple 2+aisle+2 layout: seats 1 and 4 of every group of 4 are
        # by the window, seats 2 and 3 are on the aisle.
        offset = (position - 1) % 4

        if offset in (0, 3):
            return SeatType.WINDOW

        return SeatType.AISLE

    async def get_bus_seats(self, bus_id: str):
        seats = await self.repository.get_by_bus(bus_id)
        return [self._format(seat) for seat in seats]

    async def get_trip_seats(self, trip_id: str):
        trip = await self.trip_repository.get_by_id(trip_id)

        if not trip:
            raise HTTPException(status_code=404, detail="Trip not found.")

        seats = await self.repository.get_by_bus(trip["bus_id"])
        reserved_seat_ids = await self.booking_repository.get_reserved_seat_ids(trip_id)

        result = []

        for seat in seats:
            seat_id = str(seat["_id"])

            if seat["status"] == SeatStatus.MAINTENANCE.value:
                # Out of service on every trip, regardless of bookings.
                trip_status = SeatStatus.MAINTENANCE.value
            elif seat_id in reserved_seat_ids:
                trip_status = SeatStatus.RESERVED.value
            else:
                trip_status = SeatStatus.AVAILABLE.value

            result.append(
                {
                    "seat_id": seat_id,
                    "seat_number": seat["seat_number"],
                    "seat_type": seat["seat_type"],
                    "status": trip_status,
                }
            )

        return result

    def _format(self, seat):
        return {
            "id": str(seat["_id"]),
            "bus_id": seat["bus_id"],
            "company_id": seat["company_id"],
            "seat_number": seat["seat_number"],
            "seat_type": seat["seat_type"],
            "status": seat["status"],
            "is_active": seat["is_active"],
            "created_at": seat.get("created_at"),
            "updated_at": seat.get("updated_at"),
        }
