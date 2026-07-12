from fastapi import APIRouter, Depends

from app.core.dependencies import get_current_user
from app.identity.users.schemas import (
    ChangePasswordRequest,
    UpdateProfileRequest,
    UserProfileResponse,
)
from app.identity.users.service import UserService

router = APIRouter(
    prefix="/users",
    tags=["Users"],
)

service = UserService()


@router.get("/me", response_model=UserProfileResponse)
async def get_me(current_user=Depends(get_current_user)):
    return await service.get_me(current_user["sub"])


@router.put("/me", response_model=UserProfileResponse)
async def update_me(
    data: UpdateProfileRequest,
    current_user=Depends(get_current_user),
):
    return await service.update_me(current_user["sub"], data)


@router.put("/change-password")
async def change_password(
    data: ChangePasswordRequest,
    current_user=Depends(get_current_user),
):
    return await service.change_password(current_user["sub"], data)