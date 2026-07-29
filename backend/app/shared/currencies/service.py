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

    async def update_currency(self, currency_id: str, data: CurrencyCreate):
        currency = await self.repository.get_by_id(currency_id)

        if not currency:
            raise HTTPException(status_code=404, detail="Currency not found.")

        existing = await self.repository.get_by_code(data.code)

        if existing and str(existing["_id"]) != currency_id:
            raise HTTPException(status_code=400, detail="Currency already exists.")

        currency = await self.repository.update(currency_id, data.model_dump())
        return self._format(currency)

    async def delete_currency(self, currency_id: str):
        currency = await self.repository.get_by_id(currency_id)

        if not currency:
            raise HTTPException(status_code=404, detail="Currency not found.")

        await self.repository.soft_delete(currency_id)
        return {"message": "Currency deleted successfully."}

    def _format(self, currency):
        return {
            "id": str(currency["_id"]),
            "code": currency["code"],
            "name": currency["name"],
            "symbol": currency["symbol"],
            "is_active": currency["is_active"],
        }