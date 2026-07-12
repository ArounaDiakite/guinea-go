from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.hotels.hotels.repository import HotelRepository
from app.modules.hotels.hotels.schemas import HotelCreate


class HotelService:
    def __init__(self):
        self.repository = HotelRepository()

    async def create_hotel(self, data: HotelCreate, owner_id: str):
        hotel = data.model_dump()
        hotel.update(BaseDocument.create())
        hotel["owner_id"] = owner_id
        hotel["is_verified"] = False

        hotel = await self.repository.create(hotel)
        return self._format(hotel)

    async def get_hotels(self, page: int, limit: int, search: str | None, city: str | None):
        hotels = await self.repository.get_all(page, limit, search, city)
        return [self._format(hotel) for hotel in hotels]

    async def get_hotel(self, hotel_id: str):
        hotel = await self.repository.get_by_id(hotel_id)

        if not hotel:
            raise HTTPException(status_code=404, detail="Hotel not found.")

        return self._format(hotel)

    async def update_hotel(self, hotel_id: str, data: HotelCreate, user_id: str):
        hotel = await self.repository.get_by_id(hotel_id)

        if not hotel:
            raise HTTPException(status_code=404, detail="Hotel not found.")

        ensure_owner(hotel["owner_id"], user_id)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        hotel = await self.repository.update(hotel_id, update_data)
        return self._format(hotel)

    async def delete_hotel(self, hotel_id: str, user_id: str):
        hotel = await self.repository.get_by_id(hotel_id)

        if not hotel:
            raise HTTPException(status_code=404, detail="Hotel not found.")

        ensure_owner(hotel["owner_id"], user_id)

        deleted = await self.repository.soft_delete(
            hotel_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Hotel not found.")

        return {"message": "Hotel deleted successfully."}

    def _format(self, hotel):
        return {
            "id": str(hotel["_id"]),
            "name": hotel["name"],
            "description": hotel.get("description"),
            "phone": hotel["phone"],
            "email": hotel["email"],
            "website": hotel.get("website"),
            "country_code": hotel["country_code"],
            "city": hotel["city"],
            "address": hotel["address"],
            "amenities": hotel.get("amenities", []),
            "owner_id": hotel["owner_id"],
            "is_verified": hotel["is_verified"],
            "is_active": hotel["is_active"],
            "created_at": hotel.get("created_at"),
            "updated_at": hotel.get("updated_at"),
        }
