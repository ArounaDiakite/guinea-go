from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class TicketCategory(str, Enum):
    STANDARD = "STANDARD"
    VIP = "VIP"
    EARLY_BIRD = "EARLY_BIRD"
    STUDENT = "STUDENT"


class TicketTypeCreate(BaseModel):
    event_id: str
    category: TicketCategory
    base_price: float = Field(..., gt=0)
    quantity_total: int = Field(..., ge=1)
    description: Optional[str] = None


class TicketTypeResponse(BaseModel):
    id: str
    event_id: str
    category: TicketCategory
    base_price: float
    quantity_total: int
    quantity_available: int
    description: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
