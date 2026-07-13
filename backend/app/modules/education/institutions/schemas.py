from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class InstitutionType(str, Enum):
    PRIMARY_PUBLIC = "primary_public"
    SECONDARY = "secondary"
    HIGH_SCHOOL = "high_school"
    VOCATIONAL_HIGH_SCHOOL = "vocational_high_school"
    VOCATIONAL_SCHOOL = "vocational_school"
    UNIVERSITY_PUBLIC = "university_public"
    UNIVERSITY_PRIVATE = "university_private"


class InstitutionCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    address: str = Field(..., min_length=2, max_length=255)
    city: str = Field(..., min_length=2, max_length=100)
    country_code: str = Field(..., min_length=2, max_length=3)
    institution_type: InstitutionType


class InstitutionResponse(BaseModel):
    id: str
    name: str
    address: str
    city: str
    country_code: str
    institution_type: InstitutionType
    administrator_id: str
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
