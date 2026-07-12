from datetime import datetime, time

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.buses.repository import BusRepository
from app.modules.transport.drivers.repository import DriverRepository
from app.modules.transport.routes.repository import RouteRepository
from app.modules.transport.schedules.repository import ScheduleRepository
from app.modules.transport.trips.repository import TripRepository
from app.modules.transport.trips.schemas import TripCreate


class TripService:
    def __init__(self):
        self.repository = TripRepository()
        self.company_repository = CompanyRepository()
        self.route_repository = RouteRepository()
        self.schedule_repository = ScheduleRepository()
        self.bus_repository = BusRepository()
        self.driver_repository = DriverRepository()

    async def create_trip(self, data: TripCreate, user_id: str):
        company = await self.company_repository.get_by_id(data.company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="You are not allowed to create a trip for this company.",
            )

        route = await self.route_repository.get_by_id(data.route_id)

        if not route:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        if route["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Route does not belong to this company.",
            )

        schedule = await self.schedule_repository.get_by_id(data.schedule_id)

        if not schedule:
            raise HTTPException(
                status_code=404,
                detail="Schedule not found.",
            )

        if schedule["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Schedule does not belong to this company.",
            )

        if schedule["route_id"] != data.route_id:
            raise HTTPException(
                status_code=400,
                detail="Schedule does not belong to this route.",
            )

        bus = await self.bus_repository.get_by_id(data.bus_id)

        if not bus:
            raise HTTPException(
                status_code=404,
                detail="Bus not found.",
            )

        if bus["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Bus does not belong to this company.",
            )

        if bus.get("status") in {"MAINTENANCE", "OUT_OF_SERVICE"}:
            raise HTTPException(
                status_code=400,
                detail="This bus is not available for a trip.",
            )

        driver = await self.driver_repository.get_by_id(data.driver_id)

        if not driver:
            raise HTTPException(
                status_code=404,
                detail="Driver not found.",
            )

        if driver["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Driver does not belong to this company.",
            )

        if driver.get("status") not in {"AVAILABLE", "ON_TRIP"}:
            raise HTTPException(
                status_code=400,
                detail="This driver is not available for a trip.",
            )

        travel_datetime = datetime.combine(
            data.travel_date,
            time.min,
        )

        departure_time = schedule["departure_time"].time()

        departure_datetime = datetime.combine(
            data.travel_date,
            departure_time,
        )

        estimated_arrival_datetime = None

        if schedule.get("estimated_arrival_time"):
            arrival_time = schedule["estimated_arrival_time"].time()

            estimated_arrival_datetime = datetime.combine(
                data.travel_date,
                arrival_time,
            )

            # Si l'heure d'arrivée est inférieure ou égale à l'heure
            # de départ, le voyage arrive probablement le lendemain.
            if estimated_arrival_datetime <= departure_datetime:
                from datetime import timedelta

                estimated_arrival_datetime += timedelta(days=1)

        trip = data.model_dump()

        trip["travel_date"] = travel_datetime
        trip["departure_datetime"] = departure_datetime
        trip["estimated_arrival_datetime"] = estimated_arrival_datetime

        trip["available_seats"] = bus["seat_capacity"]
        trip["booked_seats"] = 0

        trip["status"] = trip["status"].value
        trip.update(BaseDocument.create())

        created_trip = await self.repository.create(trip)

        return self._format(created_trip)

    async def get_trips(
        self,
        page: int,
        limit: int,
        company_id: str | None,
        route_id: str | None,
        travel_date,
        status: str | None,
    ):
        converted_travel_date = None

        if travel_date:
            converted_travel_date = datetime.combine(
                travel_date,
                time.min,
            )

        trips = await self.repository.get_all(
            page=page,
            limit=limit,
            company_id=company_id,
            route_id=route_id,
            travel_date=converted_travel_date,
            status=status,
        )

        return [self._format(trip) for trip in trips]

    async def get_trip(self, trip_id: str):
        trip = await self.repository.get_by_id(trip_id)

        if not trip:
            raise HTTPException(
                status_code=404,
                detail="Trip not found.",
            )

        return self._format(trip)

    async def update_trip(
        self,
        trip_id: str,
        data: TripCreate,
        user_id: str,
    ):
        existing_trip = await self.repository.get_by_id(trip_id)

        if not existing_trip:
            raise HTTPException(
                status_code=404,
                detail="Trip not found.",
            )

        company = await self.company_repository.get_by_id(
            existing_trip["company_id"]
        )

        if not company or company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="You are not allowed to update this trip.",
            )

        route = await self.route_repository.get_by_id(data.route_id)

        if not route:
            raise HTTPException(
                status_code=404,
                detail="Route not found.",
            )

        if route["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Route does not belong to this company.",
            )

        schedule = await self.schedule_repository.get_by_id(data.schedule_id)

        if not schedule:
            raise HTTPException(
                status_code=404,
                detail="Schedule not found.",
            )

        if schedule["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Schedule does not belong to this company.",
            )

        if schedule["route_id"] != data.route_id:
            raise HTTPException(
                status_code=400,
                detail="Schedule does not belong to this route.",
            )

        bus = await self.bus_repository.get_by_id(data.bus_id)

        if not bus:
            raise HTTPException(
                status_code=404,
                detail="Bus not found.",
            )

        if bus["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Bus does not belong to this company.",
            )

        driver = await self.driver_repository.get_by_id(data.driver_id)

        if not driver:
            raise HTTPException(
                status_code=404,
                detail="Driver not found.",
            )

        if driver["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Driver does not belong to this company.",
            )

        update_data = data.model_dump()

        update_data["travel_date"] = datetime.combine(
            data.travel_date,
            time.min,
        )

        update_data["departure_datetime"] = datetime.combine(
            data.travel_date,
            schedule["departure_time"].time(),
        )

        update_data["estimated_arrival_datetime"] = None

        if schedule.get("estimated_arrival_time"):
            from datetime import timedelta

            arrival_datetime = datetime.combine(
                data.travel_date,
                schedule["estimated_arrival_time"].time(),
            )

            if arrival_datetime <= update_data["departure_datetime"]:
                arrival_datetime += timedelta(days=1)

            update_data["estimated_arrival_datetime"] = arrival_datetime

        update_data["status"] = update_data["status"].value
        update_data.update(BaseDocument.update())

        updated_trip = await self.repository.update(
            trip_id,
            update_data,
        )

        return self._format(updated_trip)

    async def delete_trip(self, trip_id: str, user_id: str):
        trip = await self.repository.get_by_id(trip_id)

        if not trip:
            raise HTTPException(
                status_code=404,
                detail="Trip not found.",
            )

        company = await self.company_repository.get_by_id(
            trip["company_id"]
        )

        if not company or company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="You are not allowed to delete this trip.",
            )

        if trip.get("booked_seats", 0) > 0:
            raise HTTPException(
                status_code=400,
                detail="A trip with existing bookings cannot be deleted.",
            )

        deleted = await self.repository.soft_delete(
            trip_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(
                status_code=404,
                detail="Trip not found.",
            )

        return {
            "message": "Trip deleted successfully."
        }

    def _format(self, trip):
        return {
            "id": str(trip["_id"]),
            "company_id": trip["company_id"],
            "route_id": trip["route_id"],
            "schedule_id": trip["schedule_id"],
            "bus_id": trip["bus_id"],
            "driver_id": trip["driver_id"],
            "travel_date": trip["travel_date"],
            "departure_datetime": trip["departure_datetime"],
            "estimated_arrival_datetime": trip.get(
                "estimated_arrival_datetime"
            ),
            "available_seats": trip["available_seats"],
            "booked_seats": trip["booked_seats"],
            "price": trip["price"],
            "status": trip["status"],
            "notes": trip.get("notes"),
            "is_active": trip["is_active"],
            "created_at": trip.get("created_at"),
            "updated_at": trip.get("updated_at"),
        }