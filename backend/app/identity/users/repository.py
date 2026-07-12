from bson import ObjectId

from app.database.mongodb import db


class UserRepository:
    def __init__(self):
        self.collection = db.users

    async def get_by_id(self, user_id: str):
        return await self.collection.find_one({"_id": ObjectId(user_id)})

    async def update_by_id(self, user_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": data},
        )
        return await self.get_by_id(user_id)