from app.database.mongodb import db


class AuthRepository:
    def __init__(self):
        self.collection = db.users

    async def get_user_by_email(self, email: str):
        return await self.collection.find_one({"email": email})

    async def create_user(self, user_data: dict):
        result = await self.collection.insert_one(user_data)
        return await self.collection.find_one({"_id": result.inserted_id})