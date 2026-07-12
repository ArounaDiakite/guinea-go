from bson import ObjectId
from pymongo import ReturnDocument
from pymongo.errors import DuplicateKeyError

from app.database.mongodb import db


class BookingRepository:
    def __init__(self):
        self.collection = db.bookings
        # trip_seats is a concurrency-control pointer (one doc per
        # trip_id+seat_id, mutated in place), separate from the `bookings`
        # collection which is an append-only history log. A unique index
        # on (trip_id, seat_id) - created in database/indexes.py - is what
        # makes claim_seat's upsert race-safe.
        self.trip_seats_collection = db.trip_seats

    async def claim_seat(self, trip_id: str, seat_id: str, booking_id: ObjectId, now):
        """Atomically flip the trip_seats pointer to RESERVED, but only if
        it isn't already RESERVED. Uses find_one_and_update (not a
        read-then-write) so two concurrent callers can't both succeed:
        whichever loses the race either doesn't match the filter (existing
        doc already RESERVED) or collides with the unique index while
        upserting a first-ever claim for this trip_id+seat_id - both cases
        surface as a failure here, converted to None."""
        try:
            return await self.trip_seats_collection.find_one_and_update(
                {"trip_id": trip_id, "seat_id": seat_id, "status": {"$ne": "RESERVED"}},
                {
                    "$set": {
                        "trip_id": trip_id,
                        "seat_id": seat_id,
                        "status": "RESERVED",
                        "booking_id": str(booking_id),
                        "updated_at": now,
                    }
                },
                upsert=True,
                return_document=ReturnDocument.AFTER,
            )
        except DuplicateKeyError:
            return None

    async def release_seat(self, trip_id: str, seat_id: str, booking_id: str, now):
        await self.trip_seats_collection.find_one_and_update(
            {"trip_id": trip_id, "seat_id": seat_id, "booking_id": booking_id},
            {"$set": {"status": "AVAILABLE", "booking_id": None, "updated_at": now}},
        )

    async def get_reserved_seat_ids(self, trip_id: str) -> set[str]:
        cursor = self.trip_seats_collection.find(
            {"trip_id": trip_id, "status": "RESERVED"}
        )
        docs = await cursor.to_list(length=None)
        return {doc["seat_id"] for doc in docs}

    async def create(self, booking_data: dict):
        await self.collection.insert_one(booking_data)
        return await self.get_by_id(str(booking_data["_id"]))

    async def get_by_id(self, booking_id: str):
        if not ObjectId.is_valid(booking_id):
            return None

        return await self.collection.find_one({"_id": ObjectId(booking_id)})

    async def get_by_passenger(self, passenger_id: str, page: int = 1, limit: int = 20):
        cursor = (
            self.collection.find({"passenger_id": passenger_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def update_status(self, booking_id: str, data: dict):
        await self.collection.update_one(
            {"_id": ObjectId(booking_id)},
            {"$set": data},
        )
        return await self.get_by_id(booking_id)
