from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.education.academic_units.repository import AcademicUnitRepository
from app.modules.education.fees.repository import FeeScheduleRepository, StudentFeeRepository
from app.modules.education.fees.schemas import FeeScheduleCreate, StudentFeeCreate
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.students.repository import StudentRepository
from app.payments.repository import PaymentRepository
from app.shared.resolver import LocationResolver


class FeeScheduleService:
    def __init__(self):
        self.repository = FeeScheduleRepository()
        self.institution_repository = InstitutionRepository()
        self.academic_unit_repository = AcademicUnitRepository()
        self.location_resolver = LocationResolver()

    async def _get_owned_institution(self, institution_id: str, user_id: str):
        institution = await self.institution_repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)
        return institution

    async def _resolve_currency(self, institution: dict, currency_id: str | None) -> str:
        country = await self.location_resolver.resolve_country(institution["country_id"])
        return await self.location_resolver.resolve_currency(currency_id, country)

    async def _validate_academic_unit(self, institution_id: str, academic_unit_id: str | None):
        if not academic_unit_id:
            return

        unit = await self.academic_unit_repository.get_by_id(academic_unit_id)

        if not unit:
            raise HTTPException(status_code=404, detail="Academic unit not found.")

        if unit["institution_id"] != institution_id:
            raise HTTPException(
                status_code=400,
                detail="A fee schedule can only target an academic unit of its own institution.",
            )

    async def create_fee_schedule(self, data: FeeScheduleCreate, user_id: str):
        institution = await self._get_owned_institution(data.institution_id, user_id)
        await self._validate_academic_unit(data.institution_id, data.academic_unit_id)

        currency_id = await self._resolve_currency(institution, data.currency_id)

        fee_schedule = data.model_dump()
        fee_schedule["currency_id"] = currency_id
        fee_schedule.update(BaseDocument.create())

        fee_schedule = await self.repository.create(fee_schedule)
        return self._format(fee_schedule)

    async def get_fee_schedules(self, institution_id: str, user_id: str, page: int, limit: int):
        await self._get_owned_institution(institution_id, user_id)

        schedules = await self.repository.get_by_institution(institution_id, page, limit)
        return [self._format(schedule) for schedule in schedules]

    async def get_fee_schedule(self, fee_schedule_id: str, user_id: str):
        schedule = await self.repository.get_by_id(fee_schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Fee schedule not found.")

        await self._get_owned_institution(schedule["institution_id"], user_id)
        return self._format(schedule)

    async def update_fee_schedule(self, fee_schedule_id: str, data: FeeScheduleCreate, user_id: str):
        schedule = await self.repository.get_by_id(fee_schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Fee schedule not found.")

        institution = await self._get_owned_institution(schedule["institution_id"], user_id)

        if data.institution_id != schedule["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="A fee schedule cannot be moved to a different institution.",
            )

        await self._validate_academic_unit(data.institution_id, data.academic_unit_id)

        currency_id = await self._resolve_currency(institution, data.currency_id)

        update_data = data.model_dump()
        update_data["currency_id"] = currency_id
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(fee_schedule_id, update_data)
        return self._format(updated)

    async def delete_fee_schedule(self, fee_schedule_id: str, user_id: str):
        schedule = await self.repository.get_by_id(fee_schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Fee schedule not found.")

        await self._get_owned_institution(schedule["institution_id"], user_id)

        deleted = await self.repository.soft_delete(
            fee_schedule_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Fee schedule not found.")

        return {"message": "Fee schedule deleted successfully."}

    def _format(self, schedule):
        return {
            "id": str(schedule["_id"]),
            "institution_id": schedule["institution_id"],
            "academic_unit_id": schedule.get("academic_unit_id"),
            "name": schedule["name"],
            "amount": schedule["amount"],
            "currency_id": schedule["currency_id"],
            "period": schedule["period"],
            "is_active": schedule["is_active"],
            "created_at": schedule.get("created_at"),
            "updated_at": schedule.get("updated_at"),
        }


class StudentFeeService:
    def __init__(self):
        self.repository = StudentFeeRepository()
        self.fee_schedule_repository = FeeScheduleRepository()
        self.student_repository = StudentRepository()
        self.institution_repository = InstitutionRepository()
        self.payment_repository = PaymentRepository()

    async def _get_owned_student(self, student_id: str, user_id: str):
        student = await self.student_repository.get_by_id(student_id)

        if not student:
            raise HTTPException(status_code=404, detail="Student not found.")

        institution = await self.institution_repository.get_by_id(student["institution_id"])

        if not institution:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(institution["administrator_id"], user_id)
        return student

    async def apply_fee_schedule(self, student_id: str, data: StudentFeeCreate, user_id: str):
        student = await self._get_owned_student(student_id, user_id)

        schedule = await self.fee_schedule_repository.get_by_id(data.fee_schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Fee schedule not found.")

        if schedule["institution_id"] != student["institution_id"]:
            raise HTTPException(
                status_code=400,
                detail="Fee schedule must belong to the student's institution.",
            )

        if (
            schedule.get("academic_unit_id")
            and schedule["academic_unit_id"] != student["academic_unit_id"]
        ):
            raise HTTPException(
                status_code=400,
                detail="This fee schedule does not apply to the student's academic unit.",
            )

        existing = await self.repository.get_by_student_and_schedule(
            student_id, data.fee_schedule_id
        )

        if existing:
            raise HTTPException(
                status_code=409,
                detail="This fee schedule has already been applied to this student.",
            )

        student_fee = {
            "student_id": student_id,
            "fee_schedule_id": data.fee_schedule_id,
            "amount_due": schedule["amount"],
            "currency_id": schedule["currency_id"],
            "amount_paid": 0.0,
            "status": "unpaid",
        }
        student_fee.update(BaseDocument.create())

        student_fee = await self.repository.create(student_fee)
        return await self._format(student_fee)

    async def get_student_fees(self, student_id: str, user_id: str):
        await self._get_owned_student(student_id, user_id)

        fees = await self.repository.get_by_student(student_id)
        return [await self._format(fee) for fee in fees]

    async def _format(self, student_fee):
        schedule = await self.fee_schedule_repository.get_by_id(student_fee["fee_schedule_id"])
        payments = await self.payment_repository.get_all_by_booking(str(student_fee["_id"]))

        return {
            "id": str(student_fee["_id"]),
            "student_id": student_fee["student_id"],
            "fee_schedule_id": student_fee["fee_schedule_id"],
            "fee_schedule_name": schedule["name"] if schedule else "(deleted fee schedule)",
            "period": schedule["period"] if schedule else "",
            "amount_due": student_fee["amount_due"],
            "amount_paid": student_fee["amount_paid"],
            "amount_remaining": round(
                student_fee["amount_due"] - student_fee["amount_paid"], 2
            ),
            "currency_id": student_fee["currency_id"],
            "status": student_fee["status"],
            "payments": [
                {
                    "id": str(payment["_id"]),
                    "amount": payment["amount"],
                    "provider": payment["provider"],
                    "status": payment["status"],
                    "created_at": payment.get("created_at"),
                }
                for payment in payments
            ],
            "is_active": student_fee["is_active"],
            "created_at": student_fee.get("created_at"),
            "updated_at": student_fee.get("updated_at"),
        }
