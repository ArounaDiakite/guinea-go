from bson import ObjectId

from app.database.mongodb import db


class TicketTypeRepository:
    def __init__(self):
        self.collection = db.ticket_types

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, ticket_type_id: str):
        if not ObjectId.is_valid(ticket_type_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(ticket_type_id), "is_deleted": False}
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 20,
        event_id: str | None = None,
        category: str | None = None,
    ):
        query = {"is_deleted": False}

        if event_id:
            query["event_id"] = event_id

        if category:
            query["category"] = category

        cursor = (
            self.collection.find(query)
            .sort("created_at", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, ticket_type_id: str, data: dict):
        if not ObjectId.is_valid(ticket_type_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(ticket_type_id)},
            {"$set": data},
        )

        return await self.get_by_id(ticket_type_id)

    async def soft_delete(self, ticket_type_id: str, data: dict):
        if not ObjectId.is_valid(ticket_type_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(ticket_type_id)},
            {"$set": data},
        )

        return result.modified_count > 0

    async def claim_tickets(self, ticket_type_id: str, quantity: int) -> bool:
        """Atomic compare-and-decrement: succeeds only if at least
        `quantity` tickets are still available, in one document
        operation. Unlike seats/room_nights, a ticket has no individual
        identity before purchase, so there's no per-unit collection to
        claim rows in - the quantity counter on the ticket type itself
        IS the thing being atomically compare-and-swapped."""
        if not ObjectId.is_valid(ticket_type_id):
            return False

        result = await self.collection.find_one_and_update(
            {
                "_id": ObjectId(ticket_type_id),
                "is_deleted": False,
                "quantity_available": {"$gte": quantity},
            },
            {"$inc": {"quantity_available": -quantity}},
        )

        return result is not None

    async def release_tickets(self, ticket_type_id: str, quantity: int):
        if not ObjectId.is_valid(ticket_type_id):
            return

        await self.collection.update_one(
            {"_id": ObjectId(ticket_type_id)},
            {"$inc": {"quantity_available": quantity}},
        )
