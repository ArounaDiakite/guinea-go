from bson import ObjectId
from pymongo import ReturnDocument

from app.common.base_model import now
from app.database.mongodb import db


class FeeScheduleRepository:
    def __init__(self):
        self.collection = db.fee_schedules

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, fee_schedule_id: str):
        if not ObjectId.is_valid(fee_schedule_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(fee_schedule_id), "is_deleted": False}
        )

    async def get_by_institution(self, institution_id: str, page: int = 1, limit: int = 50):
        cursor = (
            self.collection.find({"institution_id": institution_id, "is_deleted": False})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update(self, fee_schedule_id: str, data: dict):
        if not ObjectId.is_valid(fee_schedule_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(fee_schedule_id)},
            {"$set": data},
        )

        return await self.get_by_id(fee_schedule_id)

    async def soft_delete(self, fee_schedule_id: str, data: dict):
        if not ObjectId.is_valid(fee_schedule_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(fee_schedule_id)},
            {"$set": data},
        )

        return result.modified_count > 0


class StudentFeeRepository:
    def __init__(self):
        self.collection = db.student_fees

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, student_fee_id: str):
        if not ObjectId.is_valid(student_fee_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(student_fee_id), "is_deleted": False}
        )

    async def get_by_student(self, student_id: str):
        cursor = self.collection.find(
            {"student_id": student_id, "is_deleted": False}
        ).sort("created_at", -1)
        return await cursor.to_list(length=None)

    async def get_by_student_and_schedule(self, student_id: str, fee_schedule_id: str):
        return await self.collection.find_one(
            {
                "student_id": student_id,
                "fee_schedule_id": fee_schedule_id,
                "is_deleted": False,
            }
        )

    async def apply_payment(self, student_fee_id: str, amount: float):
        """Atomic accumulate-and-reclassify: the same 'pure counter' shape
        as ticket_types.quantity_available/products.stock (a single
        document, guarded find_one_and_update, no separate claim
        collection needed) - just derived from two fields (amount_paid +
        this payment vs amount_due) instead of a plain scalar, so it
        needs an aggregation-pipeline update ($expr guard, computed
        $set) instead of a flat $inc. Still one atomic document
        operation: two payments racing to complete against the same fee
        can't jointly push amount_paid past amount_due, and this treats
        fee payments the same as the other money-moving counters in this
        codebase, unlike the school-timetable overlap check nearby (see
        timeslots/repository.py's has_overlap) which explicitly does NOT
        get this treatment because it isn't money and isn't multi-actor.
        Returns None if applying the payment would overpay - the caller
        marks that payment failed rather than silently clamping it."""
        if not ObjectId.is_valid(student_fee_id):
            return None

        return await self.collection.find_one_and_update(
            {
                "_id": ObjectId(student_fee_id),
                "$expr": {"$lte": [{"$add": ["$amount_paid", amount]}, "$amount_due"]},
            },
            [
                {
                    "$set": {
                        "amount_paid": {"$add": ["$amount_paid", amount]},
                        "status": {
                            "$cond": [
                                {"$gte": [{"$add": ["$amount_paid", amount]}, "$amount_due"]},
                                "paid",
                                "partial",
                            ]
                        },
                        "updated_at": now(),
                    }
                }
            ],
            return_document=ReturnDocument.AFTER,
        )
