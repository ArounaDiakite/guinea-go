from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.fees.schemas import FeeScheduleCreate, FeeScheduleResponse
from app.modules.education.fees.service import FeeScheduleService

router = APIRouter(
    prefix="/fee-schedules",
    tags=["Fee Schedules"],
)

service = FeeScheduleService()


@router.post("/", response_model=FeeScheduleResponse)
async def create_fee_schedule(
    data: FeeScheduleCreate,
    current_user=Depends(require_permission("fees:manage")),
):
    return await service.create_fee_schedule(data, current_user["sub"])


@router.get("/", response_model=list[FeeScheduleResponse])
async def get_fee_schedules(
    institution_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user=Depends(get_current_user),
):
    return await service.get_fee_schedules(institution_id, current_user["sub"], page, limit)


@router.get("/{fee_schedule_id}", response_model=FeeScheduleResponse)
async def get_fee_schedule(
    fee_schedule_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_fee_schedule(fee_schedule_id, current_user["sub"])


@router.put("/{fee_schedule_id}", response_model=FeeScheduleResponse)
async def update_fee_schedule(
    fee_schedule_id: str,
    data: FeeScheduleCreate,
    current_user=Depends(require_permission("fees:manage")),
):
    return await service.update_fee_schedule(fee_schedule_id, data, current_user["sub"])


@router.delete("/{fee_schedule_id}")
async def delete_fee_schedule(
    fee_schedule_id: str,
    current_user=Depends(require_permission("fees:manage")),
):
    return await service.delete_fee_schedule(fee_schedule_id, current_user["sub"])
