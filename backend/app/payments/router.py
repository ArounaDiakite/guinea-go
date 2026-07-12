from fastapi import APIRouter, BackgroundTasks, Depends

from app.core.dependencies import get_current_user
from app.payments.schemas import PaymentCreate, PaymentResponse
from app.payments.service import PaymentService

router = APIRouter(
    prefix="/bookings",
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
