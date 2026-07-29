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
# system_administrator.
@router.post("/", response_model=CountryResponse)
async def create_country(
    data: CountryCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.create_country(data)


@router.get("/", response_model=List[CountryResponse])
async def get_countries():
    return await service.get_all_countries()


@router.put("/{country_id}", response_model=CountryResponse)
async def update_country(
    country_id: str,
    data: CountryCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.update_country(country_id, data)


@router.delete("/{country_id}")
async def delete_country(
    country_id: str,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.delete_country(country_id)