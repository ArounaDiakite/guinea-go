from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.buses.repository import BusRepository
from app.modules.transport.buses.schemas import BusCreate


class BusService:
    def __init__(self):
        self.repository = BusRepository()
        self.company_repository = CompanyRepository()

    async def create_bus(self, data: BusCreate, user_id: str):
        company = await self.company_repository.get_by_id(data.company_id)

        if not company:
            raise HTTPException(status_code=404, detail="Company not found.")

        ensure_owner(company["owner_id"], user_id)

        bus = data.model_dump()
        bus["bus_type"] = bus["bus_type"].value
        bus["status"] = bus["status"].value
        bus.update(BaseDocument.create())
        bus["photos"] = []

        bus = await self.repository.create(bus)
        return self._format(bus)

    async def get_buses(self, page: int, limit: int, search: str | None, company_id: str | None, status: str | None):
        buses = await self.repository.get_all(page, limit, search, company_id, status)
        return [self._format(bus) for bus in buses]

    async def get_bus(self, bus_id: str):
        bus = await self.repository.get_by_id(bus_id)

        if not bus:
            raise HTTPException(status_code=404, detail="Bus not found.")

        return self._format(bus)

    async def update_bus(self, bus_id: str, data: BusCreate, user_id: str):
        bus = await self.repository.get_by_id(bus_id)

        if not bus:
            raise HTTPException(status_code=404, detail="Bus not found.")

        company = await self.company_repository.get_by_id(bus["company_id"])

        if not company:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(company["owner_id"], user_id)

        update_data = data.model_dump()
        update_data["bus_type"] = update_data["bus_type"].value
        update_data["status"] = update_data["status"].value
        update_data.update(BaseDocument.update())

        updated_bus = await self.repository.update(bus_id, update_data)
        return self._format(updated_bus)

    async def delete_bus(self, bus_id: str, user_id: str):
        bus = await self.repository.get_by_id(bus_id)

        if not bus:
            raise HTTPException(status_code=404, detail="Bus not found.")

        company = await self.company_repository.get_by_id(bus["company_id"])

        if not company:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(company["owner_id"], user_id)

        deleted = await self.repository.soft_delete(
            bus_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Bus not found.")

        return {"message": "Bus deleted successfully."}

    def _format(self, bus):
        return {
            "id": str(bus["_id"]),
            "company_id": bus["company_id"],
            "registration_number": bus["registration_number"],
            "fleet_number": bus["fleet_number"],
            "brand": bus["brand"],
            "model": bus["model"],
            "manufacture_year": bus["manufacture_year"],
            "color": bus.get("color"),
            "seat_capacity": bus["seat_capacity"],
            "bus_type": bus["bus_type"],
            "air_conditioning": bus["air_conditioning"],
            "wifi": bus["wifi"],
            "usb_charging": bus["usb_charging"],
            "toilet": bus["toilet"],
            "television": bus["television"],
            "status": bus["status"],
            "photos": bus.get("photos", []),
            "is_active": bus["is_active"],
            "created_at": bus.get("created_at"),
            "updated_at": bus.get("updated_at"),
        }