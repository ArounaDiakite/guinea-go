from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, model_validator


class EventCategory(str, Enum):
    CONCERT = "CONCERT"
    CONFERENCE = "CONFERENCE"
    SPORTS = "SPORTS"
    FESTIVAL = "FESTIVAL"
    THEATER = "THEATER"
    OTHER = "OTHER"


class EventCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    description: Optional[str] = None
    venue: str = Field(..., min_length=2, max_length=255)
    country_id: str
    city_id: str
    start_datetime: datetime
    end_datetime: datetime
    category: EventCategory

    @model_validator(mode="after")
    def end_after_start(self):
        if self.end_datetime <= self.start_datetime:
            raise ValueError("end_datetime must be after start_datetime.")
        return self


class EventResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    venue: str
    country_id: str
    city_id: str
    start_datetime: datetime
    end_datetime: datetime
    category: EventCategory
    organizer_id: str
    is_verified: bool
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
