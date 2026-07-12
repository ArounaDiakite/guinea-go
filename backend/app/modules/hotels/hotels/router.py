from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.hotels.hotels.schemas import HotelCreate, HotelResponse
from app.modules.hotels.hotels.service import HotelService

router = APIRouter(
    prefix="/hotels",
    tags=["Hotels"],
)

service = HotelService()


@router.post("/", response_model=HotelResponse)
async def create_hotel(
    data: HotelCreate,
    current_user=Depends(require_permission("hotels:manage")),
):
    return await service.create_hotel(data, current_user["sub"])


@router.get("/", response_model=list[HotelResponse])
async def get_hotels(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    city: Optional[str] = None,
):
    return await service.get_hotels(page, limit, search, city)


@router.get("/{hotel_id}", response_model=HotelResponse)
async def get_hotel(hotel_id: str):
    return await service.get_hotel(hotel_id)


@router.put("/{hotel_id}", response_model=HotelResponse)
async def update_hotel(
    hotel_id: str,
    data: HotelCreate,
    current_user=Depends(require_permission("hotels:manage")),
):
    return await service.update_hotel(hotel_id, data, current_user["sub"])


@router.delete("/{hotel_id}")
async def delete_hotel(
    hotel_id: str,
    current_user=Depends(require_permission("hotels:manage")),
):
    return await service.delete_hotel(hotel_id, current_user["sub"])
