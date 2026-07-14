from fastapi import HTTPException

from app.shared.cities.repository import CityRepository
from app.shared.countries.repository import CountryRepository
from app.shared.currencies.repository import CurrencyRepository


class LocationResolver:
    """Shared by every business module that references shared/countries,
    shared/cities and shared/currencies instead of free text (Company/
    Station/Route in transport, and the same shape again in hotels/
    events/commerce/education) - avoids re-implementing the same
    resolve-country / resolve-city / resolve-or-inherit-currency checks
    five times.

    City still keys off Country by country_code (shared/cities' own
    schema - untouched here), not country_id, so resolve_city cross-
    checks by code rather than comparing ids directly.
    """

    def __init__(self):
        self.country_repository = CountryRepository()
        self.city_repository = CityRepository()
        self.currency_repository = CurrencyRepository()

    async def resolve_country(self, country_id: str) -> dict:
        country = await self.country_repository.get_by_id(country_id)

        if not country:
            raise HTTPException(status_code=400, detail="Country not found.")

        return country

    async def resolve_city(self, city_id: str, country: dict) -> dict:
        city = await self.city_repository.get_by_id(city_id)

        if not city:
            raise HTTPException(status_code=400, detail="City not found.")

        if city["country_code"] != country["code"]:
            raise HTTPException(
                status_code=400,
                detail="City does not belong to the given country.",
            )

        return city

    async def resolve_currency(self, currency_id: str | None, country: dict) -> str:
        """Explicit currency_id if given (validated to exist); otherwise
        inherits the country's own currency, so callers don't have to
        specify it when it's derivable from the parent resource."""
        if currency_id is None:
            return country["currency_id"]

        currency = await self.currency_repository.get_by_id(currency_id)

        if not currency:
            raise HTTPException(status_code=400, detail="Currency not found.")

        return currency_id
