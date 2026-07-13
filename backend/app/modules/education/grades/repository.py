from bson import ObjectId

from app.database.mongodb import db


class GradeRepository:
    def __init__(self):
        self.collection = db.grades

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, grade_id: str):
        if not ObjectId.is_valid(grade_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(grade_id), "is_deleted": False}
        )

    async def get_by_student(self, student_id: str, period: str | None = None):
        query = {"student_id": student_id, "is_deleted": False}

        if period:
            query["period"] = period

        cursor = self.collection.find(query).sort(
            [("subject_id", 1), ("created_at", 1)]
        )
        return await cursor.to_list(length=None)

    async def update(self, grade_id: str, data: dict):
        if not ObjectId.is_valid(grade_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(grade_id)},
            {"$set": data},
        )

        return await self.get_by_id(grade_id)
