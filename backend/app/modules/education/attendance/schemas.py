from datetime import date as date_type, datetime
from enum import Enum

from pydantic import BaseModel, Field, field_validator


class AttendanceStatus(str, Enum):
    PRESENT = "present"
    ABSENT = "absent"
    LATE = "late"
    EXCUSED = "excused"


class AttendanceEntry(BaseModel):
    student_id: str
    status: AttendanceStatus


class AttendanceSubmit(BaseModel):
    date: date_type
    entries: list[AttendanceEntry] = Field(..., min_length=1)

    @field_validator("entries")
    @classmethod
    def no_duplicate_students(cls, entries):
        student_ids = [entry.student_id for entry in entries]
        if len(student_ids) != len(set(student_ids)):
            raise ValueError("Each student can only appear once per submission.")
        return entries


class AttendanceRecordResponse(BaseModel):
    id: str
    timeslot_id: str
    student_id: str
    date: date_type
    status: AttendanceStatus
    is_active: bool
    created_at: datetime | None = None
    updated_at: datetime | None = None
