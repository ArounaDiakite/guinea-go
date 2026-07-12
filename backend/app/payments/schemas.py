from pydantic import BaseModel


class PaymentProviderCreate(BaseModel):
    code: str
    name: str
    provider_type: str
    country_code: str
    is_active: bool = True


class PaymentProviderResponse(PaymentProviderCreate):
    id: str
