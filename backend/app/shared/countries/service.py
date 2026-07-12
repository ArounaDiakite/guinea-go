from fastapi import HTTPException

from app.shared.countries.repository import CountryRepository
from app.shared.countries.schemas import CountryCreate, CountryResponse


class CountryService:
    def __init__(self):
        self.repository = CountryRepository()

    async def create_country(self, data: CountryCreate):
        existing_country = await self.repository.get_country_by_code(data.code)

        if existing_country:
            raise HTTPException(
                status_code=400,
                detail="Country already exists."
            )

        country_data = data.model_dump()
        country_data["code"] = data.code.upper()
        country_data["currency"] = data.currency.upper()
        country_data["languages"] = [lang.lower() for lang in data.languages]

        country = await self.repository.create_country(country_data)

        return self._format_country(country)

    async def get_all_countries(self):
        countries = await self.repository.get_all_countries()
        return [self._format_country(country) for country in countries]

    def _format_country(self, country):
        return {
            "id": str(country["_id"]),
            "code": country["code"],
            "name": country["name"],
            "currency": country["currency"],
            "timezone": country["timezone"],
            "languages": country["languages"],
            "payment_methods": country["payment_methods"],
            "is_active": country["is_active"],
        }