from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ProductCreate(BaseModel):
    store_id: str
    name: str = Field(..., min_length=2, max_length=150)
    description: Optional[str] = None
    price: float = Field(..., gt=0)
    # Defaults to the owning store's own country's currency when
    # omitted - no need to specify it if it's derivable from the
    # parent resource.
    currency_id: Optional[str] = None
    category_ids: list[str] = []
    images: list[str] = []
    stock: int = Field(..., ge=0)
    is_active: bool = True


class ProductResponse(BaseModel):
    id: str
    store_id: str
    name: str
    description: Optional[str] = None
    price: float
    currency_id: str
    category_ids: list[str] = []
    images: list[str] = []
    stock: int
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
