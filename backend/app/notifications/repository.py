from bson import ObjectId

from app.database.mongodb import db


class NotificationRepository:
    def __init__(self):
        self.collection = db.notifications

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, notification_id: str):
        if not ObjectId.is_valid(notification_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(notification_id)})

    async def get_by_user(self, user_id: str, page: int = 1, limit: int = 50):
        cursor = (
            self.collection.find({"user_id": user_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update(self, notification_id: str, data: dict):
        if not ObjectId.is_valid(notification_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(notification_id)},
            {"$set": data},
        )

        return await self.get_by_id(notification_id)
