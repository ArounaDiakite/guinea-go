from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel


class SeatType(str, Enum):
    WINDOW = "WINDOW"
    AISLE = "AISLE"
    STANDARD = "STANDARD"


class SeatStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    RESERVED = "RESERVED"
    MAINTENANCE = "MAINTENANCE"


class SeatResponse(BaseModel):
    id: str
    bus_id: str
    company_id: str
    seat_number: str
    seat_type: SeatType
    status: SeatStatus
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class TripSeatResponse(BaseModel):
    """A seat's availability for one specific trip, not the bus in
    general: MAINTENANCE carries over from the seat's own bus-level
    status, RESERVED comes from an active booking for this trip_id."""

    seat_id: str
    seat_number: str
    seat_type: SeatType
    status: SeatStatus
