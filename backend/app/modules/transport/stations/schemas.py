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

    # No country_id here - a station's country is always derivable
    # from city_id (shared/cities.country_code), not worth duplicating.
    city_id: str
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

    city_id: str
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