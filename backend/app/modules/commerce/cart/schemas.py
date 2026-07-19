from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


class AddCartItemRequest(BaseModel):
    product_id: str
    quantity: int = Field(..., ge=1)


class UpdateCartItemRequest(BaseModel):
    quantity: int = Field(..., ge=1)


class CartItemResponse(BaseModel):
    product_id: str
    product_name: str
    store_id: str
    store_name: str
    unit_price: float
    quantity: int
    subtotal: float


class CartResponse(BaseModel):
    id: str
    customer_id: str
    items: list[CartItemResponse]
    total: float
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
