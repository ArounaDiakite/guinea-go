from pydantic import BaseModel, EmailStr, field_validator

from app.core.constants import PARTNER_ROLES, UserRole


class RegisterRequest(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    phone: str
    password: str
    city: str
    country_code: str = "GN"
    preferred_language: str = "fr"


class RegisterPartnerRequest(RegisterRequest):
    role: UserRole

    @field_validator("role")
    @classmethod
    def role_must_be_a_partner_role(cls, value: UserRole) -> UserRole:
        if value not in PARTNER_ROLES:
            allowed = ", ".join(role.value for role in PARTNER_ROLES)
            raise ValueError(f"role must be one of: {allowed}")
        return value


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: EmailStr
    phone: str
    city: str
    country_code: str
    preferred_language: str
    role: str
    is_active: bool


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class PartnerRegisterResponse(BaseModel):
    message: str
    user: UserResponse