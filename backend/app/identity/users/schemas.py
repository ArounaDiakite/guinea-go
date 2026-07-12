from pydantic import BaseModel, EmailStr


class UserProfileResponse(BaseModel):
    id: str
    first_name: str
    last_name: str
    email: EmailStr
    phone: str
    city: str
    country_code: str
    preferred_language: str = "fr"
    role: str
    is_verified: bool
    is_active: bool


class UpdateProfileRequest(BaseModel):
    first_name: str
    last_name: str
    phone: str
    city: str
    country_code: str
    preferred_language: str = "fr"


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str