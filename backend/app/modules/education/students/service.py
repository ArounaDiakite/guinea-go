from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.modules.education.students.schemas import StudentCreate


class StudentService:
    def __init__(self):
        self.repository = StudentRepository()
        self.institution_repository = InstitutionRepository()
        self.academic_unit_repository = AcademicUnitRepository()

    async def _get_owned_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)
        return institution

    async def _validate_academic_unit(self, institution_id: str, academic_unit_id: str):
        unit = await self.academic_unit_repository.get_by_id(academic_unit_id)

        if not unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        if unit["institution_id"] != institution_id:
            raise HTTPException(
                status_code=400,
                detail="A student can only be enrolled in an academic unit of their own institution.",
            )

    async def create_student(self, data: StudentCreate, user_id: str):
        await self._get_owned_institution(data.institution_id, user_id)
        await self._validate_academic_unit(data.institution_id, data.academic_unit_id)

        student = data.model_dump()
        student.update(BaseDocument.create())

        student = await self.repository.create(student)
        return self._format(student)

    async def get_students(
        self,
        institution_id: str,
        user_id: str,
        page: int,
        limit: int,
        academic_unit_id: str | None,
    ):
        await self._get_owned_institution(institution_id, user_id)

        students = await self.repository.get_by_institution(
            institution_id, page, limit, academic_unit_id
        )
        return [self._format(student) for student in students]

    async def get_student(self, student_id: str, user_id: str):
        student = await self.repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        await self._get_owned_institution(student["institution_id"], user_id)
        return self._format(student)

    async def update_student(self, student_id: str, data: StudentCreate, user_id: str):
        student = await self.repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        await self._get_owned_institution(student["institution_id"], user_id)

        if data.institution_id != student["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="A student cannot be moved to a different institution.",
            )

        await self._validate_academic_unit(data.institution_id, data.academic_unit_id)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(student_id, update_data)
        return self._format(updated)

    async def delete_student(self, student_id: str, user_id: str):
        student = await self.repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        await self._get_owned_institution(student["institution_id"], user_id)

        deleted = await self.repository.soft_delete(
            student_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Student not found.")

        return {"message": "Student deleted successfully."}

    def _format(self, student):
        return {
            "id": str(student["_id"]),
            "institution_id": student["institution_id"],
            "academic_unit_id": student["academic_unit_id"],
            "first_name": student["first_name"],
            "last_name": student["last_name"],
            "date_of_birth": student.get("date_of_birth"),
            "guardian_name": student.get("guardian_name"),
            "guardian_phone": student.get("guardian_phone"),
            "is_active": student["is_active"],
            "created_at": student.get("created_at"),
            "updated_at": student.get("updated_at"),
        }
