from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.grades.repository import GradeRepository
from app.modules.education.grades.schemas import GradeCreate
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.modules.education.subjects.repository import SubjectRepository


class GradeService:
    def __init__(self):
        self.repository = GradeRepository()
        self.student_repository = StudentRepository()
        self.institution_repository = InstitutionRepository()
        self.subject_repository = SubjectRepository()

    async def _get_owned_student(self, student_id: str, user_id: str):
        student = await self.student_repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        institution = await self.institution_repository.get_by_id(student["institution_id"])

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return student

    async def _validate_subject(self, institution_id: str, subject_id: str):
        subject = await self.subject_repository.get_by_id(subject_id)

        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found.")

        if subject["institution_id"] != institution_id:
            raise HTTPException(
                status_code=400,
                detail="Subject must belong to the student's institution.",
            )

    async def add_grade(self, student_id: str, data: GradeCreate, user_id: str):
        student = await self._get_owned_student(student_id, user_id)
        await self._validate_subject(student["institution_id"], data.subject_id)

        grade = data.model_dump()
        grade["period"] = grade["period"].value
        grade["student_id"] = student_id
        grade.update(BaseDocument.create())

        grade = await self.repository.create(grade)
        return self._format(grade)

    async def get_grades(self, student_id: str, user_id: str, period: str | None = None):
        await self._get_owned_student(student_id, user_id)

        grades = await self.repository.get_by_student(student_id, period)
        return [self._format(grade) for grade in grades]

    async def update_grade(
        self, student_id: str, grade_id: str, data: GradeCreate, user_id: str
    ):
        student = await self._get_owned_student(student_id, user_id)

        grade = await self.repository.get_by_id(grade_id)

        if not grade or grade["student_id"] != student_id:
            raise HTTPException(status_code=404, detail="Grade not found.")

        await self._validate_subject(student["institution_id"], data.subject_id)

        update_data = data.model_dump()
        update_data["period"] = update_data["period"].value
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(grade_id, update_data)
        return self._format(updated)

    async def get_report_card(self, student_id: str, user_id: str, period: str):
        await self._get_owned_student(student_id, user_id)

        grades = await self.repository.get_by_student(student_id, period)

        by_subject: dict[str, list] = {}
        for grade in grades:
            by_subject.setdefault(grade["subject_id"], []).append(grade)

        subject_averages = []
        # The overall average weights each subject's average by that
        # subject's total coefficient mass for the period (sum of its
        # grades' coefficients), not a plain mean of subject averages.
        # Subject itself carries no coefficient in this data model (only
        # individual grades do), so a subject backed by heavier/more
        # assessments this period counts more toward the overall figure
        # than one with a single light quiz - the closest available
        # proxy for subject importance given what Grade actually stores.
        weighted_total = 0.0
        weight_total = 0.0

        for subject_id, subject_grades in by_subject.items():
            subject = await self.subject_repository.get_by_id(subject_id)

            subject_weight_sum = sum(g["coefficient"] for g in subject_grades)
            subject_weighted_sum = sum(g["value"] * g["coefficient"] for g in subject_grades)
            subject_average = subject_weighted_sum / subject_weight_sum

            subject_averages.append(
                {
                    "subject_id": subject_id,
                    "subject_name": subject["name"] if subject else "(deleted subject)",
                    "average": round(subject_average, 2),
                    "grade_count": len(subject_grades),
                }
            )

            weighted_total += subject_average * subject_weight_sum
            weight_total += subject_weight_sum

        overall_average = round(weighted_total / weight_total, 2) if weight_total else None

        return {
            "student_id": student_id,
            "period": period,
            "subject_averages": subject_averages,
            "overall_average": overall_average,
        }

    def _format(self, grade):
        return {
            "id": str(grade["_id"]),
            "student_id": grade["student_id"],
            "subject_id": grade["subject_id"],
            "value": grade["value"],
            "coefficient": grade["coefficient"],
            "period": grade["period"],
            "is_active": grade["is_active"],
            "created_at": grade.get("created_at"),
            "updated_at": grade.get("updated_at"),
        }
