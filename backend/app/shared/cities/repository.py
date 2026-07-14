from bson import ObjectId

from app.database.mongodb import db


class CityRepository:
    def __init__(self):
        self.collection = db.cities

    async def create_city(self, city_data: dict):
        result = await self.collection.insert_one(city_data)
        return await self.collection.find_one({"_id": result.inserted_id})

    async def get_by_id(self, city_id: str):
        if not ObjectId.is_valid(city_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(city_id)})

    async def get_city(self, country_code: str, name: str):
        return await self.collection.find_one({
            "country_code": country_code.upper(),
            "name": name
        })

    async def get_all(self):
        return await self.collection.find().sort("name", 1).to_list(length=1000)

    async def get_by_country(self, country_code: str):
        return await self.collection.find({
            "country_code": country_code.upper()
        }).sort("name", 1).to_list(length=1000)