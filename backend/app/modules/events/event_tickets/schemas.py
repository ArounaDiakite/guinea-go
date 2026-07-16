from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


class EventTicketStatus(str, Enum):
    VALID = "VALID"
    USED = "USED"
    CANCELLED = "CANCELLED"


class EventTicketResponse(BaseModel):
    id: str
    booking_id: str
    event_id: str
    ticket_type_id: str
    passenger_id: str
    quantity: int
    code: str
    status: EventTicketStatus
    used_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class EventTicketValidationResponse(EventTicketResponse):
    """POST /event-tickets/{code}/validate's response - an organizer
    scanning a ticket at the door needs to see who they're admitting
    without a separate lookup (there's no general-purpose
    GET /users/{id}), so the passenger name and ticket category are
    resolved server-side and embedded here rather than exposed as
    their own endpoint - same shape as transport's
    TicketValidationResponse (passenger_name + seat_number)."""

    passenger_name: str
    ticket_category: str
