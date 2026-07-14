from app.database.mongodb import db


CURRENCIES = [
    {"code": "GNF", "name": "Franc Guinéen", "symbol": "FG", "is_active": True},
    {"code": "XOF", "name": "Franc CFA (BCEAO)", "symbol": "CFA", "is_active": True},
    {"code": "GHS", "name": "Cedi Ghanéen", "symbol": "₵", "is_active": True},
]

COUNTRIES = [
    {
        "code": "GN",
        "name": "Guinea",
        "currency_code": "GNF",
        "timezone": "Africa/Conakry",
        "languages": ["fr"],
        "payment_methods": ["orange_money", "mtn_money", "cash"],
        "is_active": True,
    },
    {
        "code": "SN",
        "name": "Senegal",
        "currency_code": "XOF",
        "timezone": "Africa/Dakar",
        "languages": ["fr"],
        "payment_methods": ["wave", "orange_money", "cash"],
        "is_active": True,
    },
    {
        "code": "GH",
        "name": "Ghana",
        "currency_code": "GHS",
        "timezone": "Africa/Accra",
        "languages": ["en"],
        "payment_methods": ["mobile_money", "cash"],
        "is_active": True,
    },
]
CITIES = [
    {"country_code": "GN", "name": "Conakry", "state_or_region": "Conakry", "is_active": True},
    {"country_code": "GN", "name": "Siguiri", "state_or_region": "Kankan", "is_active": True},
    {"country_code": "GN", "name": "Kankan", "state_or_region": "Kankan", "is_active": True},
    {"country_code": "GN", "name": "Labé", "state_or_region": "Labé", "is_active": True},

    {"country_code": "SN", "name": "Dakar", "state_or_region": "Dakar", "is_active": True},
    {"country_code": "SN", "name": "Thiès", "state_or_region": "Thiès", "is_active": True},

    {"country_code": "GH", "name": "Accra", "state_or_region": "Greater Accra", "is_active": True},
    {"country_code": "GH", "name": "Kumasi", "state_or_region": "Ashanti", "is_active": True},
]


async def seed_currencies():
    for currency in CURRENCIES:
        await db.currencies.update_one(
            {"code": currency["code"]},
            {"$set": currency},
            upsert=True,
        )


async def seed_countries():
    # Must run after seed_currencies(): each country stores a real
    # currency_id (not a free "currency" string), resolved here by
    # looking up the currency it names by code. $unset cleans up the
    # old free-text "currency" field on documents seeded before this
    # migration - a no-op once a country has already been migrated.
    for country in COUNTRIES:
        currency = await db.currencies.find_one({"code": country["currency_code"]})

        country_data = {k: v for k, v in country.items() if k != "currency_code"}
        country_data["currency_id"] = str(currency["_id"])

        await db.countries.update_one(
            {"code": country["code"]},
            {"$set": country_data, "$unset": {"currency": ""}},
            upsert=True,
        )


async def seed_cities():
    for city in CITIES:
        await db.cities.update_one(
            {
                "country_code": city["country_code"],
                "name": city["name"],
            },
            {"$set": city},
            upsert=True,
        )


async def run_seed():
    await seed_currencies()
    await seed_countries()
    await seed_cities()
