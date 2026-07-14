from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.commerce.stores.repository import StoreRepository
from app.modules.commerce.stores.schemas import StoreCreate
from app.shared.resolver import LocationResolver


class StoreService:
    def __init__(self):
        self.repository = StoreRepository()
        self.location_resolver = LocationResolver()

    async def _validate_location(self, data: StoreCreate):
        country = await self.location_resolver.resolve_country(data.country_id)
        await self.location_resolver.resolve_city(data.city_id, country)

    async def create_store(self, data: StoreCreate, owner_id: str):
        # A store_manager may run more than one store - no 1:1
        # constraint here, the simplest option that still leaves room
        # for a "one store only" rule later without a data migration.
        await self._validate_location(data)

        store = data.model_dump()
        store.update(BaseDocument.create())
        store["owner_id"] = owner_id
        store["is_verified"] = False

        store = await self.repository.create(store)
        return self._format(store)

    async def get_stores(self, page: int, limit: int, search: str | None, city_id: str | None, owner_id: str | None):
        stores = await self.repository.get_all(page, limit, search, city_id, owner_id)
        return [self._format(store) for store in stores]

    async def get_store(self, store_id: str):
        store = await self.repository.get_by_id(store_id)

        if not store:
            raise HTTPException(status_code=404, detail="Store not found.")

        return self._format(store)

    async def update_store(self, store_id: str, data: StoreCreate, user_id: str):
        store = await self.repository.get_by_id(store_id)

        if not store:
            raise HTTPException(status_code=404, detail="Store not found.")

        ensure_owner(store["owner_id"], user_id)

        await self._validate_location(data)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        store = await self.repository.update(store_id, update_data)
        return self._format(store)

    async def delete_store(self, store_id: str, user_id: str):
        store = await self.repository.get_by_id(store_id)

        if not store:
            raise HTTPException(status_code=404, detail="Store not found.")

        ensure_owner(store["owner_id"], user_id)

        deleted = await self.repository.soft_delete(
            store_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Store not found.")

        return {"message": "Store deleted successfully."}

    def _format(self, store):
        return {
            "id": str(store["_id"]),
            "name": store["name"],
            "description": store.get("description"),
            "logo_url": store.get("logo_url"),
            "phone": store["phone"],
            "email": store["email"],
            "country_id": store["country_id"],
            "city_id": store["city_id"],
            "address": store["address"],
            "shipping_info": store.get("shipping_info"),
            "owner_id": store["owner_id"],
            "is_verified": store["is_verified"],
            "is_active": store["is_active"],
            "created_at": store.get("created_at"),
            "updated_at": store.get("updated_at"),
        }
