from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.attendance.schemas import AttendanceRecordResponse
from app.modules.education.attendance.service import AttendanceService
from app.modules.education.grades.schemas import GradeCreate, GradeResponse, Period, ReportCard
from app.modules.education.grades.service import GradeService
from app.modules.education.students.schemas import StudentCreate, StudentResponse
from app.modules.education.students.service import StudentService

router = APIRouter(
    prefix="/students",
    tags=["Students"],
)

service = StudentService()
attendance_service = AttendanceService()
grade_service = GradeService()


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


@router.get("/{student_id}/attendance", response_model=list[AttendanceRecordResponse])
async def get_student_attendance(
    student_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user=Depends(get_current_user),
):
    return await attendance_service.get_student_attendance(
        student_id, current_user["sub"], page, limit
    )


@router.post("/{student_id}/grades", response_model=GradeResponse)
async def add_grade(
    student_id: str,
    data: GradeCreate,
    current_user=Depends(require_permission("grades:manage")),
):
    return await grade_service.add_grade(student_id, data, current_user["sub"])


@router.get("/{student_id}/grades", response_model=list[GradeResponse])
async def get_grades(
    student_id: str,
    period: Optional[Period] = None,
    current_user=Depends(get_current_user),
):
    return await grade_service.get_grades(
        student_id, current_user["sub"], period.value if period else None
    )


@router.put("/{student_id}/grades/{grade_id}", response_model=GradeResponse)
async def update_grade(
    student_id: str,
    grade_id: str,
    data: GradeCreate,
    current_user=Depends(require_permission("grades:manage")),
):
    return await grade_service.update_grade(student_id, grade_id, data, current_user["sub"])


@router.get("/{student_id}/report-card", response_model=ReportCard)
async def get_report_card(
    student_id: str,
    period: Period,
    current_user=Depends(get_current_user),
):
    return await grade_service.get_report_card(student_id, current_user["sub"], period.value)


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
