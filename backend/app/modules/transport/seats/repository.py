from bson import ObjectId

from app.database.mongodb import db


class SeatRepository:
    def __init__(self):
        self.collection = db.seats

    async def create_many(self, seats: list[dict]):
        result = await self.collection.insert_many(seats)
        cursor = self.collection.find({"_id": {"$in": result.inserted_ids}}).sort(
            "position", 1
        )
        return await cursor.to_list(length=len(result.inserted_ids))

    async def get_by_id(self, seat_id: str):
        if not ObjectId.is_valid(seat_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(seat_id), "is_deleted": False}
        )

    async def get_by_bus(self, bus_id: str):
        cursor = self.collection.find(
            {"bus_id": bus_id, "is_deleted": False}
        ).sort("position", 1)

        return await cursor.to_list(length=None)
