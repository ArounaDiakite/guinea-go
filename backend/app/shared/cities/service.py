from fastapi import HTTPException

from app.shared.cities.repository import CityRepository
from app.shared.cities.schemas import CityCreate


class CityService:
    def __init__(self):
        self.repository = CityRepository()

    async def create_city(self, data: CityCreate):
        city = await self.repository.get_city(
            data.country_code,
            data.name,
        )

        if city:
            raise HTTPException(
                status_code=400,
                detail="City already exists."
            )

        city_data = data.model_dump()

        city_data["country_code"] = data.country_code.upper()

        city = await self.repository.create_city(city_data)

        return self._format(city)

    async def get_all(self):
        cities = await self.repository.get_all()
        return [self._format(city) for city in cities]

    async def get_by_country(self, country_code: str):
        cities = await self.repository.get_by_country(country_code)
        return [self._format(city) for city in cities]

    def _format(self, city):
        return {
            "id": str(city["_id"]),
            "country_code": city["country_code"],
            "name": city["name"],
            "state_or_region": city["state_or_region"],
            "latitude": city.get("latitude"),
            "longitude": city.get("longitude"),
            "is_active": city["is_active"],
        }