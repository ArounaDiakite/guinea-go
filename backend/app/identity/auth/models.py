from enum import Enum
from datetime import datetime
from pydantic import BaseModel, EmailStr, Field


class UserRole(str, Enum):
    ADMIN = "admin"
    CUSTOMER = "customer"
    COMPANY = "company"


class User(BaseModel):
    first_name: str
    last_name: str

    email: EmailStr

    phone: str

    password: str

    city: str
    country: str = "Guinea"

    role: UserRole = UserRole.CUSTOMER

    is_active: bool = True

    created_at: datetime = Field(default_factory=datetime.utcnow)