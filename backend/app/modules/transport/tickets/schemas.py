from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


class TicketStatus(str, Enum):
    VALID = "VALID"
    USED = "USED"
    CANCELLED = "CANCELLED"


class TicketResponse(BaseModel):
    id: str
    booking_id: str
    trip_id: str
    seat_id: str
    passenger_id: str
    code: str
    status: TicketStatus
    used_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
