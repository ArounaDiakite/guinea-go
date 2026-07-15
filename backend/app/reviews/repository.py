from bson import ObjectId

from app.database.mongodb import db


class ReviewRepository:
    def __init__(self):
        self.collection = db.reviews

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, review_id: str):
        if not ObjectId.is_valid(review_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(review_id), "is_deleted": False}
        )

    async def get_by_author_and_target(self, author_id: str, target_type: str, target_id: str):
        return await self.collection.find_one({
            "author_id": author_id,
            "target_type": target_type,
            "target_id": target_id,
            "is_deleted": False,
        })

    async def get_by_target(self, target_type: str, target_id: str):
        cursor = self.collection.find(
            {"target_type": target_type, "target_id": target_id, "is_deleted": False}
        ).sort("created_at", -1)
        return await cursor.to_list(length=None)

    async def update(self, review_id: str, data: dict):
        if not ObjectId.is_valid(review_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(review_id)},
            {"$set": data},
        )

        return await self.get_by_id(review_id)

    async def soft_delete(self, review_id: str, data: dict):
        if not ObjectId.is_valid(review_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(review_id)},
            {"$set": data},
        )

        return result.modified_count > 0
