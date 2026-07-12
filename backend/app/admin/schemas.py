from datetime import datetime

from pydantic import BaseModel, EmailStr


class AdminUserResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: EmailStr
    phone: str
    role: str
    city: str
    country_code: str
    is_active: bool
    created_at: datetime
