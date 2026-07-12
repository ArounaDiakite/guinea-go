from bson import ObjectId

from app.database.mongodb import db


class AuthRepository:
    def __init__(self):
        self.collection = db.users

    async def get_user_by_email(self, email: str, session=None):
        return await self.collection.find_one({"email": email}, session=session)

    async def create_user(self, user_data: dict, session=None):
        result = await self.collection.insert_one(user_data, session=session)
        return await self.collection.find_one({"_id": result.inserted_id}, session=session)

    async def delete_user(self, user_id: str, session=None):
        await self.collection.delete_one({"_id": ObjectId(user_id)}, session=session)