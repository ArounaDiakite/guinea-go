from pydantic import BaseModel
from typing import List


class CountryCreate(BaseModel):
    code: str
    name: str
    currency: str
    timezone: str
    languages: List[str]
    payment_methods: List[str]
    is_active: bool = True


class CountryResponse(CountryCreate):
    id: str