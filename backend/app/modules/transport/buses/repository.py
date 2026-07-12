from bson import ObjectId

from app.database.mongodb import db


class BusRepository:
    def __init__(self):
        self.collection = db.buses

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, bus_id: str):
        if not ObjectId.is_valid(bus_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(bus_id), "is_deleted": False}
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        search: str | None = None,
        company_id: str | None = None,
        status: str | None = None,
    ):
        query = {
            "is_deleted": False
        }

        if company_id:
            query["company_id"] = company_id

        if status:
            query["status"] = status

        if search:
            query["$or"] = [
                {
                    "brand": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
                {
                    "model": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
                {
                    "registration_number": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
                {
                    "fleet_number": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
            ]

        cursor = (
            self.collection.find(query)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, bus_id: str, data: dict):
        if not ObjectId.is_valid(bus_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(bus_id)},
            {"$set": data},
        )

        return await self.get_by_id(bus_id)

    async def soft_delete(self, bus_id: str, data: dict):
        if not ObjectId.is_valid(bus_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(bus_id)},
            {"$set": data},
        )

        return result.modified_count > 0