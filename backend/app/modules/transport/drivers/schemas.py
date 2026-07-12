from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.identity.auth.schemas import RegisterRequest, UserResponse


class DriverStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    ON_TRIP = "ON_TRIP"
    ON_LEAVE = "ON_LEAVE"
    SUSPENDED = "SUSPENDED"
    INACTIVE = "INACTIVE"


class DriverGender(str, Enum):
    MALE = "MALE"
    FEMALE = "FEMALE"
    OTHER = "OTHER"


class LicenseCategory(str, Enum):
    A = "A"
    B = "B"
    C = "C"
    D = "D"
    E = "E"


class DriverCreate(BaseModel):
    company_id: str
    employee_number: str = Field(..., min_length=2, max_length=50)

    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    gender: DriverGender
    date_of_birth: date

    phone: str = Field(..., min_length=6, max_length=30)
    email: Optional[EmailStr] = None

    license_number: str = Field(..., min_length=3, max_length=100)
    license_category: LicenseCategory
    license_issue_date: Optional[date] = None
    license_expiry_date: date

    years_of_experience: int = Field(0, ge=0, le=60)

    nationality: Optional[str] = None
    country_code: str = Field(..., min_length=2, max_length=3)
    city: str = Field(..., min_length=2, max_length=100)
    address: Optional[str] = None

    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None

    status: DriverStatus = DriverStatus.AVAILABLE


class DriverResponse(BaseModel):
    id: str
    company_id: str
    user_id: Optional[str] = None
    employee_number: str

    first_name: str
    last_name: str
    gender: DriverGender
    date_of_birth: date

    phone: str
    email: Optional[EmailStr] = None

    license_number: str
    license_category: LicenseCategory
    license_issue_date: Optional[date] = None
    license_expiry_date: date

    years_of_experience: int

    nationality: Optional[str] = None
    country_code: str
    city: str
    address: Optional[str] = None

    photo_url: Optional[str] = None

    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None

    status: DriverStatus
    is_active: bool

    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class DriverProfileCreate(BaseModel):
    """Driver business-profile fields for the combined
    account + profile creation flow (POST /companies/{id}/drivers).
    Excludes company_id (from the URL) and identity fields already
    covered by DriverAccountCreate's RegisterRequest base."""

    employee_number: str = Field(..., min_length=2, max_length=50)

    gender: DriverGender
    date_of_birth: date

    license_number: str = Field(..., min_length=3, max_length=100)
    license_category: LicenseCategory
    license_issue_date: Optional[date] = None
    license_expiry_date: date

    years_of_experience: int = Field(0, ge=0, le=60)

    nationality: Optional[str] = None
    address: Optional[str] = None

    emergency_contact_name: Optional[str] = None
    emergency_contact_phone: Optional[str] = None

    status: DriverStatus = DriverStatus.AVAILABLE


class DriverAccountCreate(RegisterRequest):
    """Request body for POST /companies/{company_id}/drivers: identity
    credentials (inherited from RegisterRequest) plus the driver's
    business profile."""

    profile: DriverProfileCreate


class DriverWithAccountResponse(BaseModel):
    account: UserResponse
    driver: DriverResponse