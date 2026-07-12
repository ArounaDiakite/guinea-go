from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.transport.buses.schemas import BusCreate, BusResponse
from app.modules.transport.buses.service import BusService

router = APIRouter(
    prefix="/buses",
    tags=["Buses"],
)

service = BusService()


@router.post("/", response_model=BusResponse)
async def create_bus(
    data: BusCreate,
    current_user=Depends(get_current_user),
):
    return await service.create_bus(
        data,
        current_user["sub"],
    )


@router.get("/", response_model=list[BusResponse])
async def get_buses(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    search: Optional[str] = None,
    company_id: Optional[str] = None,
    status: Optional[str] = None,
):
    return await service.get_buses(
        page,
        limit,
        search,
        company_id,
        status,
    )


@router.get("/{bus_id}", response_model=BusResponse)
async def get_bus(bus_id: str):
    return await service.get_bus(bus_id)


@router.put("/{bus_id}", response_model=BusResponse)
async def update_bus(
    bus_id: str,
    data: BusCreate,
    current_user=Depends(get_current_user),
):
    return await service.update_bus(
        bus_id,
        data,
       current_user["sub"],
    )


@router.delete("/{bus_id}")
async def delete_bus(
    bus_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_bus(
        bus_id,
        current_user["sub"],
    )