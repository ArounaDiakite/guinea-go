from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.commerce.products.schemas import ProductCreate, ProductResponse
from app.modules.commerce.products.service import ProductService

router = APIRouter(
    prefix="/products",
    tags=["Products"],
)

service = ProductService()


@router.post("/", response_model=ProductResponse)
async def create_product(
    data: ProductCreate,
    current_user=Depends(require_permission("products:manage")),
):
    return await service.create_product(data, current_user["sub"])


@router.get("/", response_model=list[ProductResponse])
async def get_products(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    category_id: Optional[str] = None,
    owner_id: Optional[str] = None,
):
    return await service.get_products(page, limit, search, category_id, owner_id)


@router.get("/{product_id}", response_model=ProductResponse)
async def get_product(product_id: str):
    return await service.get_product(product_id)


@router.put("/{product_id}", response_model=ProductResponse)
async def update_product(
    product_id: str,
    data: ProductCreate,
    current_user=Depends(require_permission("products:manage")),
):
    return await service.update_product(product_id, data, current_user["sub"])


@router.delete("/{product_id}")
async def delete_product(
    product_id: str,
    current_user=Depends(require_permission("products:manage")),
):
    return await service.delete_product(product_id, current_user["sub"])
