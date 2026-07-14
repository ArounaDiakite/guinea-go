from bson import ObjectId

from app.core.constants import ADMIN_VALIDATED_ROLES
from app.core.utils import utc_now
from app.database.mongodb import db


class AdminRepository:
    def __init__(self):
        self.collection = db.users

    async def get_pending_partner_users(self):
        cursor = self.collection.find(
            {
                "is_active": False,
                "role": {"$in": [role.value for role in ADMIN_VALIDATED_ROLES]},
            }
        )
        return await cursor.to_list(length=None)

    async def get_by_id(self, user_id: str):
        return await self.collection.find_one({"_id": ObjectId(user_id)})

    async def activate_user(self, user_id: str):
        await self.collection.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"is_active": True, "updated_at": utc_now()}},
        )
        return await self.get_by_id(user_id)
