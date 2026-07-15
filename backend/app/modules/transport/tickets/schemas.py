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


class TicketValidationResponse(TicketResponse):
    """POST /tickets/{code}/validate's response - a driver scanning a
    ticket needs to see who they're boarding without a separate lookup
    (there's no general-purpose GET /users/{id}), so the two fields
    that matter at boarding time are resolved server-side and embedded
    here rather than exposed as their own endpoint."""

    passenger_name: str
    seat_number: str
