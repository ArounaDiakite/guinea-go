from bson import ObjectId
from fastapi import HTTPException
from pymongo.errors import DuplicateKeyError

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.database.mongodb import db
from app.notifications.service import NotificationService
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


class TargetOwnerResolver:
    """Resolves which user should be notified about a new review on a
    given target - the resource's own owner (company_owner/hotel_owner/
    event_organizer/store_manager). Same dispatch-by-target_type shape
    and same reasoning as ConsumptionVerifier above (raw collection
    reads, not five more repository imports for one narrow lookup
    each). Returns None rather than raising when a target/its parent
    can't be resolved (deleted target, malformed id, unknown
    target_type) - a notification failure shouldn't block the review
    itself from being created."""

    async def resolve_owner(self, target_type: str, target_id: str) -> str | None:
        if not ObjectId.is_valid(target_id):
            return None

        resolver = self._RESOLVERS.get(target_type)

        if resolver is None:
            return None

        return await resolver(self, target_id)

    async def _trip(self, target_id: str) -> str | None:
        trip = await db.trips.find_one({"_id": ObjectId(target_id)})

        if not trip or not ObjectId.is_valid(trip.get("company_id", "")):
            return None

        company = await db.companies.find_one({"_id": ObjectId(trip["company_id"])})
        return company["owner_id"] if company else None

    async def _hotel(self, target_id: str) -> str | None:
        hotel = await db.hotels.find_one({"_id": ObjectId(target_id)})
        return hotel["owner_id"] if hotel else None

    async def _room(self, target_id: str) -> str | None:
        room = await db.rooms.find_one({"_id": ObjectId(target_id)})

        if not room or not ObjectId.is_valid(room.get("hotel_id", "")):
            return None

        hotel = await db.hotels.find_one({"_id": ObjectId(room["hotel_id"])})
        return hotel["owner_id"] if hotel else None

    async def _event(self, target_id: str) -> str | None:
        event = await db.events.find_one({"_id": ObjectId(target_id)})
        return event["organizer_id"] if event else None

    async def _product(self, target_id: str) -> str | None:
        product = await db.products.find_one({"_id": ObjectId(target_id)})

        if not product or not ObjectId.is_valid(product.get("store_id", "")):
            return None

        store = await db.stores.find_one({"_id": ObjectId(product["store_id"])})
        return store["owner_id"] if store else None

    async def _store(self, target_id: str) -> str | None:
        store = await db.stores.find_one({"_id": ObjectId(target_id)})
        return store["owner_id"] if store else None

    async def _company(self, target_id: str) -> str | None:
        company = await db.companies.find_one({"_id": ObjectId(target_id)})
        return company["owner_id"] if company else None

    _RESOLVERS = {
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
        self.owner_resolver = TargetOwnerResolver()
        self.notification_service = NotificationService()
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

        owner_id = await self.owner_resolver.resolve_owner(
            review["target_type"], review["target_id"]
        )

        if owner_id:
            await self.notification_service.send(
                owner_id,
                "review_received",
                {
                    "target_type": review["target_type"],
                    "target_id": review["target_id"],
                    "rating": review["rating"],
                },
            )

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
