from app.database.mongodb import db


COUNTRIES = [
    {
        "code": "GN",
        "name": "Guinea",
        "currency": "GNF",
        "timezone": "Africa/Conakry",
        "languages": ["fr"],
        "payment_methods": ["orange_money", "mtn_money", "cash"],
        "is_active": True,
    },
    {
        "code": "SN",
        "name": "Senegal",
        "currency": "XOF",
        "timezone": "Africa/Dakar",
        "languages": ["fr"],
        "payment_methods": ["wave", "orange_money", "cash"],
        "is_active": True,
    },
    {
        "code": "GH",
        "name": "Ghana",
        "currency": "GHS",
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

async def seed_countries():
    for country in COUNTRIES:
        await db.countries.update_one(
            {"code": country["code"]},
            {"$set": country},
            upsert=True,
        )


async def run_seed():
    await seed_countries()
    await seed_cities()

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

PAYMENT_PROVIDERS = [
    {
        "code": "ORANGE_GN",
        "name": "Orange Money",
        "provider_type": "mobile_money",
        "country_code": "GN",
        "is_active": True,
    },
    {
        "code": "MTN_GN",
        "name": "MTN Mobile Money",
        "provider_type": "mobile_money",
        "country_code": "GN",
        "is_active": True,
    },
    {
        "code": "WAVE_SN",
        "name": "Wave",
        "provider_type": "mobile_money",
        "country_code": "SN",
        "is_active": True,
    },
    {
        "code": "STRIPE",
        "name": "Stripe",
        "provider_type": "card",
        "country_code": "GLOBAL",
        "is_active": True,
    },
    {
        "code": "PAYPAL",
        "name": "PayPal",
        "provider_type": "wallet",
        "country_code": "GLOBAL",
        "is_active": True,
    },
]        