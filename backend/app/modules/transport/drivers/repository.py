from bson import ObjectId

from app.database.mongodb import db


class DriverRepository:
    def __init__(self):
        self.collection = db.drivers

    async def create(self, data: dict, session=None):
        result = await self.collection.insert_one(data, session=session)
        return await self.get_by_id(str(result.inserted_id), session=session)

    async def get_by_id(self, driver_id: str, session=None):
        if not ObjectId.is_valid(driver_id):
            return None

        return await self.collection.find_one(
            {
                "_id": ObjectId(driver_id),
                "is_deleted": False,
            },
            session=session,
        )

    async def get_all(
        self,
        page: int = 1,
        limit: int = 10,
        search: str | None = None,
        company_id: str | None = None,
        status: str | None = None,
    ):
        query = {"is_deleted": False}

        if company_id:
            query["company_id"] = company_id

        if status:
            query["status"] = status.upper()

        if search:
            query["$or"] = [
                {"first_name": {"$regex": search, "$options": "i"}},
                {"last_name": {"$regex": search, "$options": "i"}},
                {"phone": {"$regex": search, "$options": "i"}},
                {"license_number": {"$regex": search, "$options": "i"}},
                {"employee_number": {"$regex": search, "$options": "i"}},
            ]

        cursor = (
            self.collection.find(query)
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def update(self, driver_id: str, data: dict):
        if not ObjectId.is_valid(driver_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(driver_id), "is_deleted": False},
            {"$set": data},
        )

        return await self.get_by_id(driver_id)

    async def soft_delete(self, driver_id: str, data: dict):
        if not ObjectId.is_valid(driver_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(driver_id), "is_deleted": False},
            {"$set": data},
        )

        return result.modified_count > 0