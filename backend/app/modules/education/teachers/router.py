from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.teachers.schemas import TeacherCreate, TeacherResponse
from app.modules.education.teachers.service import TeacherService

router = APIRouter(
    prefix="/teachers",
    tags=["Teachers"],
)

service = TeacherService()


@router.post("/", response_model=TeacherResponse)
async def create_teacher(
    data: TeacherCreate,
    current_user=Depends(require_permission("teachers:manage")),
):
    return await service.create_teacher(data, current_user["sub"])


@router.get("/", response_model=list[TeacherResponse])
async def get_teachers(
    institution_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    academic_unit_id: Optional[str] = None,
    current_user=Depends(get_current_user),
):
    return await service.get_teachers(
        institution_id, current_user["sub"], page, limit, academic_unit_id
    )


@router.get("/me", response_model=TeacherResponse)
async def get_my_teacher_profile(current_user=Depends(get_current_user)):
    return await service.get_my_teacher_profile(current_user["sub"])


@router.get("/{teacher_id}", response_model=TeacherResponse)
async def get_teacher(
    teacher_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_teacher(teacher_id, current_user["sub"])


@router.put("/{teacher_id}", response_model=TeacherResponse)
async def update_teacher(
    teacher_id: str,
    data: TeacherCreate,
    current_user=Depends(require_permission("teachers:manage")),
):
    return await service.update_teacher(teacher_id, data, current_user["sub"])


@router.delete("/{teacher_id}")
async def delete_teacher(
    teacher_id: str,
    current_user=Depends(require_permission("teachers:manage")),
):
    return await service.delete_teacher(teacher_id, current_user["sub"])
