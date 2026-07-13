from datetime import datetime, time

from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.attendance.repository import AttendanceRepository
from app.modules.education.attendance.schemas import AttendanceSubmit
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.modules.education.timeslots.repository import TimeSlotRepository


class AttendanceService:
    def __init__(self):
        self.repository = AttendanceRepository()
        self.timeslot_repository = TimeSlotRepository()
        self.academic_unit_repository = AcademicUnitRepository()
        self.institution_repository = InstitutionRepository()
        self.student_repository = StudentRepository()

    async def _get_owned_timeslot(self, timeslot_id: str, user_id: str):
        timeslot = await self.timeslot_repository.get_by_id(timeslot_id)

        if not timeslot:
            raise HTTPException(status_code=404, detail="Time slot not found.")

        academic_unit = await self.academic_unit_repository.get_by_id(
            timeslot["academic_unit_id"]
        )

        if not academic_unit:
            raise HTTPException(status_code=403, detail="Not allowed.")

        institution = await self.institution_repository.get_by_id(
            academic_unit["institution_id"]
        )

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return timeslot

    async def _get_owned_student(self, student_id: str, user_id: str):
        student = await self.student_repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        institution = await self.institution_repository.get_by_id(student["institution_id"])

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return student

    async def _validate_entries(self, timeslot: dict, data: AttendanceSubmit):
        for entry in data.entries:
            student = await self.student_repository.get_by_id(entry.student_id)

            if not student:
                raise HTTPException(
                    status_code=404, detail=f"Student {entry.student_id} not found."
                )

            if student["academic_unit_id"] != timeslot["academic_unit_id"]:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Student {entry.student_id} does not belong to this "
                        "time slot's academic unit."
                    ),
                )

    async def submit_attendance(self, timeslot_id: str, data: AttendanceSubmit, user_id: str):
        timeslot = await self._get_owned_timeslot(timeslot_id, user_id)
        await self._validate_entries(timeslot, data)

        record_date = datetime.combine(data.date, time.min)

        existing = await self.repository.get_by_timeslot_and_date(timeslot_id, record_date)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Attendance for this time slot and date has already been "
                    "recorded. Use PUT to correct it."
                ),
            )

        base = BaseDocument.create()
        records = [
            {
                "timeslot_id": timeslot_id,
                "student_id": entry.student_id,
                "date": record_date,
                "status": entry.status.value,
                **base,
            }
            for entry in data.entries
        ]

        created = await self.repository.create_many(timeslot_id, record_date, records)

        if created is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Attendance for this time slot and date has already been "
                    "recorded. Use PUT to correct it."
                ),
            )

        return [self._format(record) for record in created]

    async def update_attendance(self, timeslot_id: str, data: AttendanceSubmit, user_id: str):
        timeslot = await self._get_owned_timeslot(timeslot_id, user_id)
        await self._validate_entries(timeslot, data)

        record_date = datetime.combine(data.date, time.min)

        existing = await self.repository.get_by_timeslot_and_date(timeslot_id, record_date)
        if not existing:
            raise HTTPException(
                status_code=404,
                detail=(
                    "No attendance recorded yet for this time slot and date. "
                    "Use POST to record it first."
                ),
            )

        results = []
        for entry in data.entries:
            record = await self.repository.get_one(timeslot_id, record_date, entry.student_id)

            if record:
                updated = await self.repository.update_status(
                    str(record["_id"]),
                    {"status": entry.status.value, **BaseDocument.update()},
                )
                results.append(updated)
            else:
                new_record = {
                    "timeslot_id": timeslot_id,
                    "student_id": entry.student_id,
                    "date": record_date,
                    "status": entry.status.value,
                    **BaseDocument.create(),
                }
                results.append(await self.repository.create_one(new_record))

        return [self._format(record) for record in results]

    async def get_student_attendance(
        self, student_id: str, user_id: str, page: int, limit: int
    ):
        await self._get_owned_student(student_id, user_id)

        records = await self.repository.get_by_student(student_id, page, limit)
        return [self._format(record) for record in records]

    def _format(self, record):
        return {
            "id": str(record["_id"]),
            "timeslot_id": record["timeslot_id"],
            "student_id": record["student_id"],
            "date": record["date"].date(),
            "status": record["status"],
            "is_active": record["is_active"],
            "created_at": record.get("created_at"),
            "updated_at": record.get("updated_at"),
        }
