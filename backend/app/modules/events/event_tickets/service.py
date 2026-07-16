import secrets

from bson import ObjectId
from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError

from app.common.base_model import BaseDocument
from app.core.constants import UserRole
from app.core.utils import utc_now
from app.identity.users.repository import UserRepository
from app.modules.events.bookings.repository import EventBookingRepository
from app.modules.events.event_tickets.repository import EventTicketRepository
from app.modules.events.events.repository import EventRepository
from app.modules.events.ticket_types.repository import TicketTypeRepository

# Ambiguous-looking characters (0/O, 1/I) stripped, since this is also
# meant to be readable off the ticket screen if the QR scan ever fails.
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_CODE_LENGTH = 10


def _generate_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


class EventTicketService:
    def __init__(self):
        self.repository = EventTicketRepository()
        self.booking_repository = EventBookingRepository()
        self.event_repository = EventRepository()
        self.ticket_type_repository = TicketTypeRepository()
        self.user_repository = UserRepository()

    async def issue_for_booking(self, booking: dict):
        """Called once an event booking transitions to CONFIRMED (see
        payments/service.py::complete_sandbox_payment) - not exposed
        through any route. Idempotent: a booking that already has a
        ticket (e.g. this got called twice for the same confirmation)
        just returns the existing one instead of issuing a second.
        One ticket document covers the whole booking (quantity included)
        rather than one per admitted person - same "the booking is the
        purchase, the ticket is the door-scan artifact" split as
        transport, just without a per-seat identity to also track."""
        booking_id = str(booking["_id"])
        existing = await self.repository.get_by_booking(booking_id)

        if existing:
            return existing

        code = _generate_code()

        # 32^10 keyspace - a collision is vanishingly unlikely, but
        # checked and retried rather than trusted blindly, since `code`
        # carries a unique index.
        for _ in range(3):
            if not await self.repository.get_by_code(code):
                break
            code = _generate_code()

        ticket_doc = {
            "_id": ObjectId(),
            "booking_id": booking_id,
            "event_id": booking["event_id"],
            "ticket_type_id": booking["ticket_type_id"],
            "passenger_id": booking["passenger_id"],
            "quantity": booking["quantity"],
            "code": code,
            "status": "VALID",
            "used_at": None,
        }
        ticket_doc.update(BaseDocument.create())

        try:
            return await self.repository.create(ticket_doc)
        except DuplicateKeyError:
            # Another concurrent call already issued this booking's
            # ticket (or a code collision survived the retries above,
            # in which case booking_id's own unique index is what
            # actually saved us) - either way, the record that matters
            # is whichever one is now on file for this booking.
            return await self.repository.get_by_booking(booking_id)

    async def get_ticket_for_booking(self, booking_id: str, passenger_id: str):
        booking = await self.booking_repository.get_by_id(booking_id)

        if not booking:
            raise HTTPException(status_code=404, detail="Booking not found.")

        if booking["passenger_id"] != passenger_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if booking["status"] != "CONFIRMED":
            raise HTTPException(
                status_code=400,
                detail="This booking is not confirmed yet - no ticket has been issued.",
            )

        ticket = await self.repository.get_by_booking(booking_id)

        if not ticket:
            raise HTTPException(status_code=404, detail="No ticket found for this booking.")

        return self._format(ticket)

    async def validate_ticket(self, code: str, current_user_id: str, current_user_role: str):
        ticket = await self.repository.get_by_code(code)

        if not ticket:
            raise HTTPException(status_code=404, detail="Ticket not found.")

        event = await self.event_repository.get_by_id(ticket["event_id"])

        if not event:
            raise HTTPException(status_code=404, detail="Event not found for this ticket.")

        self._ensure_can_validate(event, current_user_id, current_user_role)

        if ticket["status"] == "USED":
            raise HTTPException(status_code=400, detail="This ticket has already been used.")

        if ticket["status"] == "CANCELLED":
            raise HTTPException(status_code=400, detail="This ticket has been cancelled.")

        validated = await self.repository.transition_status_if(
            str(ticket["_id"]),
            "VALID",
            {"status": "USED", "used_at": utc_now(), **BaseDocument.update()},
        )

        if not validated:
            raise HTTPException(status_code=400, detail="This ticket has already been used.")

        validated_ticket = await self.repository.get_by_id(str(ticket["_id"]))
        passenger = await self.user_repository.get_by_id(validated_ticket["passenger_id"])
        ticket_type = await self.ticket_type_repository.get_by_id(validated_ticket["ticket_type_id"])

        return {
            **self._format(validated_ticket),
            "passenger_name": f"{passenger['first_name']} {passenger['last_name']}" if passenger else "?",
            "ticket_category": ticket_type["category"] if ticket_type else "?",
        }

    def _ensure_can_validate(self, event: dict, user_id: str, role: str):
        """An event_organizer may only validate tickets for events they
        themselves organize - not scoped by require_role alone, which
        only checks the role itself."""
        if role == UserRole.SYSTEM_ADMINISTRATOR:
            return

        if role == UserRole.EVENT_ORGANIZER and event["organizer_id"] == user_id:
            return

        raise HTTPException(
            status_code=403,
            detail="You are not allowed to validate tickets for this event.",
        )

    def _format(self, ticket):
        return {
            "id": str(ticket["_id"]),
            "booking_id": ticket["booking_id"],
            "event_id": ticket["event_id"],
            "ticket_type_id": ticket["ticket_type_id"],
            "passenger_id": ticket["passenger_id"],
            "quantity": ticket["quantity"],
            "code": ticket["code"],
            "status": ticket["status"],
            "used_at": ticket.get("used_at"),
            "created_at": ticket.get("created_at"),
            "updated_at": ticket.get("updated_at"),
        }
