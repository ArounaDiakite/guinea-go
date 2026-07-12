from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.transport.drivers.schemas import DriverCreate, DriverResponse
from app.modules.transport.drivers.service import DriverService

router = APIRouter(
    prefix="/drivers",
    tags=["Drivers"],
)

service = DriverService()


@router.post("/", response_model=DriverResponse)
async def create_driver(
    data: DriverCreate,
    current_user=Depends(get_current_user),
):
    return await service.create_driver(data, current_user["sub"])


@router.get("/", response_model=list[DriverResponse])
async def get_drivers(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    company_id: Optional[str] = None,
    status: Optional[str] = None,
):
    return await service.get_drivers(page, limit, search, company_id, status)


@router.get("/{driver_id}", response_model=DriverResponse)
async def get_driver(driver_id: str):
    return await service.get_driver(driver_id)


@router.put("/{driver_id}", response_model=DriverResponse)
async def update_driver(
    driver_id: str,
    data: DriverCreate,
    current_user=Depends(get_current_user),
):
    return await service.update_driver(driver_id, data, current_user["sub"])


@router.delete("/{driver_id}")
async def delete_driver(
    driver_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_driver(driver_id, current_user["sub"])