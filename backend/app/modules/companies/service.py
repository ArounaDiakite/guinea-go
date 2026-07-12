import shutil
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile

from app.common.base_model import BaseDocument
from app.modules.companies.repository import CompanyRepository
from app.modules.companies.schemas import CompanyCreate


class CompanyService:
    def __init__(self):
        self.repository = CompanyRepository()

    async def create_company(self, data: CompanyCreate, owner_id: str):
        company = data.model_dump()

        company["company_type"] = company["company_type"].value
        company.update(BaseDocument.create())

        company["owner_id"] = owner_id
        company["is_verified"] = False
        company["logo_url"] = None

        company = await self.repository.create(company)

        return self._format(company)

    async def get_companies(
        self,
        page: int,
        limit: int,
        search: str | None,
        company_type: str | None,
        city: str | None,
    ):
        companies = await self.repository.get_all(
            page,
            limit,
            search,
            company_type,
            city,
        )

        return [self._format(company) for company in companies]

    async def get_company(self, company_id: str):
        company = await self.repository.get_by_id(company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        return self._format(company)

    async def update_company(
        self,
        company_id: str,
        data: CompanyCreate,
        user_id: str,
    ):
        company = await self.repository.get_by_id(company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        data_to_update = data.model_dump()

        data_to_update["company_type"] = data_to_update["company_type"].value
        data_to_update.update(BaseDocument.update())

        company = await self.repository.update(
            company_id,
            data_to_update,
        )

        return self._format(company)

    async def delete_company(
        self,
        company_id: str,
        user_id: str,
    ):
        company = await self.repository.get_by_id(company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        deleted = await self.repository.soft_delete(
            company_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        return {
            "message": "Company deleted successfully."
        }

    async def upload_logo(
        self,
        company_id: str,
        user_id: str,
        file: UploadFile,
    ):
        company = await self.repository.get_by_id(company_id)

        if not company:
            raise HTTPException(
                status_code=404,
                detail="Company not found.",
            )

        if company["owner_id"] != user_id:
            raise HTTPException(
                status_code=403,
                detail="Not allowed.",
            )

        allowed_extensions = {
            "jpg",
            "jpeg",
            "png",
            "webp",
        }

        allowed_content_types = {
            "image/jpeg",
            "image/png",
            "image/webp",
        }

        max_size = 5 * 1024 * 1024  # 5 MB

        extension = file.filename.split(".")[-1].lower()

        if extension not in allowed_extensions:
            raise HTTPException(
                status_code=400,
                detail="Only JPG, JPEG, PNG and WEBP images are allowed.",
            )

        if file.content_type not in allowed_content_types:
            raise HTTPException(
                status_code=400,
                detail="Invalid image type.",
            )

        file.file.seek(0, 2)
        size = file.file.tell()
        file.file.seek(0)

        if size > max_size:
            raise HTTPException(
                status_code=400,
                detail="Image must be smaller than 5 MB.",
            )

        upload_dir = Path("uploads/logos")
        upload_dir.mkdir(parents=True, exist_ok=True)

        filename = f"{uuid4()}.{extension}"

        filepath = upload_dir / filename

        with filepath.open("wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        logo_url = f"/uploads/logos/{filename}"

        company = await self.repository.update(
            company_id,
            {
                "logo_url": logo_url,
                "updated_at": BaseDocument.update()["updated_at"],
            },
        )

        return self._format(company)

    def _format(self, company):
        return {
            "id": str(company["_id"]),
            "name": company["name"],
            "company_type": company["company_type"],
            "description": company.get("description"),
            "phone": company["phone"],
            "email": company["email"],
            "website": company.get("website"),
            "logo_url": company.get("logo_url"),
            "country_code": company["country_code"],
            "city": company["city"],
            "address": company["address"],
            "owner_id": company["owner_id"],
            "is_verified": company["is_verified"],
            "is_active": company["is_active"],
            "created_at": company.get("created_at"),
            "updated_at": company.get("updated_at"),
        }