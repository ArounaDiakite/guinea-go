import secrets

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.teachers.repository import TeacherRepository
from app.modules.education.teachers.schemas import TeacherCreate

# Same ambiguity-stripped alphabet as transport/tickets - meant to be
# read and typed by hand into the self-registration form, not just
# scanned. Shorter than a ticket code (8 vs 10) since it's a one-time
# setup step, not something re-checked at a gate.
_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_CODE_LENGTH = 8


def _generate_invite_code() -> str:
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))


class TeacherService:
    def __init__(self):
        self.repository = TeacherRepository()
        self.institution_repository = InstitutionRepository()
        self.academic_unit_repository = AcademicUnitRepository()

    async def _unique_invite_code(self) -> str:
        code = _generate_invite_code()
        # 32^8 keyspace - a collision is vanishingly unlikely, but
        # checked and retried rather than trusted blindly, since
        # invite_code carries a unique index.
        for _ in range(3):
            if not await self.repository.get_by_invite_code(code):
                break
            code = _generate_invite_code()
        return code

    async def _get_owned_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)
        return institution

    async def _validate_academic_units(self, institution_id: str, academic_unit_ids: list[str]):
        for academic_unit_id in academic_unit_ids:
            unit = await self.academic_unit_repository.get_by_id(academic_unit_id)

            if not unit:
                raise HTTPException(
                    status_code=404,
                    detail=f"Academic unit {academic_unit_id} not found.",
                )

            if unit["institution_id"] != institution_id:
                raise HTTPException(
                    status_code=400,
                    detail="A teacher can only be assigned to academic units of their own institution.",
                )

    async def create_teacher(self, data: TeacherCreate, user_id: str):
        await self._get_owned_institution(data.institution_id, user_id)
        await self._validate_academic_units(data.institution_id, data.academic_unit_ids)

        teacher = data.model_dump()
        teacher.update(BaseDocument.create())
        teacher["invite_code"] = await self._unique_invite_code()
        teacher["user_id"] = None

        teacher = await self.repository.create(teacher)
        return self._format(teacher)

    async def get_teachers(
        self,
        institution_id: str,
        user_id: str,
        page: int,
        limit: int,
        academic_unit_id: str | None,
    ):
        await self._get_owned_institution(institution_id, user_id)

        teachers = await self.repository.get_by_institution(
            institution_id, page, limit, academic_unit_id
        )
        return [self._format(teacher) for teacher in teachers]

    async def get_teacher(self, teacher_id: str, user_id: str):
        teacher = await self.repository.get_by_id(teacher_id)

        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found.")

        await self._get_owned_institution(teacher["institution_id"], user_id)
        return self._format(teacher)

    async def get_my_teacher_profile(self, user_id: str):
        teacher = await self.repository.get_by_user_id(user_id)

        if not teacher:
            raise HTTPException(status_code=404, detail="No teacher profile is linked to this account.")

        return self._format(teacher)

    async def update_teacher(self, teacher_id: str, data: TeacherCreate, user_id: str):
        teacher = await self.repository.get_by_id(teacher_id)

        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found.")

        await self._get_owned_institution(teacher["institution_id"], user_id)

        if data.institution_id != teacher["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="A teacher cannot be moved to a different institution.",
            )

        await self._validate_academic_units(data.institution_id, data.academic_unit_ids)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(teacher_id, update_data)
        return self._format(updated)

    async def delete_teacher(self, teacher_id: str, user_id: str):
        teacher = await self.repository.get_by_id(teacher_id)

        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found.")

        await self._get_owned_institution(teacher["institution_id"], user_id)

        deleted = await self.repository.soft_delete(
            teacher_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Teacher not found.")

        return {"message": "Teacher deleted successfully."}

    def _format(self, teacher):
        return {
            "id": str(teacher["_id"]),
            "institution_id": teacher["institution_id"],
            "first_name": teacher["first_name"],
            "last_name": teacher["last_name"],
            "email": teacher.get("email"),
            "phone": teacher["phone"],
            "subject": teacher.get("subject"),
            "academic_unit_ids": teacher.get("academic_unit_ids", []),
            "invite_code": teacher["invite_code"],
            "user_id": teacher.get("user_id"),
            "is_active": teacher["is_active"],
            "created_at": teacher.get("created_at"),
            "updated_at": teacher.get("updated_at"),
        }
