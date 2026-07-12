from datetime import datetime, time

from fastapi import HTTPException
from pymongo.errors import OperationFailure

from app.common.base_model import BaseDocument
from app.database.mongodb import client as mongo_client
from app.identity.auth.schemas import RegisterRequest
from app.identity.auth.service import AuthService
from app.modules.companies.repository import CompanyRepository
from app.modules.transport.drivers.repository import DriverRepository
from app.modules.transport.drivers.schemas import (
    DriverAccountCreate,
    DriverCreate,
    DriverProfileCreate,
)

# pymongo OperationFailure code 20 (IllegalOperation) covers several cases;
# only treat it as "transactions unsupported" when the message confirms it -
# i.e. a standalone mongod instead of a replica set / mongos.
_TRANSACTIONS_UNSUPPORTED_CODE = 20


def _is_transactions_unsupported(error: OperationFailure) -> bool:
    return error.code == _TRANSACTIONS_UNSUPPORTED_CODE and (
        "replica set" in str(error).lower()
    )


class DriverService:
    def __init__(self):
        self.repository = DriverRepository()
        self.company_repository = CompanyRepository()
        self.auth_service = AuthService()

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

    async def create_driver_with_account(self, company_id: str, data: DriverAccountCreate):
        """Create the identity/auth account and the transport driver
        profile together, atomically. Tries a MongoDB transaction first
        (requires a replica set / mongos); if the deployment doesn't
        support transactions (e.g. a standalone mongod in local dev),
        falls back to a manual create-then-rollback."""
        try:
            return await self._create_with_transaction(company_id, data)
        except OperationFailure as error:
            if not _is_transactions_unsupported(error):
                raise
            return await self._create_with_manual_rollback(company_id, data)

    async def _create_with_transaction(self, company_id: str, data: DriverAccountCreate):
        async with await mongo_client.start_session() as session:
            async with session.start_transaction():
                account = await self.auth_service.register_driver(
                    company_id, self._account_data(data), session=session
                )
                driver = await self._create_profile(
                    company_id, data.profile, account, session=session
                )
                return {"account": account, "driver": driver}

    async def _create_with_manual_rollback(self, company_id: str, data: DriverAccountCreate):
        account = await self.auth_service.register_driver(company_id, self._account_data(data))

        try:
            driver = await self._create_profile(company_id, data.profile, account)
        except Exception:
            await self.auth_service.delete_account(account["id"])
            raise

        return {"account": account, "driver": driver}

    def _account_data(self, data: DriverAccountCreate) -> RegisterRequest:
        return RegisterRequest(
            first_name=data.first_name,
            last_name=data.last_name,
            email=data.email,
            phone=data.phone,
            password=data.password,
            city=data.city,
            country_code=data.country_code,
            preferred_language=data.preferred_language,
        )

    async def _create_profile(
        self,
        company_id: str,
        profile: DriverProfileCreate,
        account: dict,
        session=None,
    ):
        driver = profile.model_dump()

        driver["company_id"] = company_id
        driver["user_id"] = account["id"]

        # Identity fields live on the auth account; copy them onto the
        # driver document so it stays queryable/formattable on its own,
        # same as a driver created via the standalone POST /drivers/.
        driver["first_name"] = account["first_name"]
        driver["last_name"] = account["last_name"]
        driver["phone"] = account["phone"]
        driver["email"] = account["email"]
        driver["country_code"] = account["country_code"]
        driver["city"] = account["city"]

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

        driver = await self.repository.create(driver, session=session)
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
            "user_id": driver.get("user_id"),
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