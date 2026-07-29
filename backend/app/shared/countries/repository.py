from bson import ObjectId

from app.database.mongodb import db


class CountryRepository:
    def __init__(self):
        self.collection = db.countries

    async def create_country(self, country_data: dict):
        result = await self.collection.insert_one(country_data)
        return await self.collection.find_one({"_id": result.inserted_id})

    async def get_all_countries(self):
        cursor = self.collection.find({"is_active": True})
        return await cursor.to_list(length=100)

    async def get_country_by_code(self, code: str):
        return await self.collection.find_one({"code": code.upper()})

    async def get_by_id(self, country_id: str):
        if not ObjectId.is_valid(country_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(country_id)})

    async def update(self, country_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(country_id)},
            {"$set": data},
        )
        return await self.get_by_id(country_id)

    async def soft_delete(self, country_id: str):
        result = await self.collection.update_one(
            {"_id": ObjectId(country_id)},
            {"$set": {"is_active": False}},
        )
        return result.modified_count > 0