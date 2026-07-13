from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user
from app.modules.commerce.cart.schemas import (
    AddCartItemRequest,
    CartResponse,
    UpdateCartItemRequest,
)
from app.modules.commerce.cart.service import CartService

router = APIRouter(
    prefix="/cart",
    tags=["Cart"],
)

service = CartService()


@router.get("/", response_model=CartResponse)
async def get_cart(current_user=Depends(get_current_user)):
    return await service.get_cart(current_user["sub"])


@router.post("/items", response_model=CartResponse)
async def add_item(
    data: AddCartItemRequest,
    current_user=Depends(get_current_user),
):
    return await service.add_item(current_user["sub"], data)


@router.put("/items/{product_id}", response_model=CartResponse)
async def update_item_quantity(
    product_id: str,
    data: UpdateCartItemRequest,
    current_user=Depends(get_current_user),
):
    return await service.update_item_quantity(current_user["sub"], product_id, data)


@router.delete("/items/{product_id}", response_model=CartResponse)
async def remove_item(
    product_id: str,
    current_user=Depends(get_current_user),
):
    return await service.remove_item(current_user["sub"], product_id)


@router.delete("/", response_model=CartResponse)
async def clear_cart(current_user=Depends(get_current_user)):
    return await service.clear_cart(current_user["sub"])
