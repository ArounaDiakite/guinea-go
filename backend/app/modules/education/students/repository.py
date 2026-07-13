from bson import ObjectId

from app.database.mongodb import db


class StudentRepository:
    def __init__(self):
        self.collection = db.students

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, student_id: str):
        if not ObjectId.is_valid(student_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(student_id), "is_deleted": False}
        )

    async def get_by_institution(
        self,
        institution_id: str,
        page: int = 1,
        limit: int = 50,
        academic_unit_id: str | None = None,
    ):
        query = {"institution_id": institution_id, "is_deleted": False}

        if academic_unit_id:
            query["academic_unit_id"] = academic_unit_id

        cursor = (
            self.collection.find(query)
            .sort("last_name", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update(self, student_id: str, data: dict):
        if not ObjectId.is_valid(student_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(student_id)},
            {"$set": data},
        )

        return await self.get_by_id(student_id)

    async def soft_delete(self, student_id: str, data: dict):
        if not ObjectId.is_valid(student_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(student_id)},
            {"$set": data},
        )

        return result.modified_count > 0
