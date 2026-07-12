from bson import ObjectId

from app.database.mongodb import db


class RouteRepository:
    def __init__(self):
        self.collection = db.routes

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, route_id: str):
        if not ObjectId.is_valid(route_id):
            return None

        return await self.collection.find_one({
            "_id": ObjectId(route_id),
            "is_deleted": False,
        })

    async def get_by_code(self, route_code: str):
        return await self.collection.find_one({
            "route_code": route_code,
            "is_deleted": False,
        })

    async def get_all(self, page=1, limit=10, search=None, company_id=None):
        query = {"is_deleted": False}

        if company_id:
            query["company_id"] = company_id

        if search:
            query["$or"] = [
                {"name": {"$regex": search, "$options": "i"}},
                {"route_code": {"$regex": search, "$options": "i"}},
            ]

        cursor = (
            self.collection.find(query)
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, route_id: str, data: dict):
        if not ObjectId.is_valid(route_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(route_id), "is_deleted": False},
            {"$set": data},
        )

        return await self.get_by_id(route_id)

    async def soft_delete(self, route_id: str, data: dict):
        if not ObjectId.is_valid(route_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(route_id), "is_deleted": False},
            {"$set": data},
        )

        return result.modified_count > 0