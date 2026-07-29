from fastapi import HTTPException

from app.shared.countries.repository import CountryRepository
from app.shared.countries.schemas import CountryCreate, CountryResponse
from app.shared.currencies.repository import CurrencyRepository


class CountryService:
    def __init__(self):
        self.repository = CountryRepository()
        self.currency_repository = CurrencyRepository()

    async def create_country(self, data: CountryCreate):
        existing_country = await self.repository.get_country_by_code(data.code)

        if existing_country:
            raise HTTPException(
                status_code=400,
                detail="Country already exists."
            )

        currency = await self.currency_repository.get_by_code(data.currency_code)

        if not currency:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Currency '{data.currency_code}' does not exist. "
                    "Create it via POST /currencies first."
                ),
            )

        country_data = data.model_dump(exclude={"currency_code"})
        country_data["code"] = data.code.upper()
        country_data["currency_id"] = str(currency["_id"])
        country_data["languages"] = [lang.lower() for lang in data.languages]

        country = await self.repository.create_country(country_data)

        return self._format_country(country)

    async def get_all_countries(self):
        countries = await self.repository.get_all_countries()
        return [self._format_country(country) for country in countries]

    async def update_country(self, country_id: str, data: CountryCreate):
        country = await self.repository.get_by_id(country_id)

        if not country:
            raise HTTPException(status_code=404, detail="Country not found.")

        existing_with_code = await self.repository.get_country_by_code(data.code)

        if existing_with_code and str(existing_with_code["_id"]) != country_id:
            raise HTTPException(status_code=400, detail="Country already exists.")

        currency = await self.currency_repository.get_by_code(data.currency_code)

        if not currency:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Currency '{data.currency_code}' does not exist. "
                    "Create it via POST /currencies first."
                ),
            )

        update_data = data.model_dump(exclude={"currency_code"})
        update_data["code"] = data.code.upper()
        update_data["currency_id"] = str(currency["_id"])
        update_data["languages"] = [lang.lower() for lang in data.languages]

        country = await self.repository.update(country_id, update_data)
        return self._format_country(country)

    async def delete_country(self, country_id: str):
        country = await self.repository.get_by_id(country_id)

        if not country:
            raise HTTPException(status_code=404, detail="Country not found.")

        await self.repository.soft_delete(country_id)
        return {"message": "Country deleted successfully."}

    def _format_country(self, country):
        return {
            "id": str(country["_id"]),
            "code": country["code"],
            "name": country["name"],
            "currency_id": country["currency_id"],
            "timezone": country["timezone"],
            "languages": country["languages"],
            "payment_methods": country["payment_methods"],
            "is_active": country["is_active"],
        }