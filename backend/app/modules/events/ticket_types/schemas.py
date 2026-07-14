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
    # Defaults to the owning event's own country's currency when
    # omitted - no need to specify it if it's derivable from the
    # parent resource.
    currency_id: Optional[str] = None
    quantity_total: int = Field(..., ge=1)
    description: Optional[str] = None


class TicketTypeResponse(BaseModel):
    id: str
    event_id: str
    category: TicketCategory
    base_price: float
    currency_id: str
    quantity_total: int
    quantity_available: int
    description: Optional[str] = None
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
