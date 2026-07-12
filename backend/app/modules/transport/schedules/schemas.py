from datetime import datetime, time
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class DayOfWeek(str, Enum):
    MONDAY = "MONDAY"
    TUESDAY = "TUESDAY"
    WEDNESDAY = "WEDNESDAY"
    THURSDAY = "THURSDAY"
    FRIDAY = "FRIDAY"
    SATURDAY = "SATURDAY"
    SUNDAY = "SUNDAY"


class ScheduleStatus(str, Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"


class ScheduleCreate(BaseModel):
    company_id: str
    route_id: str

    departure_time: time
    estimated_arrival_time: Optional[time] = None

    operating_days: list[DayOfWeek] = Field(..., min_length=1)

    status: ScheduleStatus = ScheduleStatus.ACTIVE
    notes: Optional[str] = None


class ScheduleResponse(BaseModel):
    id: str
    company_id: str
    route_id: str

    departure_time: time
    estimated_arrival_time: Optional[time] = None

    operating_days: list[DayOfWeek]

    status: ScheduleStatus
    notes: Optional[str] = None

    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None