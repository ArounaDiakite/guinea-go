from bson import ObjectId

from app.database.mongodb import db


class OrderRepository:
    def __init__(self):
        self.collection = db.orders

    async def create(self, order_data: dict):
        await self.collection.insert_one(order_data)
        return await self.get_by_id(str(order_data["_id"]))

    async def get_by_id(self, order_id: str):
        if not ObjectId.is_valid(order_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(order_id)})

    async def delete(self, order_id: str):
        if not ObjectId.is_valid(order_id):
            return
        await self.collection.delete_one({"_id": ObjectId(order_id)})

    async def get_by_customer(self, customer_id: str, page: int = 1, limit: int = 20):
        cursor = (
            self.collection.find({"customer_id": customer_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def get_by_store(self, store_id: str, page: int = 1, limit: int = 20):
        # Backed by the [("store_id", 1), ("status", 1)] index (see
        # database/indexes.py) - store_manager's "orders received" view.
        cursor = (
            self.collection.find({"store_id": store_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def get_stale_pending_orders(self, now):
        # Unscoped (not filtered to one store/product like trip_id/room_id/
        # ticket_type_id elsewhere) - an order can hold stock for several
        # products across a single store, so there's no single resource id
        # to scope this to the way the other domains could. Run as a global
        # sweep at the start of checkout instead; the orders collection
        # stays small enough for this to be cheap.
        cursor = self.collection.find(
            {"status": "PENDING_PAYMENT", "expires_at": {"$lte": now}}
        )
        return await cursor.to_list(length=None)

    async def transition_status_if(
        self,
        order_id: str,
        expected_statuses: list[str] | str,
        data: dict,
    ) -> bool:
        if isinstance(expected_statuses, str):
            expected_statuses = [expected_statuses]

        result = await self.collection.update_one(
            {"_id": ObjectId(order_id), "status": {"$in": expected_statuses}},
            {"$set": data},
        )
        return result.modified_count > 0
