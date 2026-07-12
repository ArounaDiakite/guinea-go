import asyncio
import uuid

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.transport.bookings.repository import BookingRepository
from app.payments.repository import PaymentRepository
from app.payments.schemas import PaymentCreate

# Sandbox-only: simulates the delay of a real provider round-trip so the
# pending -> completed transition is actually observable when testing the
# flow. Not a substitute for real Orange Money/MTN/Stripe webhooks, which
# will call something equivalent to complete_sandbox_payment() later.
SANDBOX_COMPLETION_DELAY_SECONDS = 2

_ACTIVE_PAYMENT_STATUSES = ("pending", "completed")


class PaymentService:
    def __init__(self):
        self.repository = PaymentRepository()
        self.booking_repository = BookingRepository()

    async def initiate_payment(self, booking_id: str, data: PaymentCreate, passenger_id: str):
        booking = await self.booking_repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        if booking["passenger_id"] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] != "PENDING_PAYMENT":
            raise HTTPException(
                status_code=400,
                detail=f"This booking is not awaiting payment (status: {booking['status']}).",
            )

        if abs(data.amount - booking["price_paid"]) > 0.01:
            raise HTTPException(
                status_code=400,
                detail="Payment amount does not match the booking's price.",
            )

        existing_payment = await self.repository.get_by_booking(booking_id)

        if existing_payment and existing_payment["status"] in _ACTIVE_PAYMENT_STATUSES:
            raise HTTPException(
                status_code=400,
                detail="A payment has already been initiated for this booking.",
            )

        payment_doc = {
            "booking_id": booking_id,
            "amount": data.amount,
            "currency": "GNF",
            "provider": data.provider.value,
            "status": "pending",
            "external_reference": f"SANDBOX-{uuid.uuid4().hex[:12].upper()}",
        }
        payment_doc.update(BaseDocument.create())

        payment = await self.repository.create(payment_doc)

        return self._format(payment)

    async def complete_sandbox_payment(self, payment_id: str):
        """Background task standing in for a real provider webhook: after
        a short simulated delay, marks the payment completed and confirms
        the booking - unless the booking's payment window has since
        expired or it was cancelled, in which case the payment fails
        instead."""
        await asyncio.sleep(SANDBOX_COMPLETION_DELAY_SECONDS)

        payment = await self.repository.get_by_id(payment_id)

        if not payment or payment["status"] != "pending":
            return

        booking_confirmed = await self.booking_repository.transition_status_if(
            payment["booking_id"],
            "PENDING_PAYMENT",
            {"status": "CONFIRMED", **BaseDocument.update()},
        )

        if booking_confirmed:
            await self.repository.update_status(
                payment_id, {"status": "completed", **BaseDocument.update()}
            )
        else:
            await self.repository.update_status(
                payment_id, {"status": "failed", **BaseDocument.update()}
            )

    def _format(self, payment):
        return {
            "id": str(payment["_id"]),
            "booking_id": payment["booking_id"],
            "amount": payment["amount"],
            "currency": payment["currency"],
            "provider": payment["provider"],
            "status": payment["status"],
            "external_reference": payment.get("external_reference"),
            "created_at": payment.get("created_at"),
            "updated_at": payment.get("updated_at"),
        }
