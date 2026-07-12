from datetime import date, datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, model_validator


class HotelBookingStatus(str, Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class HotelBookingCreate(BaseModel):
    check_in: date
    check_out: date

    @model_validator(mode="after")
    def check_out_after_check_in(self):
        if self.check_out <= self.check_in:
            raise ValueError("check_out must be after check_in (at least one night).")
        return self


class HotelBookingResponse(BaseModel):
    id: str
    hotel_id: str
    room_id: str
    passenger_id: str
    check_in: date
    check_out: date
    nights: int
    price_paid: float
    status: HotelBookingStatus
    expires_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
