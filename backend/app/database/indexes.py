from app.database.mongodb import db


async def create_indexes():
    await db.users.create_index("email", unique=True)
    await db.users.create_index("phone")
    await db.users.create_index("country_code")

    await db.countries.create_index("code", unique=True)
    await db.cities.create_index([("country_code", 1), ("name", 1)], unique=True)

    # Concurrency-control pointer for seat bookings: guarantees at most one
    # "current occupancy" doc per trip+seat, which is what makes
    # BookingRepository.claim_seat's upsert race-safe under concurrent
    # requests for the same seat.
    await db.trip_seats.create_index([("trip_id", 1), ("seat_id", 1)], unique=True)