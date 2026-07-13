from bson import ObjectId

from app.database.mongodb import db


class ProductRepository:
    def __init__(self):
        self.collection = db.products

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, product_id: str):
        if not ObjectId.is_valid(product_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(product_id), "is_deleted": False}
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 20,
        search: str | None = None,
        category_id: str | None = None,
        store_id: str | None = None,
    ):
        query = {"is_deleted": False}

        if search:
            query["name"] = {"$regex": search, "$options": "i"}

        if category_id:
            query["category_ids"] = category_id

        if store_id:
            query["store_id"] = store_id

        cursor = (
            self.collection.find(query)
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, product_id: str, data: dict):
        if not ObjectId.is_valid(product_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": data},
        )

        return await self.get_by_id(product_id)

    async def soft_delete(self, product_id: str, data: dict):
        if not ObjectId.is_valid(product_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(product_id)},
            {"$set": data},
        )

        return result.modified_count > 0

    async def claim_stock(self, product_id: str, quantity: int) -> bool:
        """Atomic compare-and-decrement, same shape as TicketTypeRepository.
        claim_tickets: a single document operation, no separate per-unit
        collection needed since stock (like ticket quantity_available) is
        just an integer counter, not something with individual identity."""
        if not ObjectId.is_valid(product_id):
            return False

        result = await self.collection.find_one_and_update(
            {
                "_id": ObjectId(product_id),
                "is_deleted": False,
                "stock": {"$gte": quantity},
            },
            {"$inc": {"stock": -quantity}},
        )

        return result is not None

    async def release_stock(self, product_id: str, quantity: int):
        if not ObjectId.is_valid(product_id):
            return

        await self.collection.update_one(
            {"_id": ObjectId(product_id)},
            {"$inc": {"stock": quantity}},
        )
