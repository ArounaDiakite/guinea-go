from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class HotelCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    description: Optional[str] = None
    phone: str = Field(..., min_length=6, max_length=30)
    email: EmailStr
    website: Optional[str] = None
    country_code: str = Field(..., min_length=2, max_length=3)
    city: str = Field(..., min_length=2, max_length=100)
    address: str = Field(..., min_length=2, max_length=255)
    amenities: list[str] = []


class HotelResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    phone: str
    email: EmailStr
    website: Optional[str] = None
    country_code: str
    city: str
    address: str
    amenities: list[str] = []
    owner_id: str
    is_verified: bool
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
