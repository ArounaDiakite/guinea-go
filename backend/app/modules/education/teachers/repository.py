from bson import ObjectId

from app.common.base_model import now
from app.database.mongodb import db


class TeacherRepository:
    def __init__(self):
        self.collection = db.teachers

    async def create(self, data: dict):
        result = await self.collection.insert_one(data)
        return await self.get_by_id(str(result.inserted_id))

    async def get_by_id(self, teacher_id: str):
        if not ObjectId.is_valid(teacher_id):
            return None

        return await self.collection.find_one(
            {"_id": ObjectId(teacher_id), "is_deleted": False}
        )

    async def get_by_invite_code(self, invite_code: str):
        return await self.collection.find_one({"invite_code": invite_code, "is_deleted": False})

    async def get_by_user_id(self, user_id: str):
        return await self.collection.find_one({"user_id": user_id, "is_deleted": False})

    async def claim_invite_code(self, teacher_id: str, user_id: str, session=None) -> bool:
        """Consumes the invite code by linking it to the freshly created
        account - the invite_code field itself is left untouched (see
        TeacherResponse's comment); it's the presence of user_id that
        makes it single-use. The user_id: None filter makes this an
        atomic claim: a second concurrent registration attempt against
        the same code will match zero documents and get modified_count
        0, which school_members/service.py treats as "already used"."""
        result = await self.collection.update_one(
            {"_id": ObjectId(teacher_id), "user_id": None},
            {"$set": {"user_id": user_id, "updated_at": now()}},
            session=session,
        )
        return result.modified_count > 0

    async def get_by_institution(
        self,
        institution_id: str,
        page: int = 1,
        limit: int = 50,
        academic_unit_id: str | None = None,
    ):
        query = {"institution_id": institution_id, "is_deleted": False}

        if academic_unit_id:
            query["academic_unit_ids"] = academic_unit_id

        cursor = (
            self.collection.find(query)
            .sort("last_name", 1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update(self, teacher_id: str, data: dict):
        if not ObjectId.is_valid(teacher_id):
            return None

        await self.collection.update_one(
            {"_id": ObjectId(teacher_id)},
            {"$set": data},
        )

        return await self.get_by_id(teacher_id)

    async def soft_delete(self, teacher_id: str, data: dict):
        if not ObjectId.is_valid(teacher_id):
            return False

        result = await self.collection.update_one(
            {"_id": ObjectId(teacher_id)},
            {"$set": data},
        )

        return result.modified_count > 0
