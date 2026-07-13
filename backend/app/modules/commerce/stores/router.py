from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.commerce.products.schemas import ProductResponse
from app.modules.commerce.products.service import ProductService
from app.modules.commerce.stores.schemas import StoreCreate, StoreResponse
from app.modules.commerce.stores.service import StoreService

router = APIRouter(
    prefix="/stores",
    tags=["Stores"],
)

service = StoreService()
product_service = ProductService()


@router.post("/", response_model=StoreResponse)
async def create_store(
    data: StoreCreate,
    current_user=Depends(require_permission("stores:manage")),
):
    return await service.create_store(data, current_user["sub"])


@router.get("/", response_model=list[StoreResponse])
async def get_stores(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    city: Optional[str] = None,
    owner_id: Optional[str] = None,
):
    return await service.get_stores(page, limit, search, city, owner_id)


@router.get("/{store_id}", response_model=StoreResponse)
async def get_store(store_id: str):
    return await service.get_store(store_id)


@router.get("/{store_id}/products", response_model=list[ProductResponse])
async def get_store_products(
    store_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    category_id: Optional[str] = None,
):
    # Confirms the store exists (404 for a bogus id) before listing its
    # products, rather than silently returning an empty list either way.
    await service.get_store(store_id)
    return await product_service.get_products(page, limit, search, category_id, store_id)


@router.put("/{store_id}", response_model=StoreResponse)
async def update_store(
    store_id: str,
    data: StoreCreate,
    current_user=Depends(require_permission("stores:manage")),
):
    return await service.update_store(store_id, data, current_user["sub"])


@router.delete("/{store_id}")
async def delete_store(
    store_id: str,
    current_user=Depends(require_permission("stores:manage")),
):
    return await service.delete_store(store_id, current_user["sub"])
