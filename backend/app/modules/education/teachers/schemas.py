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
    # Generated once at creation, never regenerated. Still shown after
    # the account is claimed (user_id set) so the school_administrator
    # can see it was used, not just a blank field - the invite flow
    # itself is what actually blocks reuse (see school_members/
    # service.py), not hiding the code.
    invite_code: str
    user_id: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
