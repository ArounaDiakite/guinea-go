from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.commerce.categories.schemas import CategoryCreate, CategoryResponse
from app.modules.commerce.categories.service import CategoryService

router = APIRouter(
    prefix="/categories",
    tags=["Categories"],
)

service = CategoryService()


@router.post("/", response_model=CategoryResponse)
async def create_category(
    data: CategoryCreate,
    current_user=Depends(require_permission("categories:manage")),
):
    return await service.create_category(data)


@router.get("/", response_model=list[CategoryResponse])
async def get_categories(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = None,
    category_parent_id: Optional[str] = None,
):
    return await service.get_categories(page, limit, search, category_parent_id)


@router.get("/{category_id}", response_model=CategoryResponse)
async def get_category(category_id: str):
    return await service.get_category(category_id)


@router.put("/{category_id}", response_model=CategoryResponse)
async def update_category(
    category_id: str,
    data: CategoryCreate,
    current_user=Depends(require_permission("categories:manage")),
):
    return await service.update_category(category_id, data)


@router.delete("/{category_id}")
async def delete_category(
    category_id: str,
    current_user=Depends(require_permission("categories:manage")),
):
    return await service.delete_category(category_id)
