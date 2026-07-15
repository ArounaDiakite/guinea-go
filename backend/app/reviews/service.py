from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.database.mongodb import db
from app.reviews.repository import ReviewRepository
from app.reviews.schemas import ReviewCreate, ReviewUpdate

_ALREADY_REVIEWED_MESSAGE = (
    "You've already reviewed this. Use PUT /reviews/{id} to update it instead."
)


class ConsumptionVerifier:
    """The anti-fake-review gate: confirms a user actually has a
    CONFIRMED booking/order for whatever they're trying to review
    before POST /reviews accepts it. Reaches into other modules'
    collections directly (bookings, hotel_bookings, event_bookings,
    orders, trips) rather than importing five repository classes for
    one narrow existence query each - this is a transversal, read-only
    concern that belongs centralized here, not scattered as one-off
    methods across otherwise-unrelated repositories."""

    async def has_consumed(self, target_type: str, target_id: str, user_id: str) -> bool:
        checker = self._CHECKERS.get(target_type)

        if checker is None:
            return False

        return await checker(self, target_id, user_id)

    async def _trip(self, target_id: str, user_id: str) -> bool:
        booking = await db.bookings.find_one({
            "trip_id": target_id,
            "passenger_id": user_id,
            "status": "CONFIRMED",
        })
        return booking is not None

    async def _hotel(self, target_id: str, user_id: str) -> bool:
        booking = await db.hotel_bookings.find_one({
            "hotel_id": target_id,
            "passenger_id": user_id,
            "status": "CONFIRMED",
        })
        return booking is not None

    async def _room(self, target_id: str, user_id: str) -> bool:
        booking = await db.hotel_bookings.find_one({
            "room_id": target_id,
            "passenger_id": user_id,
            "status": "CONFIRMED",
        })
        return booking is not None

    async def _event(self, target_id: str, user_id: str) -> bool:
        booking = await db.event_bookings.find_one({
            "event_id": target_id,
            "passenger_id": user_id,
            "status": "CONFIRMED",
        })
        return booking is not None

    async def _product(self, target_id: str, user_id: str) -> bool:
        order = await db.orders.find_one({
            "customer_id": user_id,
            "status": "CONFIRMED",
            "items.product_id": target_id,
        })
        return order is not None

    async def _store(self, target_id: str, user_id: str) -> bool:
        order = await db.orders.find_one({
            "store_id": target_id,
            "customer_id": user_id,
            "status": "CONFIRMED",
        })
        return order is not None

    async def _company(self, target_id: str, user_id: str) -> bool:
        # Booking has no company_id of its own - resolved transitively
        # through the trips that belong to this company.
        trip_ids = [
            str(trip["_id"])
            async for trip in db.trips.find({"company_id": target_id}, {"_id": 1})
        ]

        if not trip_ids:
            return False

        booking = await db.bookings.find_one({
            "trip_id": {"$in": trip_ids},
            "passenger_id": user_id,
            "status": "CONFIRMED",
        })
        return booking is not None

    _CHECKERS = {
        "trip": _trip,
        "hotel": _hotel,
        "room": _room,
        "event": _event,
        "product": _product,
        "store": _store,
        "company": _company,
    }


class ReviewService:
    def __init__(self):
        self.repository = ReviewRepository()
        self.verifier = ConsumptionVerifier()

    async def create_review(self, data: ReviewCreate, author_id: str):
        consumed = await self.verifier.has_consumed(
            data.target_type.value, data.target_id, author_id
        )

        if not consumed:
            raise HTTPException(
                status_code=400,
                detail=(
                    "You can only review something you have a confirmed "
                    "booking or order for."
                ),
            )

        # Advisory check for a clean error in the common case; the unique
        # index on (author_id, target_type, target_id) (database/
        # indexes.py) is what actually guarantees no duplicate under a
        # genuine double-submit race.
        existing = await self.repository.get_by_author_and_target(
            author_id, data.target_type.value, data.target_id
        )

        if existing:
            raise HTTPException(status_code=409, detail=_ALREADY_REVIEWED_MESSAGE)

        review = data.model_dump()
        review["target_type"] = review["target_type"].value
        review["author_id"] = author_id
        review.update(BaseDocument.create())

        try:
            review = await self.repository.create(review)
        except DuplicateKeyError:
            raise HTTPException(status_code=409, detail=_ALREADY_REVIEWED_MESSAGE)

        return self._format(review)

    async def get_reviews(self, target_type: str, target_id: str):
        reviews = await self.repository.get_by_target(target_type, target_id)

        ratings = [review["rating"] for review in reviews]
        average = round(sum(ratings) / len(ratings), 2) if ratings else None

        return {
            "target_type": target_type,
            "target_id": target_id,
            "average_rating": average,
            "count": len(reviews),
            "reviews": [self._format(review) for review in reviews],
        }

    async def get_review(self, review_id: str):
        review = await self.repository.get_by_id(review_id)

        if not review:
            raise HTTPException(status_code=404, detail="Review not found.")

        return self._format(review)

    async def update_review(self, review_id: str, data: ReviewUpdate, user_id: str):
        review = await self.repository.get_by_id(review_id)

        if not review:
            raise HTTPException(status_code=404, detail="Review not found.")

        ensure_owner(review["author_id"], user_id)

        update_data = data.model_dump()
        update_data.update(BaseDocument.update())

        updated = await self.repository.update(review_id, update_data)
        return self._format(updated)

    async def delete_review(self, review_id: str, user_id: str):
        review = await self.repository.get_by_id(review_id)

        if not review:
            raise HTTPException(status_code=404, detail="Review not found.")

        ensure_owner(review["author_id"], user_id)

        deleted = await self.repository.soft_delete(
            review_id,
            {
                "is_deleted": True,
                "is_active": False,
                "deleted_at": BaseDocument.update()["updated_at"],
            },
        )

        if not deleted:
            raise HTTPException(status_code=404, detail="Review not found.")

        return {"message": "Review deleted successfully."}

    def _format(self, review):
        return {
            "id": str(review["_id"]),
            "author_id": review["author_id"],
            "target_type": review["target_type"],
            "target_id": review["target_id"],
            "rating": review["rating"],
            "comment": review.get("comment"),
            "created_at": review.get("created_at"),
            "updated_at": review.get("updated_at"),
        }
