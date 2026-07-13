import asyncio
import uuid

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.commerce.orders.repository import OrderRepository
from app.modules.events.bookings.repository import EventBookingRepository
from app.modules.hotels.reservations.repository import HotelBookingRepository
from app.modules.transport.bookings.repository import BookingRepository
from app.payments.repository import PaymentRepository
from app.payments.schemas import PaymentCreate

# Sandbox-only: simulates the delay of a real provider round-trip so the
# pending -> completed transition is actually observable when testing the
# flow. Not a substitute for real Orange Money/MTN/Stripe webhooks, which
# will call something equivalent to complete_sandbox_payment() later.
SANDBOX_COMPLETION_DELAY_SECONDS = 2

_ACTIVE_PAYMENT_STATUSES = ("pending", "completed")

# The field each booking type's document uses to record who it belongs
# to. Every other domain calls it passenger_id; commerce Orders use
# customer_id (the right word for that domain) - mapped here instead of
# forcing an odd field name onto Order just to keep this generic.
_OWNER_FIELD_BY_TYPE = {
    "transport": "passenger_id",
    "hotel": "passenger_id",
    "event": "passenger_id",
    "order": "customer_id",
}

# Same idea for the field holding the amount owed: every booking type
# calls it price_paid except commerce Orders, which total several line
# items under "total".
_PRICE_FIELD_BY_TYPE = {
    "transport": "price_paid",
    "hotel": "price_paid",
    "event": "price_paid",
    "order": "total",
}


class PaymentService:
    def __init__(self):
        self.repository = PaymentRepository()
        # All booking repositories expose the same get_by_id/
        # transition_status_if shape, so this service stays agnostic to
        # which domain a booking_id belongs to beyond picking the right
        # repository (and owner field) for it.
        self.booking_repositories = {
            "transport": BookingRepository(),
            "hotel": HotelBookingRepository(),
            "event": EventBookingRepository(),
            "order": OrderRepository(),
        }

    def _booking_repository(self, booking_type: str):
        return self.booking_repositories[booking_type]

    async def initiate_payment(
        self,
        booking_id: str,
        data: PaymentCreate,
        passenger_id: str,
        booking_type: str = "transport",
    ):
        booking_repository = self._booking_repository(booking_type)
        booking = await booking_repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        owner_field = _OWNER_FIELD_BY_TYPE.get(booking_type, "passenger_id")

        if booking[owner_field] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] != "PENDING_PAYMENT":
            raise HTTPException(
                status_code=400,
                detail=f"This booking is not awaiting payment (status: {booking['status']}).",
            )

        price_field = _PRICE_FIELD_BY_TYPE.get(booking_type, "price_paid")

        if abs(data.amount - booking[price_field]) > 0.01:
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
            "booking_type": booking_type,
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

        booking_repository = self._booking_repository(payment.get("booking_type", "transport"))

        booking_confirmed = await booking_repository.transition_status_if(
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
            "booking_type": payment.get("booking_type", "transport"),
            "amount": payment["amount"],
            "currency": payment["currency"],
            "provider": payment["provider"],
            "status": payment["status"],
            "external_reference": payment.get("external_reference"),
            "created_at": payment.get("created_at"),
            "updated_at": payment.get("updated_at"),
        }
