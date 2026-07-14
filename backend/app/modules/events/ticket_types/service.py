from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.events.events.repository import EventRepository
from app.modules.events.ticket_types.repository import TicketTypeRepository
from app.modules.events.ticket_types.schemas import TicketTypeCreate
from app.shared.resolver import LocationResolver


class TicketTypeService:
    def __init__(self):
        self.repository = TicketTypeRepository()
        self.event_repository = EventRepository()
        self.location_resolver = LocationResolver()

    async def _resolve_currency(self, event: dict, currency_id: str | None) -> str:
        country = await self.location_resolver.resolve_country(event["country_id"])
        return await self.location_resolver.resolve_currency(currency_id, country)

    async def create_ticket_type(self, data: TicketTypeCreate, user_id: str):
        event = await self.event_repository.get_by_id(data.event_id)

        if not event:
            raise HTTPException(status_code=404, detail="Event not found.")

        ensure_owner(event["organizer_id"], user_id)

        currency_id = await self._resolve_currency(event, data.currency_id)

        ticket_type = data.model_dump()
        ticket_type["category"] = ticket_type["category"].value
        ticket_type["quantity_available"] = ticket_type["quantity_total"]
        ticket_type["currency_id"] = currency_id
        ticket_type.update(BaseDocument.create())

        ticket_type = await self.repository.create(ticket_type)
        return self._format(ticket_type)

    async def get_ticket_types(
        self,
        page: int,
        limit: int,
        event_id: str | None,
        category: str | None,
    ):
        ticket_types = await self.repository.get_all(page, limit, event_id, category)
        return [self._format(t) for t in ticket_types]

    async def get_ticket_type(self, ticket_type_id: str):
        ticket_type = await self.repository.get_by_id(ticket_type_id)

        if not ticket_type:
            raise HTTPException(status_code=404, detail="Ticket type not found.")

        return self._format(ticket_type)

    async def update_ticket_type(self, ticket_type_id: str, data: TicketTypeCreate, user_id: str):
        ticket_type = await self.repository.get_by_id(ticket_type_id)

        if not ticket_type:
            raise HTTPException(status_code=404, detail="Ticket type not found.")

        event = await self.event_repository.get_by_id(ticket_type["event_id"])

        if not event:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(event["organizer_id"], user_id)

        currency_id = await self._resolve_currency(event, data.currency_id)

        # quantity_available isn't part of TicketTypeCreate, so this
        # $set never touches it - it's a live counter claimed/released
        # atomically by bookings (claim_tickets/release_tickets), and
        # recomputing it here from a value read moments ago would be a
        # read-then-write race against any booking claiming tickets
        # concurrently. quantity_total (the ceiling) isn't concurrently
        # mutated by anything else, so it's safe to update directly.
        update_data = data.model_dump()
        update_data["category"] = update_data["category"].value
        update_data["currency_id"] = currency_id
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(ticket_type_id, update_data)
        return self._format(updated)

    async def delete_ticket_type(self, ticket_type_id: str, user_id: str):
        ticket_type = await self.repository.get_by_id(ticket_type_id)

        if not ticket_type:
            raise HTTPException(status_code=404, detail="Ticket type not found.")

        event = await self.event_repository.get_by_id(ticket_type["event_id"])

        if not event:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(event["organizer_id"], user_id)

        deleted = await self.repository.soft_delete(
            ticket_type_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Ticket type not found.")

        return {"message": "Ticket type deleted successfully."}

    def _format(self, ticket_type):
        return {
            "id": str(ticket_type["_id"]),
            "event_id": ticket_type["event_id"],
            "category": ticket_type["category"],
            "base_price": ticket_type["base_price"],
            "currency_id": ticket_type["currency_id"],
            "quantity_total": ticket_type["quantity_total"],
            "quantity_available": ticket_type["quantity_available"],
            "description": ticket_type.get("description"),
            "is_active": ticket_type["is_active"],
            "created_at": ticket_type.get("created_at"),
            "updated_at": ticket_type.get("updated_at"),
        }
