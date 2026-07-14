from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class RouteCreate(BaseModel):
    company_id: str
    route_code: str = Field(..., min_length=2, max_length=50)
    name: str = Field(..., min_length=2, max_length=150)

    origin_station_id: str
    destination_station_id: str

    distance_km: float = Field(..., gt=0)
    estimated_duration_minutes: int = Field(..., gt=0)

    base_price: float = Field(..., gt=0)
    # Defaults to the company's own country's currency when omitted -
    # no need to specify it if it's derivable from the parent resource.
    currency_id: Optional[str] = None

    description: Optional[str] = None


class RouteResponse(BaseModel):
    id: str
    company_id: str
    route_code: str
    name: str

    origin_station_id: str
    destination_station_id: str

    distance_km: float
    estimated_duration_minutes: int

    base_price: float
    currency_id: str

    description: Optional[str] = None

    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None