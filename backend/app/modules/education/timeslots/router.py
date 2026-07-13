from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.timeslots.schemas import TimeSlotCreate, TimeSlotResponse
from app.modules.education.timeslots.service import TimeSlotService

router = APIRouter(
    prefix="/timeslots",
    tags=["Time Slots"],
)

service = TimeSlotService()


@router.post("/", response_model=TimeSlotResponse)
async def create_timeslot(
    data: TimeSlotCreate,
    current_user=Depends(require_permission("timeslots:manage")),
):
    return await service.create_timeslot(data, current_user["sub"])


@router.get("/{timeslot_id}", response_model=TimeSlotResponse)
async def get_timeslot(
    timeslot_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_timeslot(timeslot_id, current_user["sub"])


@router.put("/{timeslot_id}", response_model=TimeSlotResponse)
async def update_timeslot(
    timeslot_id: str,
    data: TimeSlotCreate,
    current_user=Depends(require_permission("timeslots:manage")),
):
    return await service.update_timeslot(timeslot_id, data, current_user["sub"])


@router.delete("/{timeslot_id}")
async def delete_timeslot(
    timeslot_id: str,
    current_user=Depends(require_permission("timeslots:manage")),
):
    return await service.delete_timeslot(timeslot_id, current_user["sub"])
