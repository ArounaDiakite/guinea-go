from fastapi import HTTPException

from app.shared.currencies.repository import CurrencyRepository
from app.shared.currencies.schemas import CurrencyCreate


class CurrencyService:
    def __init__(self):
        self.repository = CurrencyRepository()

    async def create_currency(self, data: CurrencyCreate):
        existing = await self.repository.get_by_code(data.code)

        if existing:
            raise HTTPException(
                status_code=400,
                detail="Currency already exists."
            )

        currency = await self.repository.create_currency(
            data.model_dump()
        )

        return self._format(currency)

    async def get_all(self):
        currencies = await self.repository.get_all()
        return [self._format(c) for c in currencies]

    def _format(self, currency):
        return {
            "id": str(currency["_id"]),
            "code": currency["code"],
            "name": currency["name"],
            "symbol": currency["symbol"],
            "is_active": currency["is_active"],
        }