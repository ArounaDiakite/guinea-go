from fastapi import APIRouter, Depends

from app.admin.schemas import AdminUserResponse
from app.admin.service import AdminService
from app.core.constants import UserRole
from app.core.dependencies import require_role
from app.modules.education.institutions.schemas import (
    InstitutionAccountCreate,
    InstitutionResponse,
    InstitutionWithAccountResponse,
)
from app.modules.education.institutions.service import InstitutionService

router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
)

service = AdminService()
institution_service = InstitutionService()


@router.get("/users/pending", response_model=list[AdminUserResponse])
async def get_pending_users(
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.get_pending_users()


@router.patch("/users/{user_id}/activate", response_model=AdminUserResponse)
async def activate_user(
    user_id: str,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.activate_user(user_id)


@router.post("/institutions", response_model=InstitutionWithAccountResponse)
async def create_institution(
    data: InstitutionAccountCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await institution_service.create_public_institution(data)


@router.get("/institutions", response_model=list[InstitutionResponse])
async def get_institutions(
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await institution_service.get_all_institutions()
