from fastapi import APIRouter, Depends, Query

from app.core.constants import UserRole
from app.core.dependencies import get_current_user, require_role
from app.modules.commerce.orders.schemas import OrderResponse
from app.modules.commerce.orders.service import OrderService

router = APIRouter(
    prefix="/orders",
    tags=["Orders"],
)

service = OrderService()


@router.post("/checkout", response_model=list[OrderResponse])
async def checkout(current_user=Depends(require_role(UserRole.PASSENGER))):
    return await service.checkout(current_user["sub"])


@router.get("/me", response_model=list[OrderResponse])
async def get_my_orders(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user=Depends(get_current_user),
):
    return await service.get_my_orders(current_user["sub"], page, limit)


@router.delete("/{order_id}", response_model=OrderResponse)
async def cancel_order(
    order_id: str,
    current_user=Depends(get_current_user),
):
    return await service.cancel_order(order_id, current_user["sub"])
