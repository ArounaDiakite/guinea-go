from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.core.utils import utc_now
from app.database.mongodb import db


class CartRepository:
    def __init__(self):
        self.collection = db.carts

    async def get_or_create(self, customer_id: str):
        """Upsert, not find-then-insert: a plain read-then-write here
        could create two cart documents for the same customer_id if
        their first-ever cart action fires twice at once (e.g. a
        double-click). The unique index on customer_id backs this - on
        a genuine race the loser gets a DuplicateKeyError, which just
        means the winner's document is already there to fetch."""
        now = utc_now()

        try:
            await self.collection.update_one(
                {"customer_id": customer_id},
                {
                    "$setOnInsert": {
                        "customer_id": customer_id,
                        "items": [],
                        "created_at": now,
                        "updated_at": now,
                        "is_active": True,
                        "is_deleted": False,
                    }
                },
                upsert=True,
            )
        except DuplicateKeyError:
            pass

        return await self.collection.find_one({"customer_id": customer_id})

    async def replace_items(self, cart_id, items: list[dict]):
        await self.collection.update_one(
            {"_id": cart_id},
            {"$set": {"items": items, "updated_at": utc_now()}},
        )
        return await self.collection.find_one({"_id": cart_id})
