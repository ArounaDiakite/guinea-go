from bson import ObjectId

from app.database.mongodb import db


class CompanyRepository:
    def __init__(self):
        self.collection = db.companies

    async def create(self, company: dict):
        result = await self.collection.insert_one(company)
        company["_id"] = result.inserted_id
        return company

    async def get_all(
        self,
        page: int = 1,
        limit: int = 20,
        search: str | None = None,
        company_type: str | None = None,
        city_id: str | None = None,
        owner_id: str | None = None,
    ):
        query = {"is_deleted": False}

        if search:
            query["name"] = {"$regex": search, "$options": "i"}

        if company_type:
            query["company_type"] = company_type.upper()

        if city_id:
            query["city_id"] = city_id

        if owner_id:
            query["owner_id"] = owner_id

        skip = (page - 1) * limit

        cursor = (
            self.collection
            .find(query)
            .sort("created_at", -1)
            .skip(skip)
            .limit(limit)
        )

        return await cursor.to_list(length=limit)

    async def get_by_id(self, company_id: str):
        return await self.collection.find_one({
            "_id": ObjectId(company_id),
            "is_deleted": False,
        })

    async def update(self, company_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(company_id), "is_deleted": False},
            {"$set": data},
        )
        return await self.get_by_id(company_id)

    async def soft_delete(self, company_id: str, data: dict):
        result = await self.collection.update_one(
            {"_id": ObjectId(company_id), "is_deleted": False},
            {"$set": data},
        )
        return result.modified_count > 0