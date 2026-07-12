from pydantic import BaseModel


class LanguageCreate(BaseModel):
    code: str
    name: str
    native_name: str
    is_active: bool = True


class LanguageResponse(LanguageCreate):
    id: str