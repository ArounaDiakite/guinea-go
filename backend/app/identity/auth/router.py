from fastapi import APIRouter, Depends
from fastapi.security import OAuth2PasswordRequestForm

from app.identity.auth.schemas import RegisterRequest, LoginRequest, TokenResponse
from app.identity.auth.service import AuthService

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)

service = AuthService()


@router.get("/")
async def home():
    return {
        "module": "Authentication",
        "status": "Working"
    }


@router.post("/register", response_model=TokenResponse)
async def register(data: RegisterRequest):
    return await service.register(data)


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