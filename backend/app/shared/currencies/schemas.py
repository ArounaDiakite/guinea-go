from pydantic import BaseModel


class CurrencyCreate(BaseModel):
    code: str
    name: str
    symbol: str
    is_active: bool = True


class CurrencyResponse(CurrencyCreate):
    id: str