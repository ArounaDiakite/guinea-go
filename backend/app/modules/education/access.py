"""Shared "can this caller see/act on this academic unit or student"
checks, reused across every education service that needs to admit
teacher/student self-access alongside the existing school_administrator
ownership check.

Kept in one place, unlike the trivial 3-line ensure_owner pattern
duplicated per-service elsewhere in this module - this check is
genuinely stateful (it looks up the caller's own Teacher/Student
profile via user_id) and repeating that safely across six call sites
would risk drift between them.
"""

from fastapi import HTTPException

from app.core.constants import UserRole
from app.core.permissions import ensure_owner
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.modules.education.teachers.repository import TeacherRepository


class EducationAccess:
    def __init__(self):
        self.institution_repository = InstitutionRepository()
        self.teacher_repository = TeacherRepository()
        self.student_repository = StudentRepository()

    async def _ensure_owner_of_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)

    async def ensure_can_view_academic_unit(self, academic_unit: dict, user_id: str, role: str):
        """school_administrator who owns the institution, a teacher
        assigned to this unit (academic_units:view_own), or a student
        enrolled in it (timeslots:view_self reaches its own schedule
        through the academic unit)."""
        unit_id = str(academic_unit["_id"])

        if role == UserRole.TEACHER:
            teacher = await self.teacher_repository.get_by_user_id(user_id)
            if teacher and unit_id in teacher.get("academic_unit_ids", []):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        if role == UserRole.STUDENT:
            student = await self.student_repository.get_by_user_id(user_id)
            if student and student["academic_unit_id"] == unit_id:
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        await self._ensure_owner_of_institution(academic_unit["institution_id"], user_id)

    async def ensure_can_list_students(
        self, institution_id: str, academic_unit_id: str | None, user_id: str, role: str
    ):
        """school_administrator (any/all academic units), or a teacher
        restricted to one of their own assigned units - students:view_own
        requires academic_unit_id to be provided and to be theirs, unlike
        the admin path which can list the whole institution at once."""
        if role == UserRole.TEACHER:
            teacher = await self.teacher_repository.get_by_user_id(user_id)
            if (
                teacher
                and teacher["institution_id"] == institution_id
                and academic_unit_id
                and academic_unit_id in teacher.get("academic_unit_ids", [])
            ):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        await self._ensure_owner_of_institution(institution_id, user_id)

    async def ensure_can_view_student_profile(self, student: dict, user_id: str, role: str):
        """school_administrator, or a teacher assigned to the student's
        academic unit (students:view_own). No student-self branch here -
        a student reaches their own profile through GET /students/me,
        not by id."""
        if role == UserRole.TEACHER:
            teacher = await self.teacher_repository.get_by_user_id(user_id)
            if teacher and student["academic_unit_id"] in teacher.get("academic_unit_ids", []):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        await self._ensure_owner_of_institution(student["institution_id"], user_id)

    async def ensure_can_view_student_grades(self, student: dict, user_id: str, role: str):
        """school_administrator, a teacher assigned to the student's unit
        (grades:view_own), or the student themselves (grades:view_self /
        report_card:view_self)."""
        if role == UserRole.STUDENT:
            own = await self.student_repository.get_by_user_id(user_id)
            if own and str(own["_id"]) == str(student["_id"]):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        if role == UserRole.TEACHER:
            teacher = await self.teacher_repository.get_by_user_id(user_id)
            if teacher and student["academic_unit_id"] in teacher.get("academic_unit_ids", []):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        await self._ensure_owner_of_institution(student["institution_id"], user_id)

    async def ensure_can_view_own_student_record(self, student: dict, user_id: str, role: str):
        """school_administrator, or the student themselves -
        attendance:view_self and fees:view_self. No teacher branch: a
        teacher can manage attendance (see ensure_teacher_owns_timeslot)
        but was not given a permission to browse a student's attendance
        history or fee balance."""
        if role == UserRole.STUDENT:
            own = await self.student_repository.get_by_user_id(user_id)
            if own and str(own["_id"]) == str(student["_id"]):
                return
            raise HTTPException(status_code=403, detail="Not allowed.")

        await self._ensure_owner_of_institution(student["institution_id"], user_id)

    async def ensure_teacher_owns_timeslot(self, timeslot: dict, user_id: str):
        """attendance:manage_own - a teacher may only submit/correct
        attendance for a time slot actually assigned to them."""
        teacher = await self.teacher_repository.get_by_user_id(user_id)

        if not teacher or timeslot["teacher_id"] != str(teacher["_id"]):
            raise HTTPException(status_code=403, detail="Not allowed.")

        return teacher
