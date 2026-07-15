import asyncio
import uuid

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.commerce.orders.repository import OrderRepository
from app.modules.education.fees.repository import StudentFeeRepository
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.modules.events.bookings.repository import EventBookingRepository
from app.modules.hotels.reservations.repository import HotelBookingRepository
from app.modules.transport.bookings.repository import BookingRepository
from app.notifications.service import NotificationService
from app.payments.repository import PaymentRepository
from app.payments.schemas import PaymentCreate, SchoolFeePaymentCreate

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
        # School fees don't fit booking_repositories' shape (no
        # PENDING_PAYMENT/CONFIRMED status transition, no exact-price
        # match, several payments accumulate against one fee instead of
        # a single one confirming it) - handled by the dedicated
        # initiate_fee_payment/complete_sandbox_fee_payment pair below
        # instead of being shoehorned into the generic path.
        self.student_fee_repository = StudentFeeRepository()
        self.student_repository = StudentRepository()
        self.institution_repository = InstitutionRepository()
        self.notification_service = NotificationService()

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

        booking_type = payment.get("booking_type", "transport")
        booking_repository = self._booking_repository(booking_type)

        booking_confirmed = await booking_repository.transition_status_if(
            payment["booking_id"],
            "PENDING_PAYMENT",
            {"status": "CONFIRMED", **BaseDocument.update()},
        )

        if booking_confirmed:
            await self.repository.update_status(
                payment_id, {"status": "completed", **BaseDocument.update()}
            )

            booking = await booking_repository.get_by_id(payment["booking_id"])
            owner_field = _OWNER_FIELD_BY_TYPE.get(booking_type, "passenger_id")

            await self.notification_service.send(
                booking[owner_field],
                "booking_confirmed",
                {
                    "booking_type": booking_type,
                    "booking_id": payment["booking_id"],
                    "amount": payment["amount"],
                    "currency": payment.get("currency", "GNF"),
                },
            )
        else:
            await self.repository.update_status(
                payment_id, {"status": "failed", **BaseDocument.update()}
            )

    async def _get_owned_student_fee(self, student_fee_id: str, student_id: str, user_id: str):
        student_fee = await self.student_fee_repository.get_by_id(student_fee_id)

        if not student_fee:
            raise HTTPException(status_code=404, detail="Student fee not found.")

        if student_fee["student_id"] != student_id:
            raise HTTPException(
                status_code=400,
                detail="This fee does not belong to the given student.",
            )

        student = await self.student_repository.get_by_id(student_fee["student_id"])

        if not student:
            raise HTTPException(status_code=403, detail="Not allowed.")

        institution = await self.institution_repository.get_by_id(student["institution_id"])

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return student_fee

    async def initiate_fee_payment(self, student_id: str, data: SchoolFeePaymentCreate, user_id: str):
        student_fee = await self._get_owned_student_fee(data.student_fee_id, student_id, user_id)

        remaining = student_fee["amount_due"] - student_fee["amount_paid"]

        if remaining <= 0.01:
            raise HTTPException(status_code=400, detail="This fee has already been fully paid.")

        if data.amount > remaining + 0.01:
            raise HTTPException(
                status_code=400,
                detail=f"Payment amount exceeds the remaining balance ({remaining:.2f}).",
            )

        existing_pending = await self.repository.get_pending_by_booking(data.student_fee_id)

        if existing_pending:
            raise HTTPException(
                status_code=400,
                detail=(
                    "A payment is already in progress for this fee. Wait for it "
                    "to complete before submitting another."
                ),
            )

        payment_doc = {
            "booking_id": data.student_fee_id,
            "booking_type": "school_fee",
            "amount": data.amount,
            "currency": "GNF",
            "provider": data.provider.value,
            "status": "pending",
            "external_reference": f"SANDBOX-{uuid.uuid4().hex[:12].upper()}",
        }
        payment_doc.update(BaseDocument.create())

        payment = await self.repository.create(payment_doc)
        return self._format(payment)

    async def complete_sandbox_fee_payment(self, payment_id: str):
        """Fee counterpart of complete_sandbox_payment: instead of a
        conditional PENDING_PAYMENT -> CONFIRMED status transition, it
        atomically accumulates this payment's amount onto the fee's
        amount_paid (StudentFeeRepository.apply_payment) and reclassifies
        unpaid/partial/paid from the result. Marks the payment failed if
        that atomic update didn't match - i.e. another payment completed
        in the meantime and this one would now overpay the fee."""
        await asyncio.sleep(SANDBOX_COMPLETION_DELAY_SECONDS)

        payment = await self.repository.get_by_id(payment_id)

        if not payment or payment["status"] != "pending":
            return

        updated_fee = await self.student_fee_repository.apply_payment(
            payment["booking_id"], payment["amount"]
        )

        if updated_fee:
            await self.repository.update_status(
                payment_id, {"status": "completed", **BaseDocument.update()}
            )

            # Notifies the school_administrator, not the student - same
            # reasoning as the rest of the fees feature: students have no
            # account in this system, the administrator is who submitted
            # the payment on their behalf.
            student = await self.student_repository.get_by_id(updated_fee["student_id"])

            if student:
                institution = await self.institution_repository.get_by_id(
                    student["institution_id"]
                )

                if institution:
                    await self.notification_service.send(
                        institution["administrator_id"],
                        "fee_payment_received",
                        {
                            "amount": payment["amount"],
                            "currency": payment.get("currency", "GNF"),
                            "student_name": f"{student['first_name']} {student['last_name']}",
                            "remaining": round(
                                updated_fee["amount_due"] - updated_fee["amount_paid"], 2
                            ),
                            "status": updated_fee["status"],
                        },
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
