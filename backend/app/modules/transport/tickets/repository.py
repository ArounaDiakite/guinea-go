from bson import ObjectId

from app.database.mongodb import db


class TicketRepository:
    def __init__(self):
        self.collection = db.tickets

    async def create(self, data: dict):
        await self.collection.insert_one(data)
        return await self.get_by_id(str(data["_id"]))

    async def get_by_id(self, ticket_id: str):
        if not ObjectId.is_valid(ticket_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(ticket_id)})

    async def get_by_booking(self, booking_id: str):
        return await self.collection.find_one({"booking_id": booking_id})

    async def get_by_code(self, code: str):
        return await self.collection.find_one({"code": code})

    async def transition_status_if(
        self,
        ticket_id: str,
        expected_statuses: list[str] | str,
        data: dict,
    ) -> bool:
        """Conditional update, same shape as BookingRepository's - only
        applies `data` if the ticket is currently in one of
        expected_statuses, so a ticket can't be validated twice even if
        two scans race each other."""
        if isinstance(expected_statuses, str):
            expected_statuses = [expected_statuses]

        result = await self.collection.update_one(
            {"_id": ObjectId(ticket_id), "status": {"$in": expected_statuses}},
            {"$set": data},
        )
        return result.modified_count > 0
