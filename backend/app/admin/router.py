from fastapi import APIRouter, Depends

from app.admin.schemas import AdminUserResponse
from app.admin.service import AdminService
from app.core.constants import UserRole
from app.core.dependencies import require_role

router = APIRouter(
    prefix="/admin",
    tags=["Admin"],
)

service = AdminService()


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
