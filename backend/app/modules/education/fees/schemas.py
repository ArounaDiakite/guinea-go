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
    status: str
    payments: list[FeePaymentSummary] = []
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
