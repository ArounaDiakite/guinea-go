from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from enum import Enum


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

    country: str = "Guinea"
    city: str

    profile_image: Optional[str] = None

    role: UserRole = UserRole.CUSTOMER

    is_active: bool = True

    created_at: datetime = Field(default_factory=datetime.utcnow)