from fastapi import HTTPException

from app.modules.commerce.cart.repository import CartRepository
from app.modules.commerce.cart.schemas import AddCartItemRequest, UpdateCartItemRequest
from app.modules.commerce.products.repository import ProductRepository
from app.modules.commerce.stores.repository import StoreRepository


class CartService:
    def __init__(self):
        self.repository = CartRepository()
        self.product_repository = ProductRepository()
        self.store_repository = StoreRepository()

    async def get_cart(self, customer_id: str):
        cart = await self.repository.get_or_create(customer_id)
        return await self._format(cart)

    async def add_item(self, customer_id: str, data: AddCartItemRequest):
        product = await self.product_repository.get_by_id(data.product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found.")

        if not product["is_active"]:
            raise HTTPException(status_code=400, detail="This product is not available.")

        cart = await self.repository.get_or_create(customer_id)
        items = cart["items"]

        existing = next((i for i in items if i["product_id"] == data.product_id), None)
        new_quantity = data.quantity + (existing["quantity"] if existing else 0)

        # Simple check only - not a reservation. The real atomic stock
        # lock happens at checkout (separate, later step); this just
        # stops a cart from claiming to hold more than currently exists.
        if new_quantity > product["stock"]:
            raise HTTPException(
                status_code=400,
                detail=f"Only {product['stock']} unit(s) of this product are in stock.",
            )

        if existing:
            existing["quantity"] = new_quantity
        else:
            items.append({"product_id": data.product_id, "quantity": data.quantity})

        updated_cart = await self.repository.replace_items(cart["_id"], items)
        return await self._format(updated_cart)

    async def update_item_quantity(self, customer_id: str, product_id: str, data: UpdateCartItemRequest):
        product = await self.product_repository.get_by_id(product_id)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found.")

        if data.quantity > product["stock"]:
            raise HTTPException(
                status_code=400,
                detail=f"Only {product['stock']} unit(s) of this product are in stock.",
            )

        cart = await self.repository.get_or_create(customer_id)
        items = cart["items"]

        item = next((i for i in items if i["product_id"] == product_id), None)

        if not item:
            raise HTTPException(status_code=404, detail="This product is not in your cart.")

        item["quantity"] = data.quantity

        updated_cart = await self.repository.replace_items(cart["_id"], items)
        return await self._format(updated_cart)

    async def remove_item(self, customer_id: str, product_id: str):
        cart = await self.repository.get_or_create(customer_id)
        items = [i for i in cart["items"] if i["product_id"] != product_id]

        updated_cart = await self.repository.replace_items(cart["_id"], items)
        return await self._format(updated_cart)

    async def clear_cart(self, customer_id: str):
        cart = await self.repository.get_or_create(customer_id)
        updated_cart = await self.repository.replace_items(cart["_id"], [])
        return await self._format(updated_cart)

    async def _format(self, cart):
        item_responses = []
        total = 0.0
        # Several items commonly share a store - cache resolved names
        # within this one format() call instead of re-fetching per item.
        store_name_cache: dict[str, str] = {}

        for item in cart["items"]:
            product = await self.product_repository.get_by_id(item["product_id"])

            if not product:
                # Product was deleted after being added to the cart -
                # skip it rather than error the whole cart out.
                continue

            store_id = product["store_id"]

            if store_id not in store_name_cache:
                store = await self.store_repository.get_by_id(store_id)
                if not store:
                    # Same reasoning as a deleted product - skip rather
                    # than error the whole cart out.
                    continue
                store_name_cache[store_id] = store["name"]

            subtotal = round(product["price"] * item["quantity"], 2)
            total += subtotal

            item_responses.append(
                {
                    "product_id": item["product_id"],
                    "product_name": product["name"],
                    "store_id": store_id,
                    "store_name": store_name_cache[store_id],
                    "unit_price": product["price"],
                    "quantity": item["quantity"],
                    "subtotal": subtotal,
                }
            )

        return {
            "id": str(cart["_id"]),
            "customer_id": cart["customer_id"],
            "items": item_responses,
            "total": round(total, 2),
            "created_at": cart.get("created_at"),
            "updated_at": cart.get("updated_at"),
        }
