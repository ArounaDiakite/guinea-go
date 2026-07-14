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
references - see CLAUDE.md's "Données de référence" section.
"""

from bson import ObjectId

from app.database.mongodb import db


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


async def migrate_companies_location():
    cursor = db.companies.find({
        "country_id": {"$exists": False},
        "country_code": {"$exists": True},
    })

    async for company in cursor:
        country_id, city_id = await _resolve_country_and_city(
            company["country_code"], company.get("city")
        )

        if not country_id:
            print(f"⚠️ Skipping company {company['_id']}: unknown country_code {company['country_code']!r}")
            continue

        update = {"country_id": country_id}
        if city_id:
            update["city_id"] = city_id

        await db.companies.update_one(
            {"_id": company["_id"]},
            {"$set": update, "$unset": {"country_code": "", "city": ""}},
        )


async def migrate_stations_location():
    cursor = db.stations.find({
        "city_id": {"$exists": False},
        "country_code": {"$exists": True},
    })

    async for station in cursor:
        _, city_id = await _resolve_country_and_city(
            station["country_code"], station.get("city")
        )

        if not city_id:
            print(f"⚠️ Skipping station {station['_id']}: could not resolve city {station.get('city')!r} in {station['country_code']!r}")
            continue

        await db.stations.update_one(
            {"_id": station["_id"]},
            {"$set": {"city_id": city_id}, "$unset": {"country_code": "", "city": ""}},
        )


async def migrate_routes_currency():
    # Must run after migrate_companies_location(): resolves each
    # route's currency via its company's (already-migrated) country.
    cursor = db.routes.find({
        "currency_id": {"$exists": False},
        "base_price": {"$exists": True},
    })

    async for route in cursor:
        company = await db.companies.find_one({"_id": ObjectId(route["company_id"])})

        if not company or not company.get("country_id"):
            print(f"⚠️ Skipping route {route['_id']}: company {route['company_id']} has no resolved country_id yet")
            continue

        country = await db.countries.find_one({"_id": ObjectId(company["country_id"])})

        if not country:
            print(f"⚠️ Skipping route {route['_id']}: company's country_id does not resolve")
            continue

        await db.routes.update_one(
            {"_id": route["_id"]},
            {"$set": {"currency_id": country["currency_id"]}},
        )


async def run_migrations():
    await migrate_companies_location()
    await migrate_stations_location()
    await migrate_routes_currency()
