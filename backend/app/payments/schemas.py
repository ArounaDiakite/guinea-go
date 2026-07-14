from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


# Hardcoded rather than backed by a database collection: every payment
# in this app is sandbox-simulated (see PaymentService), so there's no
# real gateway integration yet to justify a dynamic, DB-managed provider
# registry. Revisit if/when real Orange Money/MTN/Stripe integrations
# land and providers need to be enabled/disabled per country without a
# deploy.
class PaymentProvider(str, Enum):
    ORANGE_MONEY = "orange_money"
    MTN_MOMO = "mtn_momo"
    STRIPE = "stripe"


class PaymentStatus(str, Enum):
    PENDING = "pending"
    COMPLETED = "completed"
    FAILED = "failed"


class PaymentCreate(BaseModel):
    provider: PaymentProvider
    amount: float = Field(..., gt=0)


class SchoolFeePaymentCreate(BaseModel):
    # Unlike the other booking types, a student can have several
    # StudentFees open at once (tuition, registration, ...), so the
    # target has to be named explicitly rather than inferred from a
    # single "the" booking under this student.
    student_fee_id: str
    provider: PaymentProvider
    amount: float = Field(..., gt=0)


class PaymentResponse(BaseModel):
    id: str
    booking_id: str
    booking_type: str
    amount: float
    currency: str
    provider: PaymentProvider
    status: PaymentStatus
    external_reference: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
