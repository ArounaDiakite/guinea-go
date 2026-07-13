from bson import ObjectId

from app.database.mongodb import db


class TimeSlotRepository:
    def __init__(self):
        self.collection = db.timeslots

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, timeslot_id: str):
        if not ObjectId.is_valid(timeslot_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(timeslot_id), "is_deleted": False}
        )

    async def get_by_academic_unit(self, academic_unit_id: str):
        cursor = self.collection.find(
            {"academic_unit_id": academic_unit_id, "is_deleted": False}
        ).sort([("day_of_week", 1), ("start_time", 1)])
        return await cursor.to_list(length=None)

    async def has_overlap(
        self,
        field: str,
        value: str,
        day_of_week: str,
        start_time,
        end_time,
        exclude_id: str | None = None,
    ) -> bool:
        """Shared by teacher and academic_unit overlap checks - same
        interval-overlap condition as the hotel booking date ranges
        (start < existing.end AND end > existing.start), just scoped by
        day_of_week instead of spanning multiple days.

        This is a plain query, not an atomic claim like trip_seats/
        room_nights/ticket quantities: those guarded a scarce resource
        multiple paying customers can race for concurrently. A school's
        timetable is built by a single school_administrator managing
        their own institution - there's no realistic multi-actor race to
        defend against here, just a data-integrity rule to enforce."""
        query = {
            field: value,
            "day_of_week": day_of_week,
            "start_time": {"$lt": end_time},
            "end_time": {"$gt": start_time},
            "is_deleted": False,
        }

        if exclude_id:
            query["_id"] = {"$ne": ObjectId(exclude_id)}

        existing = await self.collection.find_one(query)
        return existing is not None

    async def update(self, timeslot_id: str, data: dict):
        if not ObjectId.is_valid(timeslot_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(timeslot_id)},
            {"$set": data},
        )

        return await self.get_by_id(timeslot_id)

    async def soft_delete(self, timeslot_id: str, data: dict):
        if not ObjectId.is_valid(timeslot_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(timeslot_id)},
            {"$set": data},
        )

        return result.modified_count > 0
