from bson import ObjectId

from app.database.mongodb import db


class PaymentRepository:
    def __init__(self):
        self.collection = db.payments

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, payment_id: str):
        if not ObjectId.is_valid(payment_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(payment_id)})

    async def get_by_booking(self, booking_id: str):
        return await self.collection.find_one({"booking_id": booking_id})

    async def update_status(self, payment_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(payment_id)},
            {"$set": data},
        )
        return await self.get_by_id(payment_id)
