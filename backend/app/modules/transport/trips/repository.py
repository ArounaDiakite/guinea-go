from bson import ObjectId

from app.database.mongodb import db


class TripRepository:
    def __init__(self):
        self.collection = db.trips

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, trip_id: str):
        if not ObjectId.is_valid(trip_id):
            return None

        return await self.collection.find_one(
            {
                "_id": ObjectId(trip_id),
                "is_deleted": False,
            }
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        company_id: str | None = None,
        route_id: str | None = None,
        travel_date=None,
        status: str | None = None,
    ):
        query = {
            "is_deleted": False,
        }

        if company_id:
            query["company_id"] = company_id

        if route_id:
            query["route_id"] = route_id

        if travel_date:
            query["travel_date"] = travel_date

        if status:
            query["status"] = status

        cursor = (
            self.collection.find(query)
            .sort("departure_datetime", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, trip_id: str, data: dict):
        if not ObjectId.is_valid(trip_id):
            return None

        await self.collection.update_one(
            {
                "_id": ObjectId(trip_id),
                "is_deleted": False,
            },
            {
                "$set": data,
            },
        )

        return await self.get_by_id(trip_id)

    async def soft_delete(self, trip_id: str, data: dict):
        if not ObjectId.is_valid(trip_id):
            return False

        result = await self.collection.update_one(
            {
                "_id": ObjectId(trip_id),
                "is_deleted": False,
            },
            {
                "$set": data,
            },
        )

        return result.modified_count > 0

    async def increment_booked_seats(self, trip_id: str):
        await self.collection.update_one(
            {"_id": ObjectId(trip_id)},
            {"$inc": {"booked_seats": 1, "available_seats": -1}},
        )

    async def decrement_booked_seats(self, trip_id: str):
        await self.collection.update_one(
            {"_id": ObjectId(trip_id)},
            {"$inc": {"booked_seats": -1, "available_seats": 1}},
        )