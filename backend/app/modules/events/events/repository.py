from bson import ObjectId

from app.database.mongodb import db


class EventRepository:
    def __init__(self):
        self.collection = db.events

    async def create(self, event: dict):
        result = await self.collection.insert_one(event)
        event["_id"] = result.inserted_id
        return event

    async def get_all(
        self,
        page: int = 1,
        limit: int = 20,
        search: str | None = None,
        city_id: str | None = None,
        category: str | None = None,
        organizer_id: str | None = None,
    ):
        query = {"is_deleted": False}

        if search:
            query["name"] = {"$regex": search, "$options": "i"}

        if city_id:
            query["city_id"] = city_id

        if category:
            query["category"] = category

        if organizer_id:
            query["organizer_id"] = organizer_id

        cursor = (
            self.collection.find(query)
            .sort("start_datetime", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def get_by_id(self, event_id: str):
        if not ObjectId.is_valid(event_id):
            return None

        return await self.collection.find_one({
            "_id": ObjectId(event_id),
            "is_deleted": False,
        })

    async def update(self, event_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(event_id), "is_deleted": False},
            {"$set": data},
        )
        return await self.get_by_id(event_id)

    async def soft_delete(self, event_id: str, data: dict):
        result = await self.collection.update_one(
            {"_id": ObjectId(event_id), "is_deleted": False},
            {"$set": data},
        )
        return result.modified_count > 0
