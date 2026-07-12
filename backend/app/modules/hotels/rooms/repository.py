from bson import ObjectId

from app.database.mongodb import db


class RoomRepository:
    def __init__(self):
        self.collection = db.rooms

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, room_id: str):
        if not ObjectId.is_valid(room_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(room_id), "is_deleted": False}
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        hotel_id: str | None = None,
        room_type: str | None = None,
        status: str | None = None,
    ):
        query = {"is_deleted": False}

        if hotel_id:
            query["hotel_id"] = hotel_id

        if room_type:
            query["room_type"] = room_type

        if status:
            query["status"] = status

        cursor = (
            self.collection.find(query)
            .sort("room_number", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, room_id: str, data: dict):
        if not ObjectId.is_valid(room_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(room_id)},
            {"$set": data},
        )

        return await self.get_by_id(room_id)

    async def soft_delete(self, room_id: str, data: dict):
        if not ObjectId.is_valid(room_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(room_id)},
            {"$set": data},
        )

        return result.modified_count > 0
