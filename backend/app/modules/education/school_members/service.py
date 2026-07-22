from fastapi import HTTPException, status
from pymongo.errors import OperationFailure

from app.common.utils import is_transactions_unsupported
from app.core.constants import UserRole
from app.database.mongodb import client as mongo_client
from app.identity.auth.schemas import RegisterRequest
from app.identity.auth.service import AuthService
from app.modules.education.school_members.schemas import SchoolMemberRegisterRequest
from app.modules.education.students.repository import StudentRepository
from app.modules.education.teachers.repository import TeacherRepository


class SchoolMemberService:
    """Self-registration for teacher/student accounts via an invite code
    generated on their Teacher/Student profile at creation time by a
    school_administrator (see TeacherService/StudentService._unique_invite_code).
    Applies to any institution type - the invite code alone identifies
    which profile (and therefore institution) the caller belongs to."""

    def __init__(self):
        self.teacher_repository = TeacherRepository()
        self.student_repository = StudentRepository()
        self.auth_service = AuthService()

    async def register(self, data: SchoolMemberRegisterRequest):
        role, profile = await self._resolve_invite_code(data.invite_code)

        try:
            return await self._create_with_transaction(role, profile, data)
        except OperationFailure as error:
            if not is_transactions_unsupported(error):
                raise
            return await self._create_with_manual_rollback(role, profile, data)

    async def _resolve_invite_code(self, invite_code: str):
        teacher = await self.teacher_repository.get_by_invite_code(invite_code)

        if teacher:
            if teacher.get("user_id"):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This invite code has already been used.",
                )
            return UserRole.TEACHER, teacher

        student = await self.student_repository.get_by_invite_code(invite_code)

        if student:
            if student.get("user_id"):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This invite code has already been used.",
                )
            return UserRole.STUDENT, student

        raise HTTPException(status_code=404, detail="Invalid invite code.")

    async def _create_with_transaction(
        self, role: UserRole, profile: dict, data: SchoolMemberRegisterRequest
    ):
        async with await mongo_client.start_session() as session:
            async with session.start_transaction():
                account = await self.auth_service.register_role(
                    role, self._account_data(data), is_active=True, session=session
                )
                await self._claim(role, str(profile["_id"]), account["id"], session=session)
                return self._build_response(account, role, profile)

    async def _create_with_manual_rollback(
        self, role: UserRole, profile: dict, data: SchoolMemberRegisterRequest
    ):
        account = await self.auth_service.register_role(
            role, self._account_data(data), is_active=True
        )

        try:
            await self._claim(role, str(profile["_id"]), account["id"])
        except Exception:
            await self.auth_service.delete_account(account["id"])
            raise

        return self._build_response(account, role, profile)

    async def _claim(self, role: UserRole, profile_id: str, user_id: str, session=None):
        repository = self.teacher_repository if role == UserRole.TEACHER else self.student_repository
        claimed = await repository.claim_invite_code(profile_id, user_id, session=session)

        if not claimed:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="This invite code has already been used.",
            )

    def _account_data(self, data: SchoolMemberRegisterRequest) -> RegisterRequest:
        return RegisterRequest(
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email,
            phone=data.phone,
            password=data.password,
            city=data.city,
            country_code=data.country_code,
            preferred_language=data.preferred_language,
        )

    def _build_response(self, account: dict, role: UserRole, profile: dict) -> dict:
        token = self.auth_service.build_token(account["id"], account["email"], role.value)

        return {
            "access_token": token,
            "token_type": "bearer",
            "user": account,
            "profile_id": str(profile["_id"]),
        }
