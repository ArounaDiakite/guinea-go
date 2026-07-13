from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.subjects.schemas import SubjectCreate, SubjectResponse
from app.modules.education.subjects.service import SubjectService

router = APIRouter(
    prefix="/subjects",
    tags=["Subjects"],
)

service = SubjectService()


@router.post("/", response_model=SubjectResponse)
async def create_subject(
    data: SubjectCreate,
    current_user=Depends(require_permission("subjects:manage")),
):
    return await service.create_subject(data, current_user["sub"])


@router.get("/", response_model=list[SubjectResponse])
async def get_subjects(
    institution_id: str,
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user=Depends(get_current_user),
):
    return await service.get_subjects(institution_id, current_user["sub"], page, limit)


@router.get("/{subject_id}", response_model=SubjectResponse)
async def get_subject(
    subject_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_subject(subject_id, current_user["sub"])


@router.put("/{subject_id}", response_model=SubjectResponse)
async def update_subject(
    subject_id: str,
    data: SubjectCreate,
    current_user=Depends(require_permission("subjects:manage")),
):
    return await service.update_subject(subject_id, data, current_user["sub"])


@router.delete("/{subject_id}")
async def delete_subject(
    subject_id: str,
    current_user=Depends(require_permission("subjects:manage")),
):
    return await service.delete_subject(subject_id, current_user["sub"])
