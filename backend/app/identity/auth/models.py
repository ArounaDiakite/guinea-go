from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

from app.core.constants import UserRole
from app.core.utils import utc_now


class User(BaseModel):
    first_name: str
    last_name: str

    email: EmailStr

    phone: str

    password: str

    city: str
    country: str = "Guinea"

    role: UserRole = UserRole.PASSENGER

    is_active: bool = True

    created_at: datetime = Field(default_factory=utc_now)