from fastapi import HTTPException

from app.core.security import hash_password, verify_password
from app.core.utils import utc_now
from app.identity.users.repository import UserRepository
from app.identity.users.schemas import ChangePasswordRequest, UpdateProfileRequest


class UserService:
    def __init__(self):
        self.repository = UserRepository()

    async def get_me(self, user_id: str):
        user = await self.repository.get_by_id(user_id)

        if not user:
            raise HTTPException(status_code=404, detail="User not found.")

        return self._format_user(user)

    async def update_me(self, user_id: str, data: UpdateProfileRequest):
        update_data = data.model_dump()
        update_data["country_code"] = data.country_code.upper()
        update_data["preferred_language"] = data.preferred_language.lower()
        update_data["updated_at"] = utc_now()

        user = await self.repository.update_by_id(user_id, update_data)

        return self._format_user(user)

    async def change_password(self, user_id: str, data: ChangePasswordRequest):
        user = await self.repository.get_by_id(user_id)

        if not user:
            raise HTTPException(status_code=404, detail="User not found.")

        if not verify_password(data.old_password, user["password"]):
            raise HTTPException(status_code=400, detail="Old password is incorrect.")

        await self.repository.update_by_id(
            user_id,
            {
                "password": hash_password(data.new_password),
                "updated_at": utc_now(),
            },
        )

        return {"message": "Password changed successfully."}

    def _format_user(self, user):
        return {
            "id": str(user["_id"]),
            "first_name": user["first_name"],
            "last_name": user["last_name"],
            "email": user["email"],
            "phone": user["phone"],
            "city": user["city"],
            "country_code": user.get("country_code", "GN"),
            "preferred_language": user.get("preferred_language", "fr"),
            "role": user["role"],
            "is_verified": user.get("is_verified", False),
            "is_active": user.get("is_active", True),
        }