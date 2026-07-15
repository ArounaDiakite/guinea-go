from fastapi import APIRouter, Depends

from app.core.constants import UserRole
from app.core.dependencies import get_current_user, require_role
from app.modules.transport.tickets.schemas import TicketResponse, TicketValidationResponse
from app.modules.transport.tickets.service import TicketService

# No shared prefix - this router covers two different existing
# resources (a booking's ticket, and ticket validation by code) rather
# than owning a "/tickets" collection endpoint of its own.
router = APIRouter(tags=["Tickets"])

service = TicketService()


@router.get("/bookings/{booking_id}/ticket", response_model=TicketResponse)
async def get_ticket_for_booking(
    booking_id: str,
    current_user=Depends(get_current_user),
):
    return await service.get_ticket_for_booking(booking_id, current_user["sub"])


@router.post("/tickets/{code}/validate", response_model=TicketValidationResponse)
async def validate_ticket(
    code: str,
    current_user=Depends(require_role(UserRole.DRIVER, UserRole.COMPANY_OWNER)),
):
    return await service.validate_ticket(code, current_user["sub"], current_user["role"])
