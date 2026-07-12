from fastapi import HTTPException, status

from app.admin.repository import AdminRepository


class AdminService:
    def __init__(self):
        self.repository = AdminRepository()

    async def get_pending_users(self):
        users = await self.repository.get_pending_partner_users()
        return [self._format(user) for user in users]

    async def activate_user(self, user_id: str):
        user = await self.repository.get_by_id(user_id)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found.",
            )

        if user.get("is_active"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User is already active.",
            )

        user = await self.repository.activate_user(user_id)

        return self._format(user)

    def _format(self, user):
        return {
            "id": str(user["_id"]),
            "first_name": user["first_name"],
            "last_name": user["last_name"],
            "email": user["email"],
            "phone": user["phone"],
            "role": user["role"],
            "city": user["city"],
            "country_code": user.get("country_code", "GN"),
            "is_active": user["is_active"],
            "created_at": user["created_at"],
        }
