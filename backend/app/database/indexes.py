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

    # Companies - fields filtered on in CompanyRepository.get_all.
    await db.companies.create_index("company_type")
    await db.companies.create_index("city")

    # Buses - fields filtered on in BusRepository.get_all.
    await db.buses.create_index("company_id")
    await db.buses.create_index("status")

    # Stations - fields filtered on in StationRepository.get_all, plus
    # station_code which get_by_code looks up on every route creation.
    await db.stations.create_index("city")
    await db.stations.create_index("station_type")
    await db.stations.create_index("station_code")

    # Routes - company_id filters get_all; route_code is looked up by
    # get_by_code on every route creation (uniqueness check).
    await db.routes.create_index("company_id")
    await db.routes.create_index("route_code")

    # Schedules - fields filtered on in ScheduleRepository.get_all.
    await db.schedules.create_index("company_id")
    await db.schedules.create_index("route_id")
    await db.schedules.create_index("status")

    # Trips - fields filtered on in TripRepository.get_all, plus a
    # compound index for the common "this company's trips around a given
    # date" query (also the shape of the default sort, departure_datetime).
    await db.trips.create_index("company_id")
    await db.trips.create_index("route_id")
    await db.trips.create_index("status")
    await db.trips.create_index([("company_id", 1), ("travel_date", 1)])