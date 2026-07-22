from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.access import EducationAccess
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.academic_units.schemas import AcademicUnitCreate
from app.modules.education.institutions.repository import InstitutionRepository


class AcademicUnitService:
    def __init__(self):
        self.repository = AcademicUnitRepository()
        self.institution_repository = InstitutionRepository()
        self.access = EducationAccess()

    async def _get_owned_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)
        return institution

    async def create_academic_unit(self, data: AcademicUnitCreate, user_id: str):
        await self._get_owned_institution(data.institution_id, user_id)

        academic_unit = data.model_dump()
        academic_unit.update(BaseDocument.create())

        academic_unit = await self.repository.create(academic_unit)
        return self._format(academic_unit)

    async def get_academic_units(self, institution_id: str, user_id: str, page: int, limit: int):
        await self._get_owned_institution(institution_id, user_id)

        academic_units = await self.repository.get_by_institution(institution_id, page, limit)
        return [self._format(unit) for unit in academic_units]

    async def get_academic_unit(self, academic_unit_id: str, user_id: str, role: str):
        academic_unit = await self.repository.get_by_id(academic_unit_id)

        if not academic_unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        await self.access.ensure_can_view_academic_unit(academic_unit, user_id, role)
        return self._format(academic_unit)

    async def update_academic_unit(self, academic_unit_id: str, data: AcademicUnitCreate, user_id: str):
        academic_unit = await self.repository.get_by_id(academic_unit_id)

        if not academic_unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        # Ownership is checked against the EXISTING unit's institution, not
        # data.institution_id - otherwise a caller could pass someone
        # else's institution_id in the body to sneak past the check.
        await self._get_owned_institution(academic_unit["institution_id"], user_id)

        if data.institution_id != academic_unit["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="An academic unit cannot be moved to a different institution.",
            )

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(academic_unit_id, update_data)
        return self._format(updated)

    async def delete_academic_unit(self, academic_unit_id: str, user_id: str):
        academic_unit = await self.repository.get_by_id(academic_unit_id)

        if not academic_unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        await self._get_owned_institution(academic_unit["institution_id"], user_id)

        deleted = await self.repository.soft_delete(
            academic_unit_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        return {"message": "Academic unit deleted successfully."}

    def _format(self, academic_unit):
        return {
            "id": str(academic_unit["_id"]),
            "institution_id": academic_unit["institution_id"],
            "name": academic_unit["name"],
            "level": academic_unit["level"],
            "is_active": academic_unit["is_active"],
            "created_at": academic_unit.get("created_at"),
            "updated_at": academic_unit.get("updated_at"),
        }
