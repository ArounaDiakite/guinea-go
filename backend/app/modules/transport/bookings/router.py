from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.transport.bookings.schemas import BookingResponse
from app.modules.transport.bookings.service import BookingService

router = APIRouter(
    prefix="/bookings",
    tags=["Bookings"],
)

service = BookingService()


@router.get("/me", response_model=list[BookingResponse])
async def get_my_bookings(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user),
):
    return await service.get_my_bookings(current_user["sub"], page, limit)


@router.get("/{booking_id}", response_model=BookingResponse)
async def get_booking(
    booking_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_booking(booking_id, current_user["sub"])


@router.delete("/{booking_id}", response_model=BookingResponse)
async def cancel_booking(
    booking_id: str,
    current_user=Depends(get_current_user),
):
    return await service.cancel_booking(booking_id, current_user["sub"])
