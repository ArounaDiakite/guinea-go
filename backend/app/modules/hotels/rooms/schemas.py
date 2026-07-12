from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class RoomType(str, Enum):
    SIMPLE = "SIMPLE"
    DOUBLE = "DOUBLE"
    SUITE = "SUITE"
    FAMILY = "FAMILY"


class RoomStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    MAINTENANCE = "MAINTENANCE"


class RoomCreate(BaseModel):
    hotel_id: str
    room_number: str = Field(..., min_length=1, max_length=20)
    room_type: RoomType
    capacity: int = Field(..., ge=1, le=20)
    base_price: float = Field(..., gt=0)
    description: Optional[str] = None
    status: RoomStatus = RoomStatus.AVAILABLE


class RoomResponse(BaseModel):
    id: str
    hotel_id: str
    room_number: str
    room_type: RoomType
    capacity: int
    base_price: float
    description: Optional[str] = None
    status: RoomStatus
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
