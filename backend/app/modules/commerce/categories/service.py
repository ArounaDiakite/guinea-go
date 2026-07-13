from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.modules.commerce.categories.repository import CategoryRepository
from app.modules.commerce.categories.schemas import CategoryCreate


class CategoryService:
    def __init__(self):
        self.repository = CategoryRepository()

    async def create_category(self, data: CategoryCreate):
        if data.category_parent_id:
            parent = await self.repository.get_by_id(data.category_parent_id)

            if not parent:
                raise HTTPException(status_code=404, detail="Parent category not found.")

        category = data.model_dump()
        category.update(BaseDocument.create())

        category = await self.repository.create(category)
        return self._format(category)

    async def get_categories(self, page: int, limit: int, search: str | None, category_parent_id: str | None):
        categories = await self.repository.get_all(page, limit, search, category_parent_id)
        return [self._format(category) for category in categories]

    async def get_category(self, category_id: str):
        category = await self.repository.get_by_id(category_id)

        if not category:
            raise HTTPException(status_code=404, detail="Category not found.")

        return self._format(category)

    async def update_category(self, category_id: str, data: CategoryCreate):
        category = await self.repository.get_by_id(category_id)

        if not category:
            raise HTTPException(status_code=404, detail="Category not found.")

        if data.category_parent_id:
            if data.category_parent_id == category_id:
                raise HTTPException(status_code=400, detail="A category cannot be its own parent.")

            parent = await self.repository.get_by_id(data.category_parent_id)

            if not parent:
                raise HTTPException(status_code=404, detail="Parent category not found.")

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        category = await self.repository.update(category_id, update_data)
        return self._format(category)

    async def delete_category(self, category_id: str):
        category = await self.repository.get_by_id(category_id)

        if not category:
            raise HTTPException(status_code=404, detail="Category not found.")

        deleted = await self.repository.soft_delete(
            category_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Category not found.")

        return {"message": "Category deleted successfully."}

    def _format(self, category):
        return {
            "id": str(category["_id"]),
            "name": category["name"],
            "description": category.get("description"),
            "category_parent_id": category.get("category_parent_id"),
            "is_active": category["is_active"],
            "created_at": category.get("created_at"),
            "updated_at": category.get("updated_at"),
        }
