from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field

from app.identity.auth.schemas import RegisterRequest, UserResponse


class InstitutionType(str, Enum):
    PRIMARY_PUBLIC = "primary_public"
    PRIMARY_PRIVATE = "primary_private"
    SECONDARY_PUBLIC = "secondary_public"
    SECONDARY_PRIVATE = "secondary_private"
    HIGH_SCHOOL_PUBLIC = "high_school_public"
    HIGH_SCHOOL_PRIVATE = "high_school_private"
    # No public counterpart modeled yet - Guinea's vocational track is
    # private-only in this system for now. Add one (and move it into
    # PUBLIC_INSTITUTION_TYPES below) if that turns out to be wrong;
    # nothing else assumes the two-per-level pattern holds here.
    VOCATIONAL_HIGH_SCHOOL = "vocational_high_school"
    VOCATIONAL_SCHOOL = "vocational_school"
    UNIVERSITY_PUBLIC = "university_public"
    UNIVERSITY_PRIVATE = "university_private"


# Which registration path (POST /admin/institutions vs POST /auth/
# register-institution) accepts which institution_type - a public
# institution is only ever created directly by a system_administrator,
# a private one only ever self-registers pending admin validation.
# Every InstitutionType value must appear in exactly one of these two
# sets.
PUBLIC_INSTITUTION_TYPES = {
    InstitutionType.PRIMARY_PUBLIC,
    InstitutionType.SECONDARY_PUBLIC,
    InstitutionType.HIGH_SCHOOL_PUBLIC,
    InstitutionType.UNIVERSITY_PUBLIC,
}

PRIVATE_INSTITUTION_TYPES = {
    InstitutionType.PRIMARY_PRIVATE,
    InstitutionType.SECONDARY_PRIVATE,
    InstitutionType.HIGH_SCHOOL_PRIVATE,
    InstitutionType.VOCATIONAL_HIGH_SCHOOL,
    InstitutionType.VOCATIONAL_SCHOOL,
    InstitutionType.UNIVERSITY_PRIVATE,
}

assert PUBLIC_INSTITUTION_TYPES | PRIVATE_INSTITUTION_TYPES == set(InstitutionType)
assert not (PUBLIC_INSTITUTION_TYPES & PRIVATE_INSTITUTION_TYPES)


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


class InstitutionProfileCreate(BaseModel):
    """Institution fields for the combined account + institution
    creation flows (POST /admin/institutions, POST /auth/register-
    institution). Identity fields for the school_administrator account
    itself come from InstitutionAccountCreate's RegisterRequest base."""

    name: str = Field(..., min_length=2, max_length=150)
    address: str = Field(..., min_length=2, max_length=255)
    city: str = Field(..., min_length=2, max_length=100)
    country_code: str = Field(..., min_length=2, max_length=3)
    institution_type: InstitutionType


class InstitutionAccountCreate(RegisterRequest):
    institution: InstitutionProfileCreate


class InstitutionWithAccountResponse(BaseModel):
    account: UserResponse
    institution: InstitutionResponse
