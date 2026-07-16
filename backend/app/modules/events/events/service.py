from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.events.events.repository import EventRepository
from app.modules.events.events.schemas import EventCreate
from app.shared.resolver import LocationResolver


class EventService:
    def __init__(self):
        self.repository = EventRepository()
        self.location_resolver = LocationResolver()

    async def _validate_location(self, data: EventCreate):
        country = await self.location_resolver.resolve_country(data.country_id)
        await self.location_resolver.resolve_city(data.city_id, country)

    async def create_event(self, data: EventCreate, organizer_id: str):
        await self._validate_location(data)

        event = data.model_dump()
        event["category"] = event["category"].value
        event.update(BaseDocument.create())
        event["organizer_id"] = organizer_id
        event["is_verified"] = False

        event = await self.repository.create(event)
        return self._format(event)

    async def get_events(
        self,
        page: int,
        limit: int,
        search: str | None,
        city_id: str | None,
        category: str | None,
        organizer_id: str | None = None,
    ):
        events = await self.repository.get_all(page, limit, search, city_id, category, organizer_id)
        return [self._format(event) for event in events]

    async def get_event(self, event_id: str):
        event = await self.repository.get_by_id(event_id)

        if not event:
            raise HTTPException(status_code=404, detail="Event not found.")

        return self._format(event)

    async def update_event(self, event_id: str, data: EventCreate, user_id: str):
        event = await self.repository.get_by_id(event_id)

        if not event:
            raise HTTPException(status_code=404, detail="Event not found.")

        ensure_owner(event["organizer_id"], user_id)

        await self._validate_location(data)

        update_data = data.model_dump()
        update_data["category"] = update_data["category"].value
        update_data.update(BaseDocument.update())

        event = await self.repository.update(event_id, update_data)
        return self._format(event)

    async def delete_event(self, event_id: str, user_id: str):
        event = await self.repository.get_by_id(event_id)

        if not event:
            raise HTTPException(status_code=404, detail="Event not found.")

        ensure_owner(event["organizer_id"], user_id)

        deleted = await self.repository.soft_delete(
            event_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Event not found.")

        return {"message": "Event deleted successfully."}

    def _format(self, event):
        return {
            "id": str(event["_id"]),
            "name": event["name"],
            "description": event.get("description"),
            "venue": event["venue"],
            "country_id": event["country_id"],
            "city_id": event["city_id"],
            "start_datetime": event["start_datetime"],
            "end_datetime": event["end_datetime"],
            "category": event["category"],
            "organizer_id": event["organizer_id"],
            "is_verified": event["is_verified"],
            "is_active": event["is_active"],
            "created_at": event.get("created_at"),
            "updated_at": event.get("updated_at"),
        }
