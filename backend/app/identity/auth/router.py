from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm

from app.identity.auth.schemas import (
    LoginRequest,
    PartnerRegisterResponse,
    RegisterPartnerRequest,
    RegisterRequest,
    TokenResponse,
)
from app.identity.auth.service import AuthService
from app.modules.education.institutions.schemas import (
    InstitutionAccountCreate,
    InstitutionWithAccountResponse,
)
from app.modules.education.institutions.service import InstitutionService
from app.modules.education.school_members.schemas import (
    SchoolMemberRegisterRequest,
    SchoolMemberRegisterResponse,
)
from app.modules.education.school_members.service import SchoolMemberService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)

service = AuthService()
institution_service = InstitutionService()
school_member_service = SchoolMemberService()


@router.get("/")
async def home():
    return {
        "module": "Authentication",
        "status": "Working"
    }


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest):
    return await service.register(data)


@router.post("/register-partner", response_model=PartnerRegisterResponse)
async def register_partner(data: RegisterPartnerRequest):
    return await service.register_partner(data)


@router.post("/register-institution", response_model=InstitutionWithAccountResponse)
async def register_institution(data: InstitutionAccountCreate):
    return await institution_service.register_private_institution(data)


@router.post("/register-school-member", response_model=SchoolMemberRegisterResponse)
async def register_school_member(data: SchoolMemberRegisterRequest):
    return await school_member_service.register(data)


@router.post("/login", response_model=TokenResponse)
async def login(data: LoginRequest):
    return await service.login(data)


@router.post("/token", response_model=TokenResponse)
async def token_login(form_data: OAuth2PasswordRequestForm = Depends()):
    data = LoginRequest(
        email=form_data.username,
        password=form_data.password
    )
    return await service.login(data)