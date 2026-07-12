from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.constants import UserRole
from app.core.dependencies import require_permission, require_role
from app.modules.hotels.reservations.schemas import HotelBookingCreate, HotelBookingResponse
from app.modules.hotels.reservations.service import HotelBookingService
from app.modules.hotels.rooms.schemas import RoomCreate, RoomResponse
from app.modules.hotels.rooms.service import RoomService

router = APIRouter(
    prefix="/rooms",
    tags=["Rooms"],
)

service = RoomService()
booking_service = HotelBookingService()


@router.post("/", response_model=RoomResponse)
async def create_room(
    data: RoomCreate,
    current_user=Depends(require_permission("rooms:manage")),
):
    return await service.create_room(data, current_user["sub"])


@router.get("/", response_model=list[RoomResponse])
async def get_rooms(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    hotel_id: Optional[str] = None,
    room_type: Optional[str] = None,
    status: Optional[str] = None,
):
    return await service.get_rooms(page, limit, hotel_id, room_type, status)


@router.get("/{room_id}", response_model=RoomResponse)
async def get_room(room_id: str):
    return await service.get_room(room_id)


@router.put("/{room_id}", response_model=RoomResponse)
async def update_room(
    room_id: str,
    data: RoomCreate,
    current_user=Depends(require_permission("rooms:manage")),
):
    return await service.update_room(room_id, data, current_user["sub"])


@router.delete("/{room_id}")
async def delete_room(
    room_id: str,
    current_user=Depends(require_permission("rooms:manage")),
):
    return await service.delete_room(room_id, current_user["sub"])


@router.post("/{room_id}/bookings", response_model=HotelBookingResponse)
async def create_booking(
    room_id: str,
    data: HotelBookingCreate,
    current_user=Depends(require_role(UserRole.PASSENGER)),
):
    return await booking_service.create_booking(room_id, data, current_user["sub"])
