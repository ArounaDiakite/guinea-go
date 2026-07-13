from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class Period(str, Enum):
    T1 = "T1"
    T2 = "T2"
    T3 = "T3"


class GradeCreate(BaseModel):
    subject_id: str
    # 0-20 is the standard scale in Guinea's French-inherited school
    # system - not an arbitrary choice.
    value: float = Field(..., ge=0, le=20)
    coefficient: float = Field(..., gt=0)
    period: Period


class GradeResponse(BaseModel):
    id: str
    student_id: str
    subject_id: str
    value: float
    coefficient: float
    period: Period
    is_active: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None


class SubjectAverage(BaseModel):
    subject_id: str
    subject_name: str
    average: float
    grade_count: int


class ReportCard(BaseModel):
    student_id: str
    period: Period
    subject_averages: list[SubjectAverage]
    overall_average: float | None = None
