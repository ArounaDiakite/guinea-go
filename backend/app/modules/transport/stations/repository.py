from bson import ObjectId

from app.database.mongodb import db


class StationRepository:
    def __init__(self):
        self.collection = db.stations

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, station_id: str):
        if not ObjectId.is_valid(station_id):
            return None

        return await self.collection.find_one(
            {
                "_id": ObjectId(station_id),
                "is_deleted": False,
            }
        )

    async def get_by_code(self, station_code: str):
        return await self.collection.find_one(
            {
                "station_code": station_code,
                "is_deleted": False,
            }
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        search: str | None = None,
        city_id: str | None = None,
        station_type: str | None = None,
    ):
        query = {
            "is_deleted": False,
        }

        if city_id:
            query["city_id"] = city_id

        if station_type:
            query["station_type"] = station_type

        if search:
            query["$or"] = [
                {
                    "name": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
                {
                    "station_code": {
                        "$regex": search,
                        "$options": "i",
                    }
                },
            ]

        cursor = (
            self.collection.find(query)
            .sort("name", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, station_id: str, data: dict):
        if not ObjectId.is_valid(station_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(station_id)},
            {"$set": data},
        )

        return await self.get_by_id(station_id)

    async def soft_delete(self, station_id: str, data: dict):
        if not ObjectId.is_valid(station_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(station_id)},
            {"$set": data},
        )

        return result.modified_count > 0