from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.subjects.repository import SubjectRepository
from app.modules.education.subjects.schemas import SubjectCreate


class SubjectService:
    def __init__(self):
        self.repository = SubjectRepository()
        self.institution_repository = InstitutionRepository()

    async def _get_owned_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)
        return institution

    async def create_subject(self, data: SubjectCreate, user_id: str):
        await self._get_owned_institution(data.institution_id, user_id)

        subject = data.model_dump()
        subject.update(BaseDocument.create())

        subject = await self.repository.create(subject)
        return self._format(subject)

    async def get_subjects(self, institution_id: str, user_id: str, page: int, limit: int):
        await self._get_owned_institution(institution_id, user_id)

        subjects = await self.repository.get_by_institution(institution_id, page, limit)
        return [self._format(subject) for subject in subjects]

    async def get_subject(self, subject_id: str, user_id: str):
        subject = await self.repository.get_by_id(subject_id)

        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found.")

        await self._get_owned_institution(subject["institution_id"], user_id)
        return self._format(subject)

    async def update_subject(self, subject_id: str, data: SubjectCreate, user_id: str):
        subject = await self.repository.get_by_id(subject_id)

        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found.")

        await self._get_owned_institution(subject["institution_id"], user_id)

        if data.institution_id != subject["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="A subject cannot be moved to a different institution.",
            )

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(subject_id, update_data)
        return self._format(updated)

    async def delete_subject(self, subject_id: str, user_id: str):
        subject = await self.repository.get_by_id(subject_id)

        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found.")

        await self._get_owned_institution(subject["institution_id"], user_id)

        deleted = await self.repository.soft_delete(
            subject_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Subject not found.")

        return {"message": "Subject deleted successfully."}

    def _format(self, subject):
        return {
            "id": str(subject["_id"]),
            "institution_id": subject["institution_id"],
            "name": subject["name"],
            "is_active": subject["is_active"],
            "created_at": subject.get("created_at"),
            "updated_at": subject.get("updated_at"),
        }
