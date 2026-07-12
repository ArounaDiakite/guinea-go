from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class EventBookingStatus(str, Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"
    EXPIRED = "EXPIRED"


class EventBookingCreate(BaseModel):
    quantity: int = Field(..., ge=1, le=20)


class EventBookingResponse(BaseModel):
    id: str
    event_id: str
    ticket_type_id: str
    passenger_id: str
    quantity: int
    price_paid: float
    status: EventBookingStatus
    expires_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
