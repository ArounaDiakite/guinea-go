from pydantic import BaseModel

from app.identity.auth.schemas import RegisterRequest, UserResponse


class SchoolMemberRegisterRequest(RegisterRequest):
    invite_code: str


class SchoolMemberRegisterResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
    profile_id: str
