from pydantic import BaseModel


class CityCreate(BaseModel):
    country_code: str
    name: str
    state_or_region: str
    latitude: float | None = None
    longitude: float | None = None
    is_active: bool = True


class CityResponse(CityCreate):
    id: str