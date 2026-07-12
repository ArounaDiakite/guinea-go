from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


class BookingStatus(str, Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class BookingCreate(BaseModel):
    seat_id: str


class BookingResponse(BaseModel):
    id: str
    trip_id: str
    seat_id: str
    passenger_id: str
    status: BookingStatus
    price_paid: float
    expires_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
