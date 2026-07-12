from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.transport.trips.schemas import TripCreate, TripResponse
from app.modules.transport.trips.service import TripService

router = APIRouter(
    prefix="/trips",
    tags=["Trips"],
)

service = TripService()


@router.post("/", response_model=TripResponse)
async def create_trip(
    data: TripCreate,
    current_user=Depends(get_current_user),
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


@router.put("/{trip_id}", response_model=TripResponse)
async def update_trip(
    trip_id: str,
    data: TripCreate,
    current_user=Depends(get_current_user),
):
    return await service.update_trip(
        trip_id,
        data,
        current_user["sub"],
    )


@router.delete("/{trip_id}")
async def delete_trip(
    trip_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_trip(
        trip_id,
        current_user["sub"],
    )