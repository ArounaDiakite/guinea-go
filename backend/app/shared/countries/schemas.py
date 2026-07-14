from pydantic import BaseModel
from typing import List


class CountryCreate(BaseModel):
    code: str
    name: str
    # Human-friendly input (e.g. "GNF") - the service resolves this to
    # an existing Currency document and stores currency_id, not this
    # code, on the Country record. 400s if no such currency exists yet
    # (seed/create it first via POST /currencies).
    currency_code: str
    timezone: str
    languages: List[str]
    payment_methods: List[str]
    is_active: bool = True


class CountryResponse(BaseModel):
    id: str
    code: str
    name: str
    currency_id: str
    timezone: str
    languages: List[str]
    payment_methods: List[str]
    is_active: bool
