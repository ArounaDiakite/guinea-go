from datetime import datetime, time, timedelta

from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.database.mongodb import db


class HotelBookingRepository:
    def __init__(self):
        self.collection = db.hotel_bookings
        # room_nights is a concurrency-control collection: one document per
        # (room_id, night) actually claimed by a booking, backed by a
        # unique index (database/indexes.py). This is what makes
        # claim_nights() genuinely atomic - a date-range overlap can't be
        # expressed as a single-document compare-and-swap the way a fixed
        # trip+seat slot can, so each night in the stay is claimed as its
        # own uniquely-indexed row. hotel_bookings itself stays an
        # append-only history log, same role as `bookings` in transport.
        self.room_nights_collection = db.room_nights

    def _nights_in_range(self, check_in, check_out):
        # check_out is exclusive - the night of check_out itself isn't
        # stayed (that's checkout day).
        nights = []
        current = check_in

        while current < check_out:
            nights.append(current)
            current += timedelta(days=1)

        return nights

    async def claim_nights(self, room_id: str, check_in, check_out, booking_id: ObjectId) -> bool:
        night_docs = [
            {
                "room_id": room_id,
                "night": datetime.combine(night, time.min),
                "booking_id": str(booking_id),
            }
            for night in self._nights_in_range(check_in, check_out)
        ]

        try:
            await self.room_nights_collection.insert_many(night_docs, ordered=True)
            return True
        except DuplicateKeyError:
            # Ordered insert stops at the first conflicting night, but
            # whichever nights came before it in the batch did get
            # written - clean those up so this failed attempt doesn't
            # leave a partial claim behind.
            await self.room_nights_collection.delete_many(
                {"room_id": room_id, "booking_id": str(booking_id)}
            )
            return False

    async def release_nights(self, booking_id: str):
        await self.room_nights_collection.delete_many({"booking_id": str(booking_id)})

    async def has_overlap(self, room_id: str, check_in, check_out) -> bool:
        """Advisory fast-path check only - NOT the atomicity guarantee.
        Lets create_booking return a clean 409 before attempting any
        writes in the common (non-racy) case. The real safety net against
        concurrent double-booking is claim_nights' unique index."""
        check_in_dt = datetime.combine(check_in, time.min)
        check_out_dt = datetime.combine(check_out, time.min)

        existing = await self.collection.find_one(
            {
                "room_id": room_id,
                "status": {"$in": ["PENDING_PAYMENT", "CONFIRMED"]},
                "check_in": {"$lt": check_out_dt},
                "check_out": {"$gt": check_in_dt},
            }
        )

        return existing is not None

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

    async def get_booked_room_ids(self, check_in, check_out, hotel_id: str | None = None) -> list[str]:
        """Room ids with an active (PENDING_PAYMENT/CONFIRMED) booking
        overlapping [check_in, check_out) - used to filter room search
        results down to what's actually available for those dates."""
        check_in_dt = datetime.combine(check_in, time.min)
        check_out_dt = datetime.combine(check_out, time.min)

        query = {
            "status": {"$in": ["PENDING_PAYMENT", "CONFIRMED"]},
            "check_in": {"$lt": check_out_dt},
            "check_out": {"$gt": check_in_dt},
        }

        if hotel_id:
            query["hotel_id"] = hotel_id

        return await self.collection.distinct("room_id", query)

    async def get_by_hotel(self, hotel_id: str, page: int = 1, limit: int = 20):
        cursor = (
            self.collection.find({"hotel_id": hotel_id})
            .sort("created_at", -1)
            .skip((page - 1) * limit)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def get_stale_pending_bookings(self, room_id: str, now):
        cursor = self.collection.find(
            {
                "room_id": room_id,
                "status": "PENDING_PAYMENT",
                "expires_at": {"$lte": now},
            }
        )
        return await cursor.to_list(length=None)

    async def transition_status_if(
        self,
        booking_id: str,
        expected_statuses: list[str] | str,
        data: dict,
    ) -> bool:
        if isinstance(expected_statuses, str):
            expected_statuses = [expected_statuses]

        result = await self.collection.update_one(
            {"_id": ObjectId(booking_id), "status": {"$in": expected_statuses}},
            {"$set": data},
        )
        return result.modified_count > 0
