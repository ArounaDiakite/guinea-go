from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user, require_permission
from app.modules.education.institutions.schemas import InstitutionCreate, InstitutionResponse
from app.modules.education.institutions.service import InstitutionService

router = APIRouter(
    prefix="/institutions",
    tags=["Institutions"],
)

service = InstitutionService()


@router.post("/", response_model=InstitutionResponse)
async def create_institution(
    data: InstitutionCreate,
    current_user=Depends(require_permission("institutions:manage")),
):
    return await service.create_institution(data, current_user["sub"])


@router.get("/me", response_model=InstitutionResponse)
async def get_my_institution(current_user=Depends(get_current_user)):
    return await service.get_my_institution(current_user["sub"])


@router.get("/{institution_id}", response_model=InstitutionResponse)
async def get_institution(
    institution_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_institution(institution_id, current_user["sub"])


@router.put("/{institution_id}", response_model=InstitutionResponse)
async def update_institution(
    institution_id: str,
    data: InstitutionCreate,
    current_user=Depends(require_permission("institutions:manage")),
):
    return await service.update_institution(institution_id, data, current_user["sub"])


@router.delete("/{institution_id}")
async def delete_institution(
    institution_id: str,
    current_user=Depends(require_permission("institutions:manage")),
):
    return await service.delete_institution(institution_id, current_user["sub"])
