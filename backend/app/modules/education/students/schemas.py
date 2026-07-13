from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field


class StudentCreate(BaseModel):
    institution_id: str
    academic_unit_id: str
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    date_of_birth: Optional[date] = None
    # Mostly relevant for K-12 institutions; left optional since a
    # university student is an adult and won't have one.
    guardian_name: Optional[str] = None
    guardian_phone: Optional[str] = None


class StudentResponse(BaseModel):
    id: str
    institution_id: str
    academic_unit_id: str
    first_name: str
    last_name: str
    date_of_birth: Optional[date] = None
    guardian_name: Optional[str] = None
    guardian_phone: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
