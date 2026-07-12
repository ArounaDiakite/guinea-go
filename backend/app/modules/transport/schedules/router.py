from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import require_permission
from app.modules.transport.schedules.schemas import ScheduleCreate, ScheduleResponse
from app.modules.transport.schedules.service import ScheduleService

router = APIRouter(
    prefix="/schedules",
    tags=["Schedules"],
)

service = ScheduleService()


@router.post("/", response_model=ScheduleResponse)
async def create_schedule(
    data: ScheduleCreate,
    current_user=Depends(require_permission("schedules:manage")),
):
    return await service.create_schedule(data, current_user["sub"])


@router.get("/", response_model=list[ScheduleResponse])
async def get_schedules(
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    company_id: Optional[str] = None,
    route_id: Optional[str] = None,
    status: Optional[str] = None,
):
    return await service.get_schedules(page, limit, company_id, route_id, status)


@router.get("/{schedule_id}", response_model=ScheduleResponse)
async def get_schedule(schedule_id: str):
    return await service.get_schedule(schedule_id)


@router.put("/{schedule_id}", response_model=ScheduleResponse)
async def update_schedule(
    schedule_id: str,
    data: ScheduleCreate,
    current_user=Depends(require_permission("schedules:manage")),
):
    return await service.update_schedule(schedule_id, data, current_user["sub"])


@router.delete("/{schedule_id}")
async def delete_schedule(
    schedule_id: str,
    current_user=Depends(require_permission("schedules:manage")),
):
    return await service.delete_schedule(schedule_id, current_user["sub"])