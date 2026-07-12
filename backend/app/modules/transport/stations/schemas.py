from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class StationType(str, Enum):
    BUS = "BUS"
    TAXI = "TAXI"
    FERRY = "FERRY"
    TRAIN = "TRAIN"


class StationCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    station_code: str = Field(..., min_length=2, max_length=50)
    station_type: StationType

    country_code: str = Field(..., min_length=2, max_length=3)
    city: str = Field(..., min_length=2, max_length=100)
    address: str = Field(..., min_length=2, max_length=255)

    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)

    contact_phone: Optional[str] = Field(None, max_length=30)
    contact_email: Optional[EmailStr] = None

    description: Optional[str] = None
    operating_hours: Optional[str] = None


class StationResponse(BaseModel):
    id: str
    name: str
    station_code: str
    station_type: StationType

    country_code: str
    city: str
    address: str

    latitude: Optional[float] = None
    longitude: Optional[float] = None

    contact_phone: Optional[str] = None
    contact_email: Optional[EmailStr] = None

    description: Optional[str] = None
    operating_hours: Optional[str] = None

    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None