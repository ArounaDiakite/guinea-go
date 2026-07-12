from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr


class CompanyType(str, Enum):
    BUS = "BUS"
    TAXI = "TAXI"
    HOTEL = "HOTEL"
    EVENT = "EVENT"
    CAR_RENTAL = "CAR_RENTAL"


class CompanyCreate(BaseModel):
    name: str
    company_type: CompanyType
    description: Optional[str] = None
    phone: str
    email: EmailStr
    website: Optional[str] = None
    country_code: str
    city: str
    address: str


class CompanyResponse(BaseModel):
    id: str
    name: str
    company_type: CompanyType
    description: Optional[str] = None
    phone: str
    email: EmailStr
    website: Optional[str] = None
    country_code: str
    city: str
    address: str
    owner_id: str
    is_verified: bool
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    logo_url: Optional[str] = None