from bson import ObjectId

from app.database.mongodb import db


class EventBookingRepository:
    def __init__(self):
        self.collection = db.event_bookings

    async def create(self, booking_data: dict):
        await self.collection.insert_one(booking_data)
        return await self.get_by_id(str(booking_data["_id"]))

    async def get_by_id(self, booking_id: str):
        if not ObjectId.is_valid(booking_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(booking_id)})

    async def get_by_passenger(self, passenger_id: str, page: int = 1, limit: int = 20):
        cursor = (
            self.collection.find({"passenger_id": passenger_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def get_by_event(self, event_id: str, page: int = 1, limit: int = 20):
        cursor = (
            self.collection.find({"event_id": event_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def get_stale_pending_bookings(self, ticket_type_id: str, now):
        cursor = self.collection.find(
            {
                "ticket_type_id": ticket_type_id,
                "status": "PENDING_PAYMENT",
                "expires_at": {"$lte": now},
            }
        )
        return await cursor.to_list(length=None)

    async def transition_status_if(
        self,
        booking_id: str,
        expected_statuses: list[str] | str,
        data: dict,
    ) -> bool:
        if isinstance(expected_statuses, str):
            expected_statuses = [expected_statuses]

        result = await self.collection.update_one(
            {"_id": ObjectId(booking_id), "status": {"$in": expected_statuses}},
            {"$set": data},
        )
        return result.modified_count > 0
