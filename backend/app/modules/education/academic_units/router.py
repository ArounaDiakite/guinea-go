from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.academic_units.schemas import (
    AcademicUnitCreate,
    AcademicUnitResponse,
)
from app.modules.education.academic_units.service import AcademicUnitService
from app.modules.education.timeslots.schemas import ScheduleItemResponse
from app.modules.education.timeslots.service import TimeSlotService

router = APIRouter(
    prefix="/academic-units",
    tags=["Academic Units"],
)

service = AcademicUnitService()
timeslot_service = TimeSlotService()


@router.post("/", response_model=AcademicUnitResponse)
async def create_academic_unit(
    data: AcademicUnitCreate,
    current_user=Depends(require_permission("academic_units:manage")),
):
    return await service.create_academic_unit(data, current_user["sub"])


@router.get("/", response_model=list[AcademicUnitResponse])
async def get_academic_units(
    institution_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user=Depends(get_current_user),
):
    return await service.get_academic_units(institution_id, current_user["sub"], page, limit)


@router.get("/{academic_unit_id}", response_model=AcademicUnitResponse)
async def get_academic_unit(
    academic_unit_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_academic_unit(
        academic_unit_id, current_user["sub"], current_user["role"]
    )


@router.get("/{academic_unit_id}/schedule", response_model=list[ScheduleItemResponse])
async def get_academic_unit_schedule(
    academic_unit_id: str,
    current_user=Depends(get_current_user),
):
    return await timeslot_service.get_schedule(
        academic_unit_id, current_user["sub"], current_user["role"]
    )


@router.put("/{academic_unit_id}", response_model=AcademicUnitResponse)
async def update_academic_unit(
    academic_unit_id: str,
    data: AcademicUnitCreate,
    current_user=Depends(require_permission("academic_units:manage")),
):
    return await service.update_academic_unit(academic_unit_id, data, current_user["sub"])


@router.delete("/{academic_unit_id}")
async def delete_academic_unit(
    academic_unit_id: str,
    current_user=Depends(require_permission("academic_units:manage")),
):
    return await service.delete_academic_unit(academic_unit_id, current_user["sub"])
