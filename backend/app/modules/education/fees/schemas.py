from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class FeeScheduleCreate(BaseModel):
    institution_id: str
    # Only set when fees vary by class/filière - a plain institution-wide
    # fee leaves this null.
    academic_unit_id: Optional[str] = None
    name: str = Field(..., min_length=1, max_length=150)
    amount: float = Field(..., gt=0)
    # Defaults to the owning institution's own country's currency when
    # omitted - no need to specify it if it's derivable from the
    # parent resource.
    currency_id: Optional[str] = None
    # Free text on purpose, same reasoning as AcademicUnit.level: a
    # primary school's "trimestriel" and a university's "semestriel"
    # don't share a common enum without being awkwardly overloaded.
    period: str = Field(..., min_length=1, max_length=50)


class FeeScheduleResponse(BaseModel):
    id: str
    institution_id: str
    academic_unit_id: Optional[str] = None
    name: str
    amount: float
    currency_id: str
    period: str
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class StudentFeeCreate(BaseModel):
    fee_schedule_id: str


class FeePaymentSummary(BaseModel):
    id: str
    amount: float
    provider: str
    status: str
    created_at: Optional[datetime] = None


class StudentFeeResponse(BaseModel):
    id: str
    student_id: str
    fee_schedule_id: str
    fee_schedule_name: str
    period: str
    amount_due: float
    amount_paid: float
    amount_remaining: float
    # Snapshotted from the FeeSchedule at apply time, same reasoning as
    # amount_due: if the schedule's currency is ever changed later, an
    # already-applied StudentFee shouldn't have its frozen amount_due
    # silently reinterpreted under a different currency.
    currency_id: str
    status: str
    payments: list[FeePaymentSummary] = []
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
