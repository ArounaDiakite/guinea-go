from bson import ObjectId

from app.database.mongodb import db


class CurrencyRepository:
    def __init__(self):
        self.collection = db.currencies

    async def create_currency(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.collection.find_one({"_id": result.inserted_id})

    async def get_by_code(self, code: str):
        return await self.collection.find_one({"code": code.upper()})

    async def get_by_id(self, currency_id: str):
        if not ObjectId.is_valid(currency_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(currency_id)})

    async def get_all(self):
        return await self.collection.find().sort("code", 1).to_list(length=100)