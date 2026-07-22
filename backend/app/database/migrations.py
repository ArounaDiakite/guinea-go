"""One-off, idempotent data migrations run at every startup (see
database/startup.py) - appropriate for this project's current stage
(no real persisted production data yet) rather than a formal migration
framework. Each function only touches documents that still have the
old shape (checked via the presence/absence of the new field) and is
therefore a no-op on documents already migrated. Must run after
run_seed() (database/seed.py), since resolving country_code/city/
currency_code to ids requires shared/countries, shared/cities and
shared/currencies to already be seeded.

Grown module by module as each business module is converted from free-
text country_code/city to real country_id/city_id/currency_id
references - see CLAUDE.md's "Données de référence" section. The three
_migrate_* helpers below are generic (collection-agnostic) since every
module needs the exact same two shapes: a top-level entity with
country_code/city to migrate to country_id/city_id (or city_id alone,
for a Station-like entity whose country is only ever derived through
its city), and a child entity whose currency_id is inherited from its
parent's already-migrated country_id.
"""

import random
import string

from bson import ObjectId

from app.database.mongodb import db

# Same alphabet/length as Teacher/StudentService's own invite-code
# generation (transport/tickets/service.py's collision-retry style) -
# duplicated here rather than imported, since this module intentionally
# never imports application services, only touches raw collections.
_INVITE_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
_INVITE_CODE_LENGTH = 8


def _generate_invite_code() -> str:
    return "".join(random.choices(_INVITE_CODE_ALPHABET, k=_INVITE_CODE_LENGTH))


async def _backfill_invite_code(collection):
    """Teacher/Student documents created before invite_code existed
    have it missing or null, which collides under the unique index
    (database/indexes.py) the moment more than one such document
    exists - backfills each with a fresh, real code. Must run before
    create_indexes() (see backfill_legacy_invite_codes below), unlike
    every other migration in this module, which runs after it - the
    unique index build itself is what fails on the pre-existing nulls,
    so there's nothing to migrate into once that's already thrown."""
    cursor = collection.find({"$or": [{"invite_code": {"$exists": False}}, {"invite_code": None}]})

    async for doc in cursor:
        code = _generate_invite_code()
        for _ in range(3):
            if not await collection.find_one({"invite_code": code}):
                break
            code = _generate_invite_code()

        await collection.update_one({"_id": doc["_id"]}, {"$set": {"invite_code": code}})


async def backfill_legacy_invite_codes():
    await _backfill_invite_code(db.teachers)
    await _backfill_invite_code(db.students)


async def _resolve_country_and_city(country_code: str, city_name: str | None):
    """Best-effort lookup shared by every per-module migration below.
    Returns (country_id, city_id) - city_id is None if no seeded City
    matches (e.g. a city string that predates shared/cities' seed list),
    in which case the migration still sets country_id and just leaves
    city_id unresolved rather than failing the whole document."""
    country = await db.countries.find_one({"code": country_code.upper()})

    if not country:
        return None, None

    city_id = None

    if city_name:
        city = await db.cities.find_one({
            "country_code": country_code.upper(),
            "name": city_name,
        })
        if city:
            city_id = str(city["_id"])

    return str(country["_id"]), city_id


async def _migrate_location_collection(collection):
    """country_code/city (free text) -> country_id/city_id, for a top-
    level entity that owns its own location (Company, Hotel, Event,
    Store, Institution)."""
    cursor = collection.find({
        "country_id": {"$exists": False},
        "country_code": {"$exists": True},
    })

    async for doc in cursor:
        country_id, city_id = await _resolve_country_and_city(
            doc["country_code"], doc.get("city")
        )

        if not country_id:
            print(f"⚠️ Skipping {collection.name} {doc['_id']}: unknown country_code {doc['country_code']!r}")
            continue

        update = {"country_id": country_id}
        if city_id:
            update["city_id"] = city_id

        await collection.update_one(
            {"_id": doc["_id"]},
            {"$set": update, "$unset": {"country_code": "", "city": ""}},
        )


async def _migrate_city_only_collection(collection):
    """country_code/city (free text) -> city_id only, for an entity
    whose country is always derivable through its city (Station)."""
    cursor = collection.find({
        "city_id": {"$exists": False},
        "country_code": {"$exists": True},
    })

    async for doc in cursor:
        _, city_id = await _resolve_country_and_city(
            doc["country_code"], doc.get("city")
        )

        if not city_id:
            print(f"⚠️ Skipping {collection.name} {doc['_id']}: could not resolve city {doc.get('city')!r} in {doc['country_code']!r}")
            continue

        await collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"city_id": city_id}, "$unset": {"country_code": "", "city": ""}},
        )


