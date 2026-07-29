from bson import ObjectId

from app.database.mongodb import db


class InstitutionRepository:
    def __init__(self):
        self.collection = db.institutions

    async def create(self, institution: dict, session=None):
        result = await self.collection.insert_one(institution, session=session)
        institution["_id"] = result.inserted_id
        return institution

    async def get_by_id(self, institution_id: str):
        if not ObjectId.is_valid(institution_id):
            return None

        return await self.collection.find_one({
            "_id": ObjectId(institution_id),
            "is_deleted": False,
        })

    async def get_by_administrator(self, administrator_id: str):
        return await self.collection.find_one({
            "administrator_id": administrator_id,
            "is_deleted": False,
        })

    async def get_all(self):
        cursor = self.collection.find({"is_deleted": False})
        return await cursor.to_list(length=None)

    async def update(self, institution_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(institution_id), "is_deleted": False},
            {"$set": data},
        )
        return await self.get_by_id(institution_id)

    async def soft_delete(self, institution_id: str, data: dict):
        result = await self.collection.update_one(
            {"_id": ObjectId(institution_id), "is_deleted": False},
            {"$set": data},
        )
        return result.modified_count > 0
