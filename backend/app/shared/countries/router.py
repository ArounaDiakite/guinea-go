from typing import List

from fastapi import APIRouter

from app.shared.countries.schemas import CountryCreate, CountryResponse
from app.shared.countries.service import CountryService
router = APIRouter(
    prefix="/countries",
    tags=["Countries"]
)

service = CountryService()


@router.post("/", response_model=CountryResponse)
async def create_country(data: CountryCreate):
    return await service.create_country(data)


@router.get("/", response_model=List[CountryResponse])
async def get_countries():
    return await service.get_all_countries()