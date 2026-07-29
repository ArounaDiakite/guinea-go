from typing import List

from fastapi import APIRouter, Depends

from app.core.constants import UserRole
from app.core.dependencies import require_role
from app.shared.cities.schemas import CityCreate, CityResponse
from app.shared.cities.service import CityService

router = APIRouter(
    prefix="/cities",
    tags=["Cities"]
)

service = CityService()


# Reference data: readable by anyone (GET below), writable only by a
# system_administrator.
@router.post("/", response_model=CityResponse)
async def create_city(
    data: CityCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.create_city(data)


@router.get("/", response_model=List[CityResponse])
async def get_cities():
    return await service.get_all()


@router.get("/{country_code}", response_model=List[CityResponse])
async def get_cities_by_country(country_code: str):
    return await service.get_by_country(country_code)


@router.put("/{city_id}", response_model=CityResponse)
async def update_city(
    city_id: str,
    data: CityCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.update_city(city_id, data)


@router.delete("/{city_id}")
async def delete_city(
    city_id: str,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.delete_city(city_id)