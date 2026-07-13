from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class ProductCreate(BaseModel):
    name: str = Field(..., min_length=2, max_length=150)
    description: Optional[str] = None
    price: float = Field(..., gt=0)
    category_ids: list[str] = []
    images: list[str] = []
    stock: int = Field(..., ge=0)
    is_active: bool = True


class ProductResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    price: float
    category_ids: list[str] = []
    images: list[str] = []
    stock: int
    owner_id: str
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
