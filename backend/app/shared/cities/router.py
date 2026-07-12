from typing import List

from fastapi import APIRouter

from app.shared.cities.schemas import CityCreate, CityResponse
from app.shared.cities.service import CityService

router = APIRouter(
    prefix="/cities",
    tags=["Cities"]
)

service = CityService()


@router.post("/", response_model=CityResponse)
async def create_city(data: CityCreate):
    return await service.create_city(data)


@router.get("/", response_model=List[CityResponse])
async def get_cities():
    return await service.get_all()


@router.get("/{country_code}", response_model=List[CityResponse])
async def get_cities_by_country(country_code: str):
    return await service.get_by_country(country_code)