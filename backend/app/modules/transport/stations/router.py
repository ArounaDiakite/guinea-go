from typing import Optional

from fastapi import APIRouter, Query

from app.modules.transport.stations.schemas import StationCreate, StationResponse
from app.modules.transport.stations.service import StationService

router = APIRouter(
    prefix="/stations",
    tags=["Stations"],
)

service = StationService()


@router.post("/", response_model=StationResponse)
async def create_station(data: StationCreate):
    return await service.create_station(data)


@router.get("/", response_model=list[StationResponse])
async def get_stations(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    city: Optional[str] = None,
    station_type: Optional[str] = None,
):
    return await service.get_stations(page, limit, search, city, station_type)


@router.get("/{station_id}", response_model=StationResponse)
async def get_station(station_id: str):
    return await service.get_station(station_id)


@router.put("/{station_id}", response_model=StationResponse)
async def update_station(station_id: str, data: StationCreate):
    return await service.update_station(station_id, data)


@router.delete("/{station_id}")
async def delete_station(station_id: str):
    return await service.delete_station(station_id)