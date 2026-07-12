from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class BusType(str, Enum):
    STANDARD = "STANDARD"
    VIP = "VIP"
    LUXURY = "LUXURY"
    SLEEPER = "SLEEPER"
    MINIBUS = "MINIBUS"


class BusStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    IN_SERVICE = "IN_SERVICE"
    MAINTENANCE = "MAINTENANCE"
    OUT_OF_SERVICE = "OUT_OF_SERVICE"


class BusCreate(BaseModel):
    company_id: str
    registration_number: str
    fleet_number: str
    brand: str
    model: str
    manufacture_year: int = Field(..., ge=1980, le=2100)
    color: Optional[str] = None
    seat_capacity: int = Field(..., ge=1, le=100)
    bus_type: BusType
    air_conditioning: bool = False
    wifi: bool = False
    usb_charging: bool = False
    toilet: bool = False
    television: bool = False
    status: BusStatus = BusStatus.AVAILABLE


class BusResponse(BaseModel):
    id: str
    company_id: str
    registration_number: str
    fleet_number: str
    brand: str
    model: str
    manufacture_year: int
    color: Optional[str] = None
    seat_capacity: int
    bus_type: BusType
    air_conditioning: bool
    wifi: bool
    usb_charging: bool
    toilet: bool
    television: bool
    status: BusStatus
    photos: list[str] = []
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None