async def _migrate_currency_via_parent(collection, parent_collection, parent_id_field, price_field="base_price"):
    """currency_id, inherited from the parent's (already-migrated)
    country_id, for a child entity that carries a price (Route via
    Company, Room via Hotel). Must run after the parent's own location
    migration."""
    cursor = collection.find({
        "currency_id": {"$exists": False},
        price_field: {"$exists": True},
    })

    async for doc in cursor:
        parent = await parent_collection.find_one({"_id": ObjectId(doc[parent_id_field])})

        if not parent or not parent.get("country_id"):
            print(f"⚠️ Skipping {collection.name} {doc['_id']}: parent {doc[parent_id_field]} has no resolved country_id yet")
            continue

        country = await db.countries.find_one({"_id": ObjectId(parent["country_id"])})

        if not country:
            print(f"⚠️ Skipping {collection.name} {doc['_id']}: parent's country_id does not resolve")
            continue

        await collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"currency_id": country["currency_id"]}},
        )


async def _migrate_currency_from_parent_currency(collection, parent_collection, parent_id_field):
    """currency_id, copied directly from a parent that already carries
    its own currency_id (StudentFee via FeeSchedule) - unlike
    _migrate_currency_via_parent above, which resolves through a
    parent's country_id, this parent already IS the currency source
    (same snapshot-at-apply-time reasoning as the live code path, see
    fees/service.py's apply_fee_schedule). Must run after the parent
    collection's own currency migration."""
    cursor = collection.find({"currency_id": {"$exists": False}})

    async for doc in cursor:
        if not ObjectId.is_valid(doc[parent_id_field]):
            continue

        parent = await parent_collection.find_one({"_id": ObjectId(doc[parent_id_field])})

        if not parent or not parent.get("currency_id"):
            print(f"⚠️ Skipping {collection.name} {doc['_id']}: parent {doc[parent_id_field]} has no resolved currency_id yet")
            continue

        await collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"currency_id": parent["currency_id"]}},
        )


async def migrate_companies_location():
    await _migrate_location_collection(db.companies)


async def migrate_stations_location():
    await _migrate_city_only_collection(db.stations)


async def migrate_routes_currency():
    # Must run after migrate_companies_location().
    await _migrate_currency_via_parent(db.routes, db.companies, "company_id")


async def migrate_hotels_location():
    await _migrate_location_collection(db.hotels)


async def migrate_rooms_currency():
    # Must run after migrate_hotels_location().
    await _migrate_currency_via_parent(db.rooms, db.hotels, "hotel_id")


async def migrate_events_location():
    await _migrate_location_collection(db.events)


async def migrate_ticket_types_currency():
    # Must run after migrate_events_location().
    await _migrate_currency_via_parent(db.ticket_types, db.events, "event_id")


async def migrate_stores_location():
    await _migrate_location_collection(db.stores)


async def migrate_products_currency():
    # Must run after migrate_stores_location().
    await _migrate_currency_via_parent(db.products, db.stores, "store_id", price_field="price")


async def migrate_institutions_location():
    await _migrate_location_collection(db.institutions)


async def migrate_fee_schedules_currency():
    # Must run after migrate_institutions_location().
    await _migrate_currency_via_parent(
        db.fee_schedules, db.institutions, "institution_id", price_field="amount"
    )


async def migrate_student_fees_currency():
    # Must run after migrate_fee_schedules_currency(): StudentFee
    # already snapshots amount_due from its FeeSchedule at apply time
    # in the live code path, so its currency_id is backfilled the same
    # way - copied from the schedule, not re-derived from a country.
    await _migrate_currency_from_parent_currency(
        db.student_fees, db.fee_schedules, "fee_schedule_id"
    )


async def run_migrations():
    await migrate_companies_location()
    await migrate_stations_location()
    await migrate_routes_currency()
    await migrate_hotels_location()
    await migrate_rooms_currency()
    await migrate_events_location()
    await migrate_ticket_types_currency()
    await migrate_stores_location()
    await migrate_products_currency()
    await migrate_institutions_location()
    await migrate_fee_schedules_currency()
    await migrate_student_fees_currency()
