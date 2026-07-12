from fastapi import UploadFile, File
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.modules.companies.schemas import CompanyCreate, CompanyResponse
from app.modules.companies.service import CompanyService
from app.core.constants import UserRole
from app.core.dependencies import get_current_user, require_role
from app.identity.auth.schemas import RegisterRequest, UserResponse
from app.identity.auth.service import AuthService

auth_service = AuthService()

router = APIRouter(
    prefix="/companies",
    tags=["Companies"],
)

service = CompanyService()


@router.post("/", response_model=CompanyResponse)
async def create_company(
    data: CompanyCreate,
    current_user=Depends(get_current_user),
):
    return await service.create_company(data, current_user["sub"])


@router.get("/", response_model=list[CompanyResponse])
async def get_companies(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: Optional[str] = None,
    company_type: Optional[str] = None,
    city: Optional[str] = None,
):
    return await service.get_companies(page, limit, search, company_type, city)


@router.get("/{company_id}", response_model=CompanyResponse)
async def get_company(company_id: str):
    return await service.get_company(company_id)


@router.put("/{company_id}", response_model=CompanyResponse)
async def update_company(
    company_id: str,
    data: CompanyCreate,
    current_user=Depends(get_current_user),
):
    return await service.update_company(company_id, data, current_user["sub"])


@router.delete("/{company_id}")
async def delete_company(
    company_id: str,
    current_user=Depends(get_current_user),
):
    return await service.delete_company(company_id, current_user["sub"])
@router.post("/{company_id}/logo", response_model=CompanyResponse)
async def upload_company_logo(
    company_id: str,
    file: UploadFile = File(...),
    current_user=Depends(get_current_user),
):
    return await service.upload_logo(company_id, current_user["sub"], file)


@router.post("/{company_id}/drivers", response_model=UserResponse)
async def create_driver(
    company_id: str,
    data: RegisterRequest,
    current_user=Depends(require_role(UserRole.COMPANY_OWNER)),
):
    company = await service.get_company(company_id)

    if company["owner_id"] != current_user["sub"]:
        raise HTTPException(
            status_code=403,
            detail="Not allowed.",
        )

    return await auth_service.register_driver(company_id, data)