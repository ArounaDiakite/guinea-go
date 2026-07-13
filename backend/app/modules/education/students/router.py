from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.students.schemas import StudentCreate, StudentResponse
from app.modules.education.students.service import StudentService

router = APIRouter(
    prefix="/students",
    tags=["Students"],
)

service = StudentService()


@router.post("/", response_model=StudentResponse)
async def create_student(
    data: StudentCreate,
    current_user=Depends(require_permission("students:manage")),
):
    return await service.create_student(data, current_user["sub"])


@router.get("/", response_model=list[StudentResponse])
async def get_students(
    institution_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    academic_unit_id: Optional[str] = None,
    current_user=Depends(get_current_user),
):
    return await service.get_students(
        institution_id, current_user["sub"], page, limit, academic_unit_id
    )


@router.get("/{student_id}", response_model=StudentResponse)
async def get_student(
    student_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_student(student_id, current_user["sub"])


@router.put("/{student_id}", response_model=StudentResponse)
async def update_student(
    student_id: str,
    data: StudentCreate,
    current_user=Depends(require_permission("students:manage")),
):
    return await service.update_student(student_id, data, current_user["sub"])


@router.delete("/{student_id}")
async def delete_student(
    student_id: str,
    current_user=Depends(require_permission("students:manage")),
):
    return await service.delete_student(student_id, current_user["sub"])
