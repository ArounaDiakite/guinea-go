from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class PaymentProviderCreate(BaseModel):
    code: str
    name: str
    provider_type: str
    country_code: str
    is_active: bool = True


class PaymentProviderResponse(PaymentProviderCreate):
    id: str


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
