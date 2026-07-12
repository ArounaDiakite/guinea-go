from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.events.bookings.schemas import EventBookingResponse
from app.modules.events.bookings.service import EventBookingService

router = APIRouter(
    prefix="/event-bookings",
    tags=["Event Bookings"],
)

service = EventBookingService()


@router.get("/me", response_model=list[EventBookingResponse])
async def get_my_bookings(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user),
):
    return await service.get_my_bookings(current_user["sub"], page, limit)


@router.delete("/{booking_id}", response_model=EventBookingResponse)
async def cancel_booking(
    booking_id: str,
    current_user=Depends(get_current_user),
):
    return await service.cancel_booking(booking_id, current_user["sub"])
