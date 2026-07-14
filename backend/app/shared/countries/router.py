from typing import List

from fastapi import APIRouter, Depends

from app.core.constants import UserRole
from app.core.dependencies import require_role
from app.shared.countries.schemas import CountryCreate, CountryResponse
from app.shared.countries.service import CountryService
router = APIRouter(
    prefix="/countries",
    tags=["Countries"]
)

service = CountryService()


# Reference data: readable by anyone (GET below), writable only by a
# system_administrator. No PUT/DELETE exist yet on this router - nothing
# else to gate until those are actually added.
@router.post("/", response_model=CountryResponse)
async def create_country(
    data: CountryCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.create_country(data)


@router.get("/", response_model=List[CountryResponse])
async def get_countries():
    return await service.get_all_countries()