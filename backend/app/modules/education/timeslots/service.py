from datetime import date, datetime

from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.subjects.repository import SubjectRepository
from app.modules.education.teachers.repository import TeacherRepository
from app.modules.education.timeslots.repository import TimeSlotRepository
from app.modules.education.timeslots.schemas import TimeSlotCreate


class TimeSlotConflictException(HTTPException):
    def __init__(self, detail: str):
        super().__init__(status_code=status.HTTP_409_CONFLICT, detail=detail)


class TimeSlotService:
    def __init__(self):
        self.repository = TimeSlotRepository()
        self.academic_unit_repository = AcademicUnitRepository()
        self.institution_repository = InstitutionRepository()
        self.subject_repository = SubjectRepository()
        self.teacher_repository = TeacherRepository()

    async def _get_owned_academic_unit(self, academic_unit_id: str, user_id: str):
        academic_unit = await self.academic_unit_repository.get_by_id(academic_unit_id)

        if not academic_unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        institution = await self.institution_repository.get_by_id(academic_unit["institution_id"])

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return academic_unit

    async def _validate_references(self, academic_unit: dict, data: TimeSlotCreate):
        institution_id = academic_unit["institution_id"]

        subject = await self.subject_repository.get_by_id(data.subject_id)

        if not subject:
            raise HTTPException(status_code=404, detail="Subject not found.")

        if subject["institution_id"] != institution_id:
            raise HTTPException(
                status_code=400,
                detail="Subject must belong to the same institution as the academic unit.",
            )

        teacher = await self.teacher_repository.get_by_id(data.teacher_id)

        if not teacher:
            raise HTTPException(status_code=404, detail="Teacher not found.")

        if teacher["institution_id"] != institution_id:
            raise HTTPException(
                status_code=400,
                detail="Teacher must belong to the same institution as the academic unit.",
            )

        if data.academic_unit_id not in teacher.get("academic_unit_ids", []):
            raise HTTPException(
                status_code=400,
                detail="This teacher is not assigned to this academic unit.",
            )

    async def _check_overlaps(self, data: TimeSlotCreate, start_dt, end_dt, exclude_id=None):
        teacher_conflict = await self.repository.has_overlap(
            "teacher_id", data.teacher_id, data.day_of_week.value, start_dt, end_dt, exclude_id
        )

        if teacher_conflict:
            raise TimeSlotConflictException(
                "This teacher already has an overlapping time slot on this day."
            )

        unit_conflict = await self.repository.has_overlap(
            "academic_unit_id", data.academic_unit_id, data.day_of_week.value, start_dt, end_dt, exclude_id
        )

        if unit_conflict:
            raise TimeSlotConflictException(
                "This academic unit already has an overlapping time slot on this day."
            )

    async def create_timeslot(self, data: TimeSlotCreate, user_id: str):
        academic_unit = await self._get_owned_academic_unit(data.academic_unit_id, user_id)
        await self._validate_references(academic_unit, data)

        start_dt = datetime.combine(date.today(), data.start_time)
        end_dt = datetime.combine(date.today(), data.end_time)

        await self._check_overlaps(data, start_dt, end_dt)

        timeslot = data.model_dump()
        timeslot["day_of_week"] = timeslot["day_of_week"].value
        timeslot["start_time"] = start_dt
        timeslot["end_time"] = end_dt
        timeslot.update(BaseDocument.create())

        timeslot = await self.repository.create(timeslot)
        return self._format(timeslot)

    async def get_timeslot(self, timeslot_id: str, user_id: str):
        timeslot = await self.repository.get_by_id(timeslot_id)

        if not timeslot:
            raise HTTPException(status_code=404, detail="Time slot not found.")

        await self._get_owned_academic_unit(timeslot["academic_unit_id"], user_id)
        return self._format(timeslot)

    async def update_timeslot(self, timeslot_id: str, data: TimeSlotCreate, user_id: str):
        timeslot = await self.repository.get_by_id(timeslot_id)

        if not timeslot:
            raise HTTPException(status_code=404, detail="Time slot not found.")

        if data.academic_unit_id != timeslot["academic_unit_id"]:
            raise HTTPException(
                status_code=400,
                detail="A time slot cannot be moved to a different academic unit.",
            )

        academic_unit = await self._get_owned_academic_unit(data.academic_unit_id, user_id)
        await self._validate_references(academic_unit, data)

        start_dt = datetime.combine(date.today(), data.start_time)
        end_dt = datetime.combine(date.today(), data.end_time)

        await self._check_overlaps(data, start_dt, end_dt, exclude_id=timeslot_id)

        update_data = data.model_dump()
        update_data["day_of_week"] = update_data["day_of_week"].value
        update_data["start_time"] = start_dt
        update_data["end_time"] = end_dt
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(timeslot_id, update_data)
        return self._format(updated)

    async def delete_timeslot(self, timeslot_id: str, user_id: str):
        timeslot = await self.repository.get_by_id(timeslot_id)

        if not timeslot:
            raise HTTPException(status_code=404, detail="Time slot not found.")

        await self._get_owned_academic_unit(timeslot["academic_unit_id"], user_id)

        deleted = await self.repository.soft_delete(
            timeslot_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Time slot not found.")

        return {"message": "Time slot deleted successfully."}

    async def get_schedule(self, academic_unit_id: str, user_id: str):
        await self._get_owned_academic_unit(academic_unit_id, user_id)

        timeslots = await self.repository.get_by_academic_unit(academic_unit_id)

        schedule = []
        for timeslot in timeslots:
            subject = await self.subject_repository.get_by_id(timeslot["subject_id"])
            teacher = await self.teacher_repository.get_by_id(timeslot["teacher_id"])

            schedule.append(
                {
                    "id": str(timeslot["_id"]),
                    "subject_id": timeslot["subject_id"],
                    "subject_name": subject["name"] if subject else "(deleted subject)",
                    "teacher_id": timeslot["teacher_id"],
                    "teacher_name": (
                        f"{teacher['first_name']} {teacher['last_name']}"
                        if teacher
                        else "(deleted teacher)"
                    ),
                    "day_of_week": timeslot["day_of_week"],
                    "start_time": timeslot["start_time"].time(),
                    "end_time": timeslot["end_time"].time(),
                }
            )

        return schedule

    def _format(self, timeslot):
        return {
            "id": str(timeslot["_id"]),
            "academic_unit_id": timeslot["academic_unit_id"],
            "subject_id": timeslot["subject_id"],
            "teacher_id": timeslot["teacher_id"],
            "day_of_week": timeslot["day_of_week"],
            "start_time": timeslot["start_time"].time(),
            "end_time": timeslot["end_time"].time(),
            "is_active": timeslot["is_active"],
            "created_at": timeslot.get("created_at"),
            "updated_at": timeslot.get("updated_at"),
        }
