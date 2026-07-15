from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.notifications.schemas import NotificationResponse
from app.notifications.service import NotificationService

router = APIRouter(
    prefix="/notifications",
    tags=["Notifications"],
)

service = NotificationService()


@router.get("/me", response_model=list[NotificationResponse])
async def get_my_notifications(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=200),
    current_user=Depends(get_current_user),
):
    return await service.get_my_notifications(current_user["sub"], page, limit)


@router.patch("/{notification_id}/read", response_model=NotificationResponse)
async def mark_as_read(
    notification_id: str,
    current_user=Depends(get_current_user),
):
    return await service.mark_as_read(notification_id, current_user["sub"])
