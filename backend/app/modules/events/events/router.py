from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_current_user
from app.modules.events.events.schemas import EventCreate, EventResponse
from app.modules.events.events.service import EventService

router = APIRouter(
    prefix="/events",
    tags=["Events"],
)

service = EventService()


@router.post("/", response_model=EventResponse)
async def create_event(
    data: EventCreate,
    current_user=Depends(get_current_user),
):
    return await service.create_event(data, current_user["sub"])


@router.get("/", response_model=list[EventResponse])
async def get_events(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    city: Optional[str] = None,
    category: Optional[str] = None,
):
    return await service.get_events(page, limit, search, city, category)


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(event_id: str):
    return await service.get_event(event_id)


@router.put("/{event_id}", response_model=EventResponse)
async def update_event(
    event_id: str,
    data: EventCreate,
    current_user=Depends(get_current_user),
):
    return await service.update_event(event_id, data, current_user["sub"])


@router.delete("/{event_id}")
async def delete_event(
    event_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_event(event_id, current_user["sub"])
