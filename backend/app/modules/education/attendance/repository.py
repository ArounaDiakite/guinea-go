from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.database.mongodb import db


class AttendanceRepository:
    def __init__(self):
        self.collection = db.attendance_records

    async def create_many(self, timeslot_id: str, record_date, records: list[dict]):
        """Ordered insert backed by the unique (timeslot_id, date,
        student_id) index. The service already checks for an existing
        submission before calling this, so this is a backstop against a
        genuine double-submit race (same reasoning as institutions.
        administrator_id / carts.customer_id), not a scarce-resource
        claim. If it does fire, whichever records came before the
        conflicting one in the batch did get written - clean those up so
        a failed attempt doesn't leave a partial submission behind."""
        try:
            await self.collection.insert_many(records, ordered=True)
            return await self.get_by_timeslot_and_date(timeslot_id, record_date)
        except DuplicateKeyError:
            await self.collection.delete_many(
                {"timeslot_id": timeslot_id, "date": record_date}
            )
            return None

    async def get_by_id(self, record_id: str):
        if not ObjectId.is_valid(record_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(record_id), "is_deleted": False}
        )

    async def get_by_timeslot_and_date(self, timeslot_id: str, record_date):
        cursor = self.collection.find(
            {"timeslot_id": timeslot_id, "date": record_date, "is_deleted": False}
        ).sort("student_id", 1)
        return await cursor.to_list(length=None)

    async def get_one(self, timeslot_id: str, record_date, student_id: str):
        return await self.collection.find_one(
            {
                "timeslot_id": timeslot_id,
                "date": record_date,
                "student_id": student_id,
                "is_deleted": False,
            }
        )

    async def create_one(self, record: dict):
        result = await self.collection.insert_one(record)
        return await self.get_by_id(str(result.inserted_id))

    async def update_status(self, record_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(record_id)},
            {"$set": data},
        )
        return await self.get_by_id(record_id)

    async def get_by_student(self, student_id: str, page: int, limit: int):
        cursor = (
            self.collection.find({"student_id": student_id, "is_deleted": False})
            .sort("date", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)
