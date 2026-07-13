from fastapi import APIRouter, BackgroundTasks, Depends

from app.core.dependencies import get_current_user
from app.payments.schemas import PaymentCreate, PaymentResponse
from app.payments.service import PaymentService

router = APIRouter(
    prefix="/bookings",
    tags=["Payments"],
)

hotel_router = APIRouter(
    prefix="/hotel-bookings",
    tags=["Payments"],
)

event_router = APIRouter(
    prefix="/event-bookings",
    tags=["Payments"],
)

order_router = APIRouter(
    prefix="/orders",
    tags=["Payments"],
)

service = PaymentService()


@router.post("/{booking_id}/payments", response_model=PaymentResponse)
async def initiate_payment(
    booking_id: str,
    data: PaymentCreate,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    payment = await service.initiate_payment(booking_id, data, current_user["sub"])
    background_tasks.add_task(service.complete_sandbox_payment, payment["id"])
    return payment


@hotel_router.post("/{booking_id}/payments", response_model=PaymentResponse)
async def initiate_hotel_payment(
    booking_id: str,
    data: PaymentCreate,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    payment = await service.initiate_payment(
        booking_id, data, current_user["sub"], booking_type="hotel"
    )
    background_tasks.add_task(service.complete_sandbox_payment, payment["id"])
    return payment


@event_router.post("/{booking_id}/payments", response_model=PaymentResponse)
async def initiate_event_payment(
    booking_id: str,
    data: PaymentCreate,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    payment = await service.initiate_payment(
        booking_id, data, current_user["sub"], booking_type="event"
    )
    background_tasks.add_task(service.complete_sandbox_payment, payment["id"])
    return payment


@order_router.post("/{booking_id}/payments", response_model=PaymentResponse)
async def initiate_order_payment(
    booking_id: str,
    data: PaymentCreate,
    background_tasks: BackgroundTasks,
    current_user=Depends(get_current_user),
):
    payment = await service.initiate_payment(
        booking_id, data, current_user["sub"], booking_type="order"
    )
    background_tasks.add_task(service.complete_sandbox_payment, payment["id"])
    return payment
