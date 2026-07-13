from datetime import datetime, time
from enum import Enum
from typing import Optional

from pydantic import BaseModel, model_validator


class DayOfWeek(str, Enum):
    MONDAY = "MONDAY"
    TUESDAY = "TUESDAY"
    WEDNESDAY = "WEDNESDAY"
    THURSDAY = "THURSDAY"
    FRIDAY = "FRIDAY"
    SATURDAY = "SATURDAY"
    SUNDAY = "SUNDAY"


class TimeSlotCreate(BaseModel):
    academic_unit_id: str
    subject_id: str
    teacher_id: str
    day_of_week: DayOfWeek
    start_time: time
    end_time: time

    @model_validator(mode="after")
    def end_after_start(self):
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time.")
        return self


class TimeSlotResponse(BaseModel):
    id: str
    academic_unit_id: str
    subject_id: str
    teacher_id: str
    day_of_week: DayOfWeek
    start_time: time
    end_time: time
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ScheduleItemResponse(BaseModel):
    """Enriched view for GET /academic-units/{id}/schedule - a raw
    TimeSlotResponse would force the client into N+1 lookups just to
    render a human-readable timetable."""

    id: str
    subject_id: str
    subject_name: str
    teacher_id: str
    teacher_name: str
    day_of_week: DayOfWeek
    start_time: time
    end_time: time
