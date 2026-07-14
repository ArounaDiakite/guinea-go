from bson import ObjectId

from app.database.mongodb import db


class HotelRepository:
    def __init__(self):
        self.collection = db.hotels

    async def create(self, hotel: dict):
        result = await self.collection.insert_one(hotel)
        hotel["_id"] = result.inserted_id
        return hotel

    async def get_all(
        self,
        page: int = 1,
        limit: int = 20,
        search: str | None = None,
        city_id: str | None = None,
    ):
        query = {"is_deleted": False}

        if search:
            query["name"] = {"$regex": search, "$options": "i"}

        if city_id:
            query["city_id"] = city_id

        cursor = (
            self.collection.find(query)
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def get_by_id(self, hotel_id: str):
        if not ObjectId.is_valid(hotel_id):
            return None

        return await self.collection.find_one({
            "_id": ObjectId(hotel_id),
            "is_deleted": False,
        })

    async def update(self, hotel_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(hotel_id), "is_deleted": False},
            {"$set": data},
        )
        return await self.get_by_id(hotel_id)

    async def soft_delete(self, hotel_id: str, data: dict):
        result = await self.collection.update_one(
            {"_id": ObjectId(hotel_id), "is_deleted": False},
            {"$set": data},
        )
        return result.modified_count > 0
