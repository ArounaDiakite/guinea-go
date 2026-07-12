from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.transport.routes.schemas import RouteCreate, RouteResponse
from app.modules.transport.routes.service import RouteService

router = APIRouter(
    prefix="/routes",
    tags=["Routes"],
)

service = RouteService()


@router.post("/", response_model=RouteResponse)
async def create_route(
    data: RouteCreate,
    current_user=Depends(require_permission("routes:manage")),
):
    return await service.create_route(data, current_user["sub"])


@router.get("/", response_model=list[RouteResponse])
async def get_routes(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    company_id: Optional[str] = None,
):
    return await service.get_routes(page, limit, search, company_id)


@router.get("/{route_id}", response_model=RouteResponse)
async def get_route(route_id: str):
    return await service.get_route(route_id)


@router.put("/{route_id}", response_model=RouteResponse)
async def update_route(
    route_id: str,
    data: RouteCreate,
    current_user=Depends(require_permission("routes:manage")),
):
    return await service.update_route(route_id, data, current_user["sub"])


@router.delete("/{route_id}")
async def delete_route(
    route_id: str,
    current_user=Depends(require_permission("routes:manage")),
):
    return await service.delete_route(route_id, current_user["sub"])