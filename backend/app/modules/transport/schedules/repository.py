from bson import ObjectId

from app.database.mongodb import db


class ScheduleRepository:
    def __init__(self):
        self.collection = db.schedules

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, schedule_id: str):
        if not ObjectId.is_valid(schedule_id):
            return None

        return await self.collection.find_one(
            {
                "_id": ObjectId(schedule_id),
                "is_deleted": False,
            }
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        company_id: str | None = None,
        route_id: str | None = None,
        status: str | None = None,
    ):
        query = {
            "is_deleted": False,
        }

        if company_id:
            query["company_id"] = company_id

        if route_id:
            query["route_id"] = route_id

        if status:
            query["status"] = status

        cursor = (
            self.collection.find(query)
            .sort("departure_time", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, schedule_id: str, data: dict):
        if not ObjectId.is_valid(schedule_id):
            return None

        await self.collection.update_one(
            {
                "_id": ObjectId(schedule_id),
                "is_deleted": False,
            },
            {
                "$set": data,
            },
        )

        return await self.get_by_id(schedule_id)

    async def soft_delete(self, schedule_id: str, data: dict):
        if not ObjectId.is_valid(schedule_id):
            return False

        result = await self.collection.update_one(
            {
                "_id": ObjectId(schedule_id),
                "is_deleted": False,
            },
            {
                "$set": data,
            },
        )

        return result.modified_count > 0