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

    async def get_pending_by_booking(self, booking_id: str):
        return await self.collection.find_one({"booking_id": booking_id, "status": "pending"})

    async def get_all_by_booking(self, booking_id: str):
        # School fees allow several completed payments over a fee's
        # lifetime (each partial payment its own record) - unlike
        # get_by_booking above, which the single-shot booking flow uses
        # to check for one payment, not to list a history.
        cursor = self.collection.find({"booking_id": booking_id}).sort("created_at", -1)
        return await cursor.to_list(length=None)

    async def update_status(self, payment_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(payment_id)},
            {"$set": data},
        )
        return await self.get_by_id(payment_id)
