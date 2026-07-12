from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.transport.bookings.schemas import BookingCreate, BookingResponse
from app.modules.transport.bookings.service import BookingService
from app.modules.transport.seats.schemas import TripSeatResponse
from app.modules.transport.seats.service import SeatService
from app.modules.transport.trips.schemas import TripCreate, TripResponse
from app.modules.transport.trips.service import TripService

router = APIRouter(
    prefix="/trips",
    tags=["Trips"],
)

service = TripService()
seat_service = SeatService()
booking_service = BookingService()


@router.post("/", response_model=TripResponse)
async def create_trip(
    data: TripCreate,
    current_user=Depends(require_permission("trips:manage")),
):
    return await service.create_trip(
        data,
        current_user["sub"],
    )


@router.get("/", response_model=list[TripResponse])
async def get_trips(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    company_id: Optional[str] = None,
    route_id: Optional[str] = None,
    travel_date: Optional[date] = None,
    status: Optional[str] = None,
):
    return await service.get_trips(
        page=page,
        limit=limit,
        company_id=company_id,
        route_id=route_id,
        travel_date=travel_date,
        status=status,
    )


@router.get("/{trip_id}", response_model=TripResponse)
async def get_trip(trip_id: str):
    return await service.get_trip(trip_id)


@router.get("/{trip_id}/seats", response_model=list[TripSeatResponse])
async def get_trip_seats(trip_id: str):
    return await seat_service.get_trip_seats(trip_id)


@router.post("/{trip_id}/bookings", response_model=BookingResponse)
async def create_booking(
    trip_id: str,
    data: BookingCreate,
    current_user=Depends(get_current_user),
):
    return await booking_service.create_booking(trip_id, data, current_user["sub"])


@router.put("/{trip_id}", response_model=TripResponse)
async def update_trip(
    trip_id: str,
    data: TripCreate,
    current_user=Depends(require_permission("trips:manage")),
):
    return await service.update_trip(
        trip_id,
        data,
        current_user["sub"],
    )


@router.delete("/{trip_id}")
async def delete_trip(
    trip_id: str,
    current_user=Depends(require_permission("trips:manage")),
):
    return await service.delete_trip(
        trip_id,
        current_user["sub"],
    )