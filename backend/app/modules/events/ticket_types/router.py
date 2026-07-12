from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.constants import UserRole
from app.core.dependencies import require_permission, require_role
from app.modules.events.bookings.schemas import EventBookingCreate, EventBookingResponse
from app.modules.events.bookings.service import EventBookingService
from app.modules.events.ticket_types.schemas import TicketTypeCreate, TicketTypeResponse
from app.modules.events.ticket_types.service import TicketTypeService

router = APIRouter(
    prefix="/ticket-types",
    tags=["Ticket Types"],
)

service = TicketTypeService()
booking_service = EventBookingService()


@router.post("/", response_model=TicketTypeResponse)
async def create_ticket_type(
    data: TicketTypeCreate,
    current_user=Depends(require_permission("events:manage")),
):
    return await service.create_ticket_type(data, current_user["sub"])


@router.get("/", response_model=list[TicketTypeResponse])
async def get_ticket_types(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    event_id: Optional[str] = None,
    category: Optional[str] = None,
):
    return await service.get_ticket_types(page, limit, event_id, category)


@router.get("/{ticket_type_id}", response_model=TicketTypeResponse)
async def get_ticket_type(ticket_type_id: str):
    return await service.get_ticket_type(ticket_type_id)


@router.put("/{ticket_type_id}", response_model=TicketTypeResponse)
async def update_ticket_type(
    ticket_type_id: str,
    data: TicketTypeCreate,
    current_user=Depends(require_permission("events:manage")),
):
    return await service.update_ticket_type(ticket_type_id, data, current_user["sub"])


@router.delete("/{ticket_type_id}")
async def delete_ticket_type(
    ticket_type_id: str,
    current_user=Depends(require_permission("events:manage")),
):
    return await service.delete_ticket_type(ticket_type_id, current_user["sub"])


@router.post("/{ticket_type_id}/bookings", response_model=EventBookingResponse)
async def create_booking(
    ticket_type_id: str,
    data: EventBookingCreate,
    current_user=Depends(require_role(UserRole.PASSENGER)),
):
    return await booking_service.create_booking(ticket_type_id, data, current_user["sub"])
