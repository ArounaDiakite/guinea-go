from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user, require_any_permission, require_permission
from app.modules.education.attendance.schemas import (
    AttendanceRecordResponse,
    AttendanceSubmit,
)
from app.modules.education.attendance.service import AttendanceService
from app.modules.education.timeslots.schemas import TimeSlotCreate, TimeSlotResponse
from app.modules.education.timeslots.service import TimeSlotService

router = APIRouter(
    prefix="/timeslots",
    tags=["Time Slots"],
)

service = TimeSlotService()
attendance_service = AttendanceService()


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


@router.post("/{timeslot_id}/attendance", response_model=list[AttendanceRecordResponse])
async def submit_attendance(
    timeslot_id: str,
    data: AttendanceSubmit,
    current_user=Depends(require_any_permission("attendance:manage", "attendance:manage_own")),
):
    return await attendance_service.submit_attendance(
        timeslot_id, data, current_user["sub"], current_user["role"]
    )


@router.put("/{timeslot_id}/attendance", response_model=list[AttendanceRecordResponse])
async def correct_attendance(
    timeslot_id: str,
    data: AttendanceSubmit,
    current_user=Depends(require_any_permission("attendance:manage", "attendance:manage_own")),
):
    return await attendance_service.update_attendance(
        timeslot_id, data, current_user["sub"], current_user["role"]
    )
