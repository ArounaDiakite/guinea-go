from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class StoreCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    description: Optional[str] = None
    logo_url: Optional[str] = None
    phone: str = Field(..., min_length=6, max_length=30)
    email: EmailStr
    country_code: str = Field(..., min_length=2, max_length=3)
    city: str = Field(..., min_length=2, max_length=100)
    address: str = Field(..., min_length=2, max_length=255)
    shipping_info: Optional[str] = None


class StoreResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    logo_url: Optional[str] = None
    phone: str
    email: EmailStr
    country_code: str
    city: str
    address: str
    shipping_info: Optional[str] = None
    owner_id: str
    is_verified: bool
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
