from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError, OperationFailure

from app.common.base_model import BaseDocument
from app.common.utils import is_transactions_unsupported
from app.core.permissions import ensure_owner
from app.database.mongodb import client as mongo_client
from app.identity.auth.schemas import RegisterRequest
from app.identity.auth.service import AuthService
from app.modules.education.institutions.repository import InstitutionRepository
from app.modules.education.institutions.schemas import (
    InstitutionAccountCreate,
    InstitutionCreate,
    InstitutionProfileCreate,
    PRIVATE_INSTITUTION_TYPES,
    PUBLIC_INSTITUTION_TYPES,
)

_ALREADY_HAS_INSTITUTION_MESSAGE = (
    "You already administer an institution. Only one institution per "
    "school_administrator is allowed."
)


class InstitutionService:
    def __init__(self):
        self.repository = InstitutionRepository()
        self.auth_service = AuthService()

    async def create_institution(self, data: InstitutionCreate, administrator_id: str):
        # Advisory check for a clean error in the common case; the unique
        # index on administrator_id (database/indexes.py) is what actually
        # guarantees the 1:1 constraint under a genuine double-submit race.
        existing = await self.repository.get_by_administrator(administrator_id)

        if existing:
            raise HTTPException(status_code=400, detail=_ALREADY_HAS_INSTITUTION_MESSAGE)

        institution = data.model_dump()
        institution["institution_type"] = institution["institution_type"].value
        institution.update(BaseDocument.create())
        institution["administrator_id"] = administrator_id

        try:
            institution = await self.repository.create(institution)
        except DuplicateKeyError:
            raise HTTPException(status_code=400, detail=_ALREADY_HAS_INSTITUTION_MESSAGE)

        return self._format(institution)

    async def create_public_institution(self, data: InstitutionAccountCreate):
        """POST /admin/institutions: a system_administrator creates the
        Institution and its school_administrator account together,
        active immediately - already vetted by whoever holds the
        system_administrator role, so there's nothing left to validate
        the way a self-registered private institution needs."""
        self._require_type_in(data.institution.institution_type, PUBLIC_INSTITUTION_TYPES)
        return await self._create_with_account(data, is_active=True)

    async def register_private_institution(self, data: InstitutionAccountCreate):
        """POST /auth/register-institution: the future
        school_administrator self-registers, inactive until a
        system_administrator validates them through the same PATCH
        /admin/users/{id}/activate flow company_owner/hotel_owner/
        event_organizer/store_manager already use."""
        self._require_type_in(data.institution.institution_type, PRIVATE_INSTITUTION_TYPES)
        return await self._create_with_account(data, is_active=False)

    def _require_type_in(self, institution_type, allowed_types):
        if institution_type not in allowed_types:
            allowed = ", ".join(sorted(t.value for t in allowed_types))
            raise HTTPException(
                status_code=400,
                detail=f"institution_type must be one of: {allowed}.",
            )

    async def _create_with_account(self, data: InstitutionAccountCreate, is_active: bool):
        """Create the identity/auth account and the Institution together,
        atomically. Same transaction-first, manual-rollback-fallback
        shape as DriverService.create_driver_with_account - tries a
        MongoDB transaction first (requires a replica set / mongos);
        falls back to create-then-rollback against this project's local
        standalone MongoDB, which doesn't support transactions."""
        try:
            return await self._create_with_transaction(data, is_active)
        except OperationFailure as error:
            if not is_transactions_unsupported(error):
                raise
            return await self._create_with_manual_rollback(data, is_active)

    async def _create_with_transaction(self, data: InstitutionAccountCreate, is_active: bool):
        async with await mongo_client.start_session() as session:
            async with session.start_transaction():
                account = await self.auth_service.register_institution_administrator(
                    self._account_data(data), is_active, session=session
                )
                institution = await self._create_profile(
                    data.institution, account, session=session
                )
                return {"account": account, "institution": institution}

    async def _create_with_manual_rollback(self, data: InstitutionAccountCreate, is_active: bool):
        account = await self.auth_service.register_institution_administrator(
            self._account_data(data), is_active
        )

        try:
            institution = await self._create_profile(data.institution, account)
        except Exception:
            await self.auth_service.delete_account(account["id"])
            raise

        return {"account": account, "institution": institution}

    def _account_data(self, data: InstitutionAccountCreate) -> RegisterRequest:
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
        self, profile: InstitutionProfileCreate, account: dict, session=None
    ):
        institution = profile.model_dump()
        institution["institution_type"] = institution["institution_type"].value
        institution.update(BaseDocument.create())
        institution["administrator_id"] = account["id"]

        institution = await self.repository.create(institution, session=session)
        return self._format(institution)

    async def get_my_institution(self, administrator_id: str):
        institution = await self.repository.get_by_administrator(administrator_id)

        if not institution:
            raise HTTPException(status_code=404, detail="You don't administer an institution yet.")

        return self._format(institution)

    async def get_institution(self, institution_id: str, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        # No public browsing for this module - institution records (and
        # everything under them) are only visible to the administrator who
        # owns them. A different, unrelated school_administrator gets 403,
        # not a 404 that would at least confirm the id exists.
        ensure_owner(institution["administrator_id"], user_id)

        return self._format(institution)

    async def update_institution(self, institution_id: str, data: InstitutionCreate, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)

        update_data = data.model_dump()
        update_data["institution_type"] = update_data["institution_type"].value
        update_data.update(BaseDocument.update())

        institution = await self.repository.update(institution_id, update_data)
        return self._format(institution)

    async def delete_institution(self, institution_id: str, user_id: str):
        institution = await self.repository.get_by_id(institution_id)

        if not institution:
            raise HTTPException(status_code=404, detail="Institution not found.")

        ensure_owner(institution["administrator_id"], user_id)

        deleted = await self.repository.soft_delete(
            institution_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Institution not found.")

        return {"message": "Institution deleted successfully."}

    def _format(self, institution):
        return {
            "id": str(institution["_id"]),
            "name": institution["name"],
            "address": institution["address"],
            "city": institution["city"],
            "country_code": institution["country_code"],
            "institution_type": institution["institution_type"],
            "administrator_id": institution["administrator_id"],
            "is_active": institution["is_active"],
            "created_at": institution.get("created_at"),
            "updated_at": institution.get("updated_at"),
        }
