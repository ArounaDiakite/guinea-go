from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.hotels.hotels.repository import HotelRepository
from app.modules.hotels.rooms.repository import RoomRepository
from app.modules.hotels.rooms.schemas import RoomCreate


class RoomService:
    def __init__(self):
        self.repository = RoomRepository()
        self.hotel_repository = HotelRepository()

    async def create_room(self, data: RoomCreate, user_id: str):
        hotel = await self.hotel_repository.get_by_id(data.hotel_id)

        if not hotel:
            raise HTTPException(status_code=404, detail="Hotel not found.")

        ensure_owner(hotel["owner_id"], user_id)

        room = data.model_dump()
        room["room_type"] = room["room_type"].value
        room["status"] = room["status"].value
        room.update(BaseDocument.create())

        room = await self.repository.create(room)
        return self._format(room)

    async def get_rooms(
        self,
        page: int,
        limit: int,
        hotel_id: str | None,
        room_type: str | None,
        status: str | None,
    ):
        rooms = await self.repository.get_all(page, limit, hotel_id, room_type, status)
        return [self._format(room) for room in rooms]

    async def get_room(self, room_id: str):
        room = await self.repository.get_by_id(room_id)

        if not room:
            raise HTTPException(status_code=404, detail="Room not found.")

        return self._format(room)

    async def update_room(self, room_id: str, data: RoomCreate, user_id: str):
        room = await self.repository.get_by_id(room_id)

        if not room:
            raise HTTPException(status_code=404, detail="Room not found.")

        hotel = await self.hotel_repository.get_by_id(room["hotel_id"])

        if not hotel:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(hotel["owner_id"], user_id)

        update_data = data.model_dump()
        update_data["room_type"] = update_data["room_type"].value
        update_data["status"] = update_data["status"].value
        update_data.update(BaseDocument.update())

        updated_room = await self.repository.update(room_id, update_data)
        return self._format(updated_room)

    async def delete_room(self, room_id: str, user_id: str):
        room = await self.repository.get_by_id(room_id)

        if not room:
            raise HTTPException(status_code=404, detail="Room not found.")

        hotel = await self.hotel_repository.get_by_id(room["hotel_id"])

        if not hotel:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(hotel["owner_id"], user_id)

        deleted = await self.repository.soft_delete(
            room_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Room not found.")

        return {"message": "Room deleted successfully."}

    def _format(self, room):
        return {
            "id": str(room["_id"]),
            "hotel_id": room["hotel_id"],
            "room_number": room["room_number"],
            "room_type": room["room_type"],
            "capacity": room["capacity"],
            "base_price": room["base_price"],
            "description": room.get("description"),
            "status": room["status"],
            "is_active": room["is_active"],
            "created_at": room.get("created_at"),
            "updated_at": room.get("updated_at"),
        }
