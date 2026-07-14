from typing import List

from fastapi import APIRouter, Depends

from app.core.constants import UserRole
from app.core.dependencies import require_role
from app.shared.currencies.schemas import CurrencyCreate, CurrencyResponse
from app.shared.currencies.service import CurrencyService
router = APIRouter(
    prefix="/currencies",
    tags=["Currencies"]
)

service = CurrencyService()


# Reference data: readable by anyone (GET below), writable only by a
# system_administrator. No PUT/DELETE exist yet on this router - nothing
# else to gate until those are actually added.
@router.post("/", response_model=CurrencyResponse)
async def create_currency(
    data: CurrencyCreate,
    current_user=Depends(require_role(UserRole.SYSTEM_ADMINISTRATOR)),
):
    return await service.create_currency(data)


@router.get("/", response_model=List[CurrencyResponse])
async def get_currencies():
    return await service.get_all()