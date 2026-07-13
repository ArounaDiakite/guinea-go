from bson import ObjectId

from app.database.mongodb import db


class AcademicUnitRepository:
    def __init__(self):
        self.collection = db.academic_units

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, academic_unit_id: str):
        if not ObjectId.is_valid(academic_unit_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(academic_unit_id), "is_deleted": False}
        )

    async def get_by_institution(self, institution_id: str, page: int = 1, limit: int = 50):
        cursor = (
            self.collection.find({"institution_id": institution_id, "is_deleted": False})
            .sort("name", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update(self, academic_unit_id: str, data: dict):
        if not ObjectId.is_valid(academic_unit_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(academic_unit_id)},
            {"$set": data},
        )

        return await self.get_by_id(academic_unit_id)

    async def soft_delete(self, academic_unit_id: str, data: dict):
        if not ObjectId.is_valid(academic_unit_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(academic_unit_id)},
            {"$set": data},
        )

        return result.modified_count > 0
