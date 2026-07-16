from fastapi import APIRouter, Depends

from app.core.constants import UserRole
from app.core.dependencies import get_current_user, require_role
from app.modules.events.event_tickets.schemas import EventTicketResponse, EventTicketValidationResponse
from app.modules.events.event_tickets.service import EventTicketService

# No shared prefix - this router covers two different existing
# resources (a booking's ticket, and ticket validation by code) rather
# than owning an "/event-tickets" collection endpoint of its own -
# same shape as transport/tickets/router.py.
router = APIRouter(tags=["Event Tickets"])

service = EventTicketService()


@router.get("/event-bookings/{booking_id}/ticket", response_model=EventTicketResponse)
async def get_ticket_for_booking(
    booking_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_ticket_for_booking(booking_id, current_user["sub"])


@router.post("/event-tickets/{code}/validate", response_model=EventTicketValidationResponse)
async def validate_ticket(
    code: str,
    current_user=Depends(require_role(UserRole.EVENT_ORGANIZER)),
):
    return await service.validate_ticket(code, current_user["sub"], current_user["role"])
