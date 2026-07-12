from typing import List

from fastapi import APIRouter

from app.shared.currencies.schemas import CurrencyCreate, CurrencyResponse
from app.shared.currencies.service import CurrencyService
router = APIRouter(
    prefix="/currencies",
    tags=["Currencies"]
)

service = CurrencyService()


@router.post("/", response_model=CurrencyResponse)
async def create_currency(data: CurrencyCreate):
    return await service.create_currency(data)


@router.get("/", response_model=List[CurrencyResponse])
async def get_currencies():
    return await service.get_all()