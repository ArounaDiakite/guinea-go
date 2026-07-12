from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class TripStatus(str, Enum):
    SCHEDULED = "SCHEDULED"
    BOARDING = "BOARDING"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    DELAYED = "DELAYED"


class TripCreate(BaseModel):
    company_id: str
    route_id: str
    schedule_id: str
    bus_id: str
    driver_id: str

    travel_date: date

    # Defaults to the route's base_price when omitted; set explicitly here
    # only to override it for this specific trip (e.g. a one-off surge).
    price: Optional[float] = Field(None, ge=0)
    notes: Optional[str] = None

    status: TripStatus = TripStatus.SCHEDULED


class TripResponse(BaseModel):
    id: str
    company_id: str
    route_id: str
    schedule_id: str
    bus_id: str
    driver_id: str

    travel_date: datetime
    departure_datetime: datetime
    estimated_arrival_datetime: Optional[datetime] = None

    available_seats: int
    booked_seats: int
    price: float

    status: TripStatus
    notes: Optional[str] = None

    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None