from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.institutions.schemas import InstitutionCreate

_ALREADY_HAS_INSTITUTION_MESSAGE = (
    "You already administer an institution. Only one institution per "
    "school_administrator is allowed."
)


class InstitutionService:
    def __init__(self):
        self.repository = InstitutionRepository()

    async def create_institution(self, data: InstitutionCreate, administrator_id: str):
        # Advisory check for a clean error in the common case; the unique
        # index on administrator_id (database/indexes.py) is what actually
        # guarantees the 1:1 constraint under a genuine double-submit race.
        existing = await self.repository.get_by_administrator(administrator_id)

        if existing:
            raise HTTPException(status_code=400, detail=_ALREADY_HAS_INSTITUTION_MESSAGE)

        institution = data.model_dump()
        institution["institution_type"] = institution["institution_type"].value
        institution.update(BaseDocument.create())
        institution["administrator_id"] = administrator_id

        try:
            institution = await self.repository.create(institution)
        except DuplicateKeyError:
            raise HTTPException(status_code=400, detail=_ALREADY_HAS_INSTITUTION_MESSAGE)

        return self._format(institution)

    async def get_my_institution(self, administrator_id: str):
        institution = await self.repository.get_by_administrator(administrator_id)

        if not institution:
            raise HTTPException(status_code=404, detail="You don't administer an institution yet.")

        return self._format(institution)

    async def get_institution(self, institution_id: str, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        # No public browsing for this module - institution records (and
        # everything under them) are only visible to the administrator who
        # owns them. A different, unrelated school_administrator gets 403,
        # not a 404 that would at least confirm the id exists.
        ensure_owner(institution["administrator_id"], user_id)

        return self._format(institution)

    async def update_institution(self, institution_id: str, data: InstitutionCreate, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)

        update_data = data.model_dump()
        update_data["institution_type"] = update_data["institution_type"].value
        update_data.update(BaseDocument.update())

        institution = await self.repository.update(institution_id, update_data)
        return self._format(institution)

    async def delete_institution(self, institution_id: str, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)

        deleted = await self.repository.soft_delete(
            institution_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Institution not found.")

        return {"message": "Institution deleted successfully."}

    def _format(self, institution):
        return {
            "id": str(institution["_id"]),
            "name": institution["name"],
            "address": institution["address"],
            "city": institution["city"],
            "country_code": institution["country_code"],
            "institution_type": institution["institution_type"],
            "administrator_id": institution["administrator_id"],
            "is_active": institution["is_active"],
            "created_at": institution.get("created_at"),
            "updated_at": institution.get("updated_at"),
        }
