from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.modules.commerce.products.repository import ProductRepository
from app.modules.commerce.products.schemas import ProductCreate
from app.modules.commerce.stores.repository import StoreRepository


class ProductService:
    def __init__(self):
        self.repository = ProductRepository()
        self.store_repository = StoreRepository()

    async def create_product(self, data: ProductCreate, user_id: str):
        store = await self.store_repository.get_by_id(data.store_id)

        if not store:
            raise HTTPException(status_code=404, detail="Store not found.")

        ensure_owner(store["owner_id"], user_id)

        product = data.model_dump()
        product.update(BaseDocument.create())
        # BaseDocument.create() always sets is_active=True - let the
        # creator's explicit choice win (e.g. adding a product before
        # it's ready to be listed).
        product["is_active"] = data.is_active

        product = await self.repository.create(product)
        return self._format(product)

    async def get_products(
        self,
        page: int,
        limit: int,
        search: str | None,
        category_id: str | None,
        store_id: str | None,
    ):
        products = await self.repository.get_all(page, limit, search, category_id, store_id)
        return [self._format(product) for product in products]

    async def get_product(self, product_id: str):
        product = await self.repository.get_by_id(product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found.")

        return self._format(product)

    async def update_product(self, product_id: str, data: ProductCreate, user_id: str):
        product = await self.repository.get_by_id(product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found.")

        store = await self.store_repository.get_by_id(product["store_id"])

        if not store:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(store["owner_id"], user_id)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(product_id, update_data)
        return self._format(updated)

    async def delete_product(self, product_id: str, user_id: str):
        product = await self.repository.get_by_id(product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found.")

        store = await self.store_repository.get_by_id(product["store_id"])

        if not store:
            raise HTTPException(status_code=403, detail="Not allowed.")

        ensure_owner(store["owner_id"], user_id)

        deleted = await self.repository.soft_delete(
            product_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Product not found.")

        return {"message": "Product deleted successfully."}

    def _format(self, product):
        return {
            "id": str(product["_id"]),
            "store_id": product["store_id"],
            "name": product["name"],
            "description": product.get("description"),
            "price": product["price"],
            "category_ids": product.get("category_ids", []),
            "images": product.get("images", []),
            "stock": product["stock"],
            "is_active": product["is_active"],
            "created_at": product.get("created_at"),
            "updated_at": product.get("updated_at"),
        }
