from datetime import datetime, time

from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.drivers.repository import DriverRepository
from app.modules.transport.drivers.schemas import DriverCreate


class DriverService:
    def __init__(self):
        self.repository = DriverRepository()
        self.company_repository = CompanyRepository()

    async def create_driver(self, data: DriverCreate, user_id: str):
        company = await self.company_repository.get_by_id(data.company_id)

        if not company:
            raise HTTPException(status_code=404, detail="Company not found.")

        if company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        driver = data.model_dump()

        driver["date_of_birth"] = datetime.combine(driver["date_of_birth"], time.min)
        driver["license_expiry_date"] = datetime.combine(
            driver["license_expiry_date"],
            time.min,
        )

        if driver.get("license_issue_date"):
            driver["license_issue_date"] = datetime.combine(
                driver["license_issue_date"],
                time.min,
            )

        driver["gender"] = driver["gender"].value
        driver["license_category"] = driver["license_category"].value
        driver["status"] = driver["status"].value

        driver.update(BaseDocument.create())
        driver["photo_url"] = None

        driver = await self.repository.create(driver)
        return self._format(driver)

    async def get_drivers(
        self,
        page: int,
        limit: int,
        search: str | None,
        company_id: str | None,
        status: str | None,
    ):
        drivers = await self.repository.get_all(
            page=page,
            limit=limit,
            search=search,
            company_id=company_id,
            status=status,
        )

        return [self._format(driver) for driver in drivers]

    async def get_driver(self, driver_id: str):
        driver = await self.repository.get_by_id(driver_id)

        if not driver:
            raise HTTPException(status_code=404, detail="Driver not found.")

        return self._format(driver)

    async def update_driver(self, driver_id: str, data: DriverCreate, user_id: str):
        driver = await self.repository.get_by_id(driver_id)

        if not driver:
            raise HTTPException(status_code=404, detail="Driver not found.")

        company = await self.company_repository.get_by_id(driver["company_id"])

        if not company or company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        update_data = data.model_dump()

        update_data["date_of_birth"] = datetime.combine(
            update_data["date_of_birth"],
            time.min,
        )
        update_data["license_expiry_date"] = datetime.combine(
            update_data["license_expiry_date"],
            time.min,
        )

        if update_data.get("license_issue_date"):
            update_data["license_issue_date"] = datetime.combine(
                update_data["license_issue_date"],
                time.min,
            )

        update_data["gender"] = update_data["gender"].value
        update_data["license_category"] = update_data["license_category"].value
        update_data["status"] = update_data["status"].value
        update_data.update(BaseDocument.update())

        driver = await self.repository.update(driver_id, update_data)
        return self._format(driver)

    async def delete_driver(self, driver_id: str, user_id: str):
        driver = await self.repository.get_by_id(driver_id)

        if not driver:
            raise HTTPException(status_code=404, detail="Driver not found.")

        company = await self.company_repository.get_by_id(driver["company_id"])

        if not company or company["owner_id"] != user_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        deleted = await self.repository.soft_delete(
            driver_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Driver not found.")

        return {"message": "Driver deleted successfully."}

    def _format(self, driver):
        return {
            "id": str(driver["_id"]),
            "company_id": driver["company_id"],
            "employee_number": driver["employee_number"],
            "first_name": driver["first_name"],
            "last_name": driver["last_name"],
            "gender": driver["gender"],
            "date_of_birth": driver["date_of_birth"],
            "phone": driver["phone"],
            "email": driver.get("email"),
            "license_number": driver["license_number"],
            "license_category": driver["license_category"],
            "license_issue_date": driver.get("license_issue_date"),
            "license_expiry_date": driver["license_expiry_date"],
            "years_of_experience": driver["years_of_experience"],
            "nationality": driver.get("nationality"),
            "country_code": driver["country_code"],
            "city": driver["city"],
            "address": driver.get("address"),
            "photo_url": driver.get("photo_url"),
            "emergency_contact_name": driver.get("emergency_contact_name"),
            "emergency_contact_phone": driver.get("emergency_contact_phone"),
            "status": driver["status"],
            "is_active": driver["is_active"],
            "created_at": driver.get("created_at"),
            "updated_at": driver.get("updated_at"),
        }