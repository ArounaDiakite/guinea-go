from collections import defaultdict
from datetime import timedelta

from bson import ObjectId
from fastapi import HTTPException, status

from app.common.base_model import BaseDocument
from app.core.config import settings
from app.core.permissions import ensure_owner
from app.core.utils import utc_now
from app.modules.commerce.cart.repository import CartRepository
from app.modules.commerce.orders.repository import OrderRepository
from app.modules.commerce.products.repository import ProductRepository
from app.modules.commerce.stores.repository import StoreRepository


class InsufficientStockException(HTTPException):
    def __init__(self, product_name: str):
        super().__init__(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Not enough stock available for '{product_name}'.",
        )


class OrderService:
    def __init__(self):
        self.repository = OrderRepository()
        self.product_repository = ProductRepository()
        self.cart_repository = CartRepository()
        self.store_repository = StoreRepository()

    async def checkout(self, customer_id: str):
        # Release any abandoned PENDING_PAYMENT orders' stock before
        # attempting new claims - same lazy-expiration approach as every
        # other booking flow, just an unscoped sweep here (see
        # get_stale_pending_orders for why).
        await self.expire_stale_orders()

        cart = await self.cart_repository.get_or_create(customer_id)

        if not cart["items"]:
            raise HTTPException(status_code=400, detail="Your cart is empty.")

        resolved_items = []
        for item in cart["items"]:
            product = await self.product_repository.get_by_id(item["product_id"])
            if not product:
                continue
            if not product["is_active"]:
                continue
            resolved_items.append((product, item["quantity"]))

        if not resolved_items:
            raise HTTPException(
                status_code=400,
                detail="Your cart has no items available to check out.",
            )

        # Claim stock atomically for every item across the whole cart,
        # store boundaries included. If any single claim fails, roll back
        # everything already claimed in this attempt and abort the whole
        # checkout - no partial orders, no silently-half-checked-out cart.
        claimed: list[tuple[str, int]] = []
        try:
            for product, quantity in resolved_items:
                product_id = str(product["_id"])
                ok = await self.product_repository.claim_stock(product_id, quantity)

                if not ok:
                    raise InsufficientStockException(product["name"])

                claimed.append((product_id, quantity))
        except InsufficientStockException:
            for product_id, quantity in claimed:
                await self.product_repository.release_stock(product_id, quantity)
            raise

        # Group by store: one Order per store, prices frozen from the
        # product data already fetched above.
        by_store = defaultdict(list)
        for product, quantity in resolved_items:
            by_store[product["store_id"]].append((product, quantity))

        now = utc_now()
        created_orders = []

        try:
            for store_id, items in by_store.items():
                order_items = []
                total = 0.0

                for product, quantity in items:
                    subtotal = round(product["price"] * quantity, 2)
                    total += subtotal
                    order_items.append(
                        {
                            "product_id": str(product["_id"]),
                            "product_name": product["name"],
                            "unit_price": product["price"],
                            "quantity": quantity,
                            "subtotal": subtotal,
                        }
                    )

                order_doc = {
                    "_id": ObjectId(),
                    "store_id": store_id,
                    "customer_id": customer_id,
                    "items": order_items,
                    "total": round(total, 2),
                    "status": "PENDING_PAYMENT",
                    "expires_at": now + timedelta(minutes=settings.BOOKING_PAYMENT_TIMEOUT_MINUTES),
                }
                order_doc.update(BaseDocument.create())

                order = await self.repository.create(order_doc)
                created_orders.append(order)
        except Exception:
            # Roll back every stock claim from this attempt and delete any
            # orders it did manage to insert before the failure.
            for product_id, quantity in claimed:
                await self.product_repository.release_stock(product_id, quantity)
            for order in created_orders:
                await self.repository.delete(str(order["_id"]))
            raise

        # Success: drop the ordered items from the cart, leave anything
        # that wasn't part of this checkout (e.g. an inactive product that
        # got silently skipped above) for the customer to deal with.
        ordered_product_ids = {product_id for product_id, _ in claimed}
        remaining_items = [
            item for item in cart["items"] if item["product_id"] not in ordered_product_ids
        ]
        await self.cart_repository.replace_items(cart["_id"], remaining_items)

        return [self._format(order) for order in created_orders]

    async def get_order(self, order_id: str, customer_id: str):
        order = await self.repository.get_by_id(order_id)

        if not order:
            raise HTTPException(status_code=404, detail="Order not found.")

        if order["customer_id"] != customer_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        return self._format(order)

    async def cancel_order(self, order_id: str, customer_id: str):
        order = await self.repository.get_by_id(order_id)

        if not order:
            raise HTTPException(status_code=404, detail="Order not found.")

        if order["customer_id"] != customer_id:
            raise HTTPException(status_code=403, detail="Not allowed.")

        if order["status"] in ("CANCELLED", "EXPIRED"):
            raise HTTPException(
                status_code=400,
                detail=f"Order is already {order['status'].lower()}.",
            )

        cancelled = await self.repository.transition_status_if(
            order_id,
            ["PENDING_PAYMENT", "CONFIRMED"],
            {"status": "CANCELLED", **BaseDocument.update()},
        )

        if not cancelled:
            raise HTTPException(status_code=400, detail="Order is already cancelled or expired.")

        for item in order["items"]:
            await self.product_repository.release_stock(item["product_id"], item["quantity"])

        return self._format(await self.repository.get_by_id(order_id))

    async def expire_stale_orders(self):
        stale_orders = await self.repository.get_stale_pending_orders(utc_now())

        for order in stale_orders:
            order_id = str(order["_id"])

            expired = await self.repository.transition_status_if(
                order_id,
                "PENDING_PAYMENT",
                {"status": "EXPIRED", **BaseDocument.update()},
            )

            if not expired:
                continue

            for item in order["items"]:
                await self.product_repository.release_stock(item["product_id"], item["quantity"])

    async def get_my_orders(self, customer_id: str, page: int, limit: int):
        orders = await self.repository.get_by_customer(customer_id, page, limit)
        return [self._format(order) for order in orders]

    async def get_orders_for_store(self, store_id: str, page: int, limit: int, user_id: str):
        store = await self.store_repository.get_by_id(store_id)

        if not store:
            raise HTTPException(status_code=404, detail="Store not found.")

        ensure_owner(store["owner_id"], user_id)

        orders = await self.repository.get_by_store(store_id, page, limit)
        return [self._format(order) for order in orders]

    def _format(self, order):
        return {
            "id": str(order["_id"]),
            "store_id": order["store_id"],
            "customer_id": order["customer_id"],
            "items": order["items"],
            "total": order["total"],
            "status": order["status"],
            "expires_at": order.get("expires_at"),
            "created_at": order.get("created_at"),
            "updated_at": order.get("updated_at"),
        }
