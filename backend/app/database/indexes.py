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
    await db.companies.create_index("city_id")
    await db.companies.create_index("country_id")

    # Buses - fields filtered on in BusRepository.get_all.
    await db.buses.create_index("company_id")
    await db.buses.create_index("status")

    # Stations - fields filtered on in StationRepository.get_all, plus
    # station_code which get_by_code looks up on every route creation.
    await db.stations.create_index("city_id")
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

    # Concurrency-control pointer for hotel room bookings: one document
    # per (room_id, night) actually claimed, which is what makes
    # HotelBookingRepository.claim_nights' insert_many race-safe - a date
    # range can't be a single compare-and-swap key like a trip+seat slot,
    # so each night in the stay gets its own uniquely-indexed row.
    await db.room_nights.create_index([("room_id", 1), ("night", 1)], unique=True)

    # Hotels / Rooms / hotel_bookings - fields filtered on in their
    # respective get_all()/has_overlap() queries.
    await db.hotels.create_index("city_id")
    await db.hotels.create_index("country_id")
    await db.rooms.create_index("hotel_id")
    await db.rooms.create_index("status")
    await db.hotel_bookings.create_index("passenger_id")
    await db.hotel_bookings.create_index([("room_id", 1), ("status", 1)])

    # Events / TicketTypes / event_bookings - fields filtered on in their
    # respective get_all() queries. No per-unit concurrency-control
    # collection needed here (unlike trip_seats/room_nights): a ticket
    # has no individual identity, so the atomic claim is a single
    # find_one_and_update on ticket_types.quantity_available itself -
    # nothing to index beyond the implicit _id lookup that's already
    # covered by the default _id index.
    await db.events.create_index("city_id")
    await db.events.create_index("country_id")
    await db.events.create_index("category")
    await db.ticket_types.create_index("event_id")
    await db.event_bookings.create_index("passenger_id")
    await db.event_bookings.create_index([("ticket_type_id", 1), ("status", 1)])

    # Categories / Stores / Products - fields filtered on in their
    # respective get_all() queries.
    await db.categories.create_index("category_parent_id")
    await db.stores.create_index("owner_id")
    await db.stores.create_index("city_id")
    await db.stores.create_index("country_id")
    await db.products.create_index("category_ids")
    await db.products.create_index("store_id")

    # One cart per user, enforced at the database level - backs
    # CartRepository.get_or_create's upsert against a genuine race on a
    # user's very first cart action.
    await db.carts.create_index("customer_id", unique=True)

    # Orders - fields filtered on in get_by_customer()/get_stale_pending_
    # orders(). No per-unit concurrency-control collection here either,
    # same reasoning as ticket_types: the atomic claim is a single
    # find_one_and_update on products.stock itself.
    await db.orders.create_index("customer_id")
    await db.orders.create_index([("store_id", 1), ("status", 1)])

    # Institutions: one per school_administrator, enforced at the database
    # level - backs InstitutionService.create_institution's advisory check
    # against a genuine double-submit race on a user's very first
    # institution creation (same reasoning as carts.customer_id).
    await db.institutions.create_index("administrator_id", unique=True)

    # AcademicUnits / Teachers / Students - fields filtered on in their
    # respective get_by_institution() queries. No cross-institution
    # queries exist anywhere in this module by design, so institution_id
    # is the only index that matters for isolation/performance here.
    await db.academic_units.create_index("institution_id")
    await db.teachers.create_index("institution_id")
    await db.teachers.create_index("academic_unit_ids")
    await db.students.create_index("institution_id")
    await db.students.create_index("academic_unit_id")

    # Subjects / TimeSlots - fields filtered/queried on in get_by_
    # institution()/get_by_academic_unit()/has_overlap(). The compound
    # indexes match has_overlap()'s query shape exactly (field + day_of_
    # week, then a range scan on start_time/end_time).
    await db.subjects.create_index("institution_id")
    await db.timeslots.create_index("academic_unit_id")
    await db.timeslots.create_index([("teacher_id", 1), ("day_of_week", 1)])
    await db.timeslots.create_index([("academic_unit_id", 1), ("day_of_week", 1)])

    # Attendance: one record per (timeslot, date, student), enforced at
    # the database level - backs AttendanceRepository.create_many's
    # pre-checked insert against a genuine double-submit race (same
    # reasoning as institutions.administrator_id / carts.customer_id),
    # and doubles as the query shape for get_by_timeslot_and_date/
    # get_one. get_by_student needs its own index since student_id isn't
    # a prefix of the compound key above.
    await db.attendance_records.create_index(
        [("timeslot_id", 1), ("date", 1), ("student_id", 1)], unique=True
    )
    await db.attendance_records.create_index([("student_id", 1), ("date", -1)])

    # Grades - matches get_by_student()'s query shape (student_id, with
    # an optional period filter used by both the grades list and the
    # report card calculation).
    await db.grades.create_index([("student_id", 1), ("period", 1)])

    # Fee schedules / student fees - institution_id backs get_by_
    # institution(); the unique (student_id, fee_schedule_id) pair backs
    # apply_fee_schedule's pre-checked insert against a genuine
    # double-submit race, same shape as attendance_records above, and
    # doubles as get_by_student_and_schedule's lookup.
    await db.fee_schedules.create_index("institution_id")
    await db.student_fees.create_index(
        [("student_id", 1), ("fee_schedule_id", 1)], unique=True
    )

    # Payments - booking_id is what every lookup in this collection
    # filters on (get_by_booking/get_pending_by_booking/
    # get_all_by_booking), across all five booking_type values.
    await db.payments.create_index("booking_id")

    # Reviews - the unique (author_id, target_type, target_id) triple
    # backs create_review's pre-checked insert against a genuine
    # double-submit race (same shape as attendance_records/
    # student_fees) and doubles as get_by_author_and_target()'s lookup.
    # target_id doesn't share a prefix with that one (author_id leads),
    # so get_by_target()'s (target_type, target_id) list query needs
    # its own index.
    await db.reviews.create_index(
        [("author_id", 1), ("target_type", 1), ("target_id", 1)], unique=True
    )
    await db.reviews.create_index([("target_type", 1), ("target_id", 1)])

    # Notifications - matches get_by_user()'s query shape exactly
    # (filter by user_id, sorted by created_at descending for "most
    # recent first").
    await db.notifications.create_index([("user_id", 1), ("created_at", -1)])