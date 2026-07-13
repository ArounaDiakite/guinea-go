from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class TeacherCreate(BaseModel):
    institution_id: str
    first_name: str = Field(..., min_length=1, max_length=100)
    last_name: str = Field(..., min_length=1, max_length=100)
    email: Optional[EmailStr] = None
    phone: str = Field(..., min_length=6, max_length=30)
    subject: Optional[str] = None
    academic_unit_ids: list[str] = []


class TeacherResponse(BaseModel):
    id: str
    institution_id: str
    first_name: str
    last_name: str
    email: Optional[EmailStr] = None
    phone: str
    subject: Optional[str] = None
    academic_unit_ids: list[str] = []
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
