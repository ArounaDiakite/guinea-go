from datetime import datetime, date

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.routes.repository import RouteRepository
from app.modules.transport.schedules.repository import ScheduleRepository
from app.modules.transport.schedules.schemas import ScheduleCreate


class ScheduleService:
    def __init__(self):
        self.repository = ScheduleRepository()
        self.company_repository = CompanyRepository()
        self.route_repository = RouteRepository()

    async def create_schedule(self, data: ScheduleCreate, user_id: str):
        company = await self.company_repository.get_by_id(data.company_id)

        if not company:
            raise HTTPException(status_code=404, detail="Company not found.")

        if company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        route = await self.route_repository.get_by_id(data.route_id)

        if not route:
            raise HTTPException(status_code=404, detail="Route not found.")

        if route["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Route does not belong to this company.",
            )

        schedule = data.model_dump()

        schedule["departure_time"] = datetime.combine(
            date.today(),
            schedule["departure_time"],
        )

        if schedule.get("estimated_arrival_time"):
            schedule["estimated_arrival_time"] = datetime.combine(
                date.today(),
                schedule["estimated_arrival_time"],
            )

        schedule["operating_days"] = [
            day.value for day in schedule["operating_days"]
        ]
        schedule["status"] = schedule["status"].value

        schedule.update(BaseDocument.create())

        schedule = await self.repository.create(schedule)
        return self._format(schedule)

    async def get_schedules(
        self,
        page: int,
        limit: int,
        company_id: str | None,
        route_id: str | None,
        status: str | None,
    ):
        schedules = await self.repository.get_all(
            page=page,
            limit=limit,
            company_id=company_id,
            route_id=route_id,
            status=status,
        )

        return [self._format(schedule) for schedule in schedules]

    async def get_schedule(self, schedule_id: str):
        schedule = await self.repository.get_by_id(schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        return self._format(schedule)

    async def update_schedule(
        self,
        schedule_id: str,
        data: ScheduleCreate,
        user_id: str,
    ):
        schedule = await self.repository.get_by_id(schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        company = await self.company_repository.get_by_id(schedule["company_id"])

        if not company or company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        route = await self.route_repository.get_by_id(data.route_id)

        if not route:
            raise HTTPException(status_code=404, detail="Route not found.")

        if route["company_id"] != data.company_id:
            raise HTTPException(
                status_code=400,
                detail="Route does not belong to this company.",
            )

        update_data = data.model_dump()

        update_data["departure_time"] = datetime.combine(
            date.today(),
            update_data["departure_time"],
        )

        if update_data.get("estimated_arrival_time"):
            update_data["estimated_arrival_time"] = datetime.combine(
                date.today(),
                update_data["estimated_arrival_time"],
            )

        update_data["operating_days"] = [
            day.value for day in update_data["operating_days"]
        ]
        update_data["status"] = update_data["status"].value
        update_data.update(BaseDocument.update())

        schedule = await self.repository.update(schedule_id, update_data)
        return self._format(schedule)

    async def delete_schedule(self, schedule_id: str, user_id: str):
        schedule = await self.repository.get_by_id(schedule_id)

        if not schedule:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        company = await self.company_repository.get_by_id(schedule["company_id"])

        if not company or company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        deleted = await self.repository.soft_delete(
            schedule_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Schedule not found.")

        return {"message": "Schedule deleted successfully."}

    def _format(self, schedule):
        return {
            "id": str(schedule["_id"]),
            "company_id": schedule["company_id"],
            "route_id": schedule["route_id"],
            "departure_time": schedule["departure_time"].time(),
            "estimated_arrival_time": (
                schedule["estimated_arrival_time"].time()
                if schedule.get("estimated_arrival_time")
                else None
            ),
            "operating_days": schedule["operating_days"],
            "status": schedule["status"],
            "notes": schedule.get("notes"),
            "is_active": schedule["is_active"],
            "created_at": schedule.get("created_at"),
            "updated_at": schedule.get("updated_at"),
        }