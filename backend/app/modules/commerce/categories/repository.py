from bson import ObjectId

from app.database.mongodb import db


class CategoryRepository:
    def __init__(self):
        self.collection = db.categories

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, category_id: str):
        if not ObjectId.is_valid(category_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(category_id), "is_deleted": False}
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 50,
        search: str | None = None,
        category_parent_id: str | None = None,
    ):
        query = {"is_deleted": False}

        if search:
            query["name"] = {"$regex": search, "$options": "i"}

        if category_parent_id:
            query["category_parent_id"] = category_parent_id

        cursor = (
            self.collection.find(query)
            .sort("name", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, category_id: str, data: dict):
        if not ObjectId.is_valid(category_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(category_id)},
            {"$set": data},
        )

        return await self.get_by_id(category_id)

    async def soft_delete(self, category_id: str, data: dict):
        if not ObjectId.is_valid(category_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(category_id)},
            {"$set": data},
        )

        return result.modified_count > 0
