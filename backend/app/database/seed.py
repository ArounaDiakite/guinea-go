from datetime import UTC, datetime, timedelta

from app.core.constants import UserRole
from app.core.security import hash_password
from app.database.mongodb import db
from app.modules.events.events.schemas import EventCategory
from app.modules.events.ticket_types.schemas import TicketCategory


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


DEMO_EVENT_ORGANIZER = {
    "first_name": "Mariama",
    "last_name": "Camara",
    "email": "organisateur.demo@guineago.com",
    "phone": "+224620010203",
    "city": "Conakry",
    "country_code": "GN",
    "preferred_language": "fr",
}
DEMO_EVENT_ORGANIZER_PASSWORD = "Demo1234!"

# start_offset_days/duration_hours are resolved against "now" the one
# time this seed actually inserts data (see seed_demo_events) so the
# events stay in the future no matter how long ago the DB was first
# seeded, without needing to re-run and touch live quantity_available
# counters that real demo bookings may have since decremented.
DEMO_EVENTS = [
    {
        "name": "Concert Acoustik Nuit",
        "description": "Une soirée acoustique réunissant les meilleurs artistes de la scène guinéenne.",
        "venue": "Palais du Peuple, Conakry",
        "category": EventCategory.CONCERT,
        "start_offset_days": 20,
        "start_hour": 20,
        "duration_hours": 3,
        "ticket_types": [
            {"category": TicketCategory.STANDARD, "base_price": 50000, "quantity": 200},
            {"category": TicketCategory.VIP, "base_price": 150000, "quantity": 50, "description": "Accès carré or + boissons offertes."},
        ],
    },
    {
        "name": "Syli National vs Sénégal - Éliminatoires CAN",
        "description": "Match qualificatif de la Coupe d'Afrique des Nations au stade de Nongo.",
        "venue": "Stade Général Lansana Conté, Nongo",
        "category": EventCategory.SPORTS,
        "start_offset_days": 35,
        "start_hour": 18,
        "duration_hours": 2,
        "ticket_types": [
            {"category": TicketCategory.STANDARD, "base_price": 30000, "quantity": 500},
            {"category": TicketCategory.VIP, "base_price": 100000, "quantity": 100, "description": "Tribune officielle."},
        ],
    },
    {
        "name": "Salon International de l'Entrepreneuriat de Conakry",
        "description": "Rencontres, conférences et stands autour de l'entrepreneuriat en Guinée.",
        "venue": "Centre International de Conférences de Conakry (CICC), Sonfonia",
        "category": EventCategory.CONFERENCE,
        "start_offset_days": 45,
        "start_hour": 9,
        "duration_hours": 26,
        "ticket_types": [
            {"category": TicketCategory.STANDARD, "base_price": 25000, "quantity": 300, "description": "Pass 1 jour."},
            {"category": TicketCategory.VIP, "base_price": 80000, "quantity": 80, "description": "Pass complet, accès réseautage."},
        ],
    },
    {
        "name": "Festival des Îles de Los",
        "description": "Musique, artisanat et gastronomie le temps d'une journée sur les Îles de Los.",
        "venue": "Îles de Los, Kaloum",
        "category": EventCategory.FESTIVAL,
        "start_offset_days": 60,
        "start_hour": 10,
        "duration_hours": 8,
        "ticket_types": [
            {"category": TicketCategory.STANDARD, "base_price": 20000, "quantity": 400},
            {"category": TicketCategory.VIP, "base_price": 60000, "quantity": 60, "description": "Navette bateau incluse."},
        ],
    },
]


async def seed_demo_event_organizer():
    # Bypasses the normal register-partner + admin-activation flow
    # (see PARTNER_ROLES in core/constants.py) so the demo account is
    # usable to test the passenger search flow immediately, without a
    # system_administrator having to activate it first.
    now = datetime.now(UTC)
    await db.users.update_one(
        {"email": DEMO_EVENT_ORGANIZER["email"]},
        {
            "$set": {
                **DEMO_EVENT_ORGANIZER,
                "password": hash_password(DEMO_EVENT_ORGANIZER_PASSWORD),
                "role": UserRole.EVENT_ORGANIZER.value,
                "is_active": True,
                "is_verified": True,
                "profile_picture": None,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now, "last_login": None},
        },
        upsert=True,
    )
    return await db.users.find_one({"email": DEMO_EVENT_ORGANIZER["email"]})


async def seed_demo_events():
    organizer = await seed_demo_event_organizer()
    organizer_id = str(organizer["_id"])

    # Only ever inserts once: re-running this after real demo bookings
    # have decremented quantity_available (or a passenger cancelled
    # one) must never reset that live counter back to quantity_total.
    already_seeded = await db.events.find_one({"organizer_id": organizer_id, "is_deleted": False})
    if already_seeded:
        return

    country = await db.countries.find_one({"code": "GN"})
    city = await db.cities.find_one({"country_code": "GN", "name": "Conakry"})
    if not country or not city:
        # seed_countries()/seed_cities() haven't produced Guinea/Conakry
        # yet - run_seed() always calls them first, so this shouldn't
        # happen, but skip cleanly rather than crash if it ever does.
        return

    country_id = str(country["_id"])
    city_id = str(city["_id"])
    currency_id = country["currency_id"]

    now = datetime.now(UTC)

    for spec in DEMO_EVENTS:
        start = (now + timedelta(days=spec["start_offset_days"])).replace(
            hour=spec["start_hour"], minute=0, second=0, microsecond=0
        )
        end = start + timedelta(hours=spec["duration_hours"])

        event = {
            "name": spec["name"],
            "description": spec["description"],
            "venue": spec["venue"],
            "country_id": country_id,
            "city_id": city_id,
            "start_datetime": start,
            "end_datetime": end,
            "category": spec["category"].value,
            "organizer_id": organizer_id,
            "is_verified": True,
            "is_active": True,
            "is_deleted": False,
            "created_at": now,
            "updated_at": now,
        }
        result = await db.events.insert_one(event)
        event_id = str(result.inserted_id)

        for ticket_spec in spec["ticket_types"]:
            await db.ticket_types.insert_one({
                "event_id": event_id,
                "category": ticket_spec["category"].value,
                "base_price": ticket_spec["base_price"],
                "currency_id": currency_id,
                "quantity_total": ticket_spec["quantity"],
                "quantity_available": ticket_spec["quantity"],
                "description": ticket_spec.get("description"),
                "is_active": True,
                "is_deleted": False,
                "created_at": now,
                "updated_at": now,
            })


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


DEMO_STORE_MANAGER = {
    "first_name": "Ibrahima",
    "last_name": "Bah",
    "email": "commercant.demo@guineago.com",
    "phone": "+224621040506",
    "city": "Conakry",
    "country_code": "GN",
    "preferred_language": "fr",
}
DEMO_STORE_MANAGER_PASSWORD = "Demo1234!"

# Every product's category_ids points into this by name (resolved to a
# real category_id in seed_demo_commerce, same shape as products/
# service.py does at request time) - kept flat here since these seed
# categories don't need a parent hierarchy.
DEMO_CATEGORIES = ["Mode", "Électronique", "Alimentation"]

DEMO_STORES = [
    {
        "name": "Fouta Mode",
        "description": "Prêt-à-porter et accessoires pour toute la famille.",
        "phone": "+224621111222",
        "email": "contact@foutamode.gn",
        "address": "Marché Madina, Conakry",
        "shipping_info": "Retrait en boutique ou livraison à Conakry sous 48h.",
        "products": [
            {"name": "Boubou brodé homme", "category": "Mode", "price": 250000, "stock": 15},
            {"name": "Robe wax femme", "category": "Mode", "price": 180000, "stock": 20},
            {"name": "Sandales en cuir", "category": "Mode", "price": 90000, "stock": 30},
            {"name": "Sac à main tissé", "category": "Mode", "price": 120000, "stock": 12},
        ],
    },
    {
        "name": "Kaloum Électronique",
        "description": "Téléphones, accessoires et petit électronique.",
        "phone": "+224621333444",
        "email": "contact@kaloumelectro.gn",
        "address": "Avenue de la République, Kaloum, Conakry",
        "shipping_info": "Livraison à Conakry sous 24h, garantie 6 mois sur les appareils.",
        "products": [
            {"name": "Smartphone Tecno Spark", "category": "Électronique", "price": 950000, "stock": 10},
            {"name": "Chargeur solaire portable", "category": "Électronique", "price": 150000, "stock": 25},
            {"name": "Écouteurs Bluetooth", "category": "Électronique", "price": 80000, "stock": 40},
            {"name": "Powerbank 20000mAh", "category": "Électronique", "price": 200000, "stock": 18},
        ],
    },
    {
        "name": "Marché Frais Conakry",
        "description": "Produits alimentaires locaux et boissons artisanales.",
        "phone": "+224621555666",
        "email": "contact@marchefrais.gn",
        "address": "Marché de Niger, Conakry",
        "shipping_info": "Livraison à domicile à Conakry sous 24h.",
        "products": [
            {"name": "Sac de riz local 25kg", "category": "Alimentation", "price": 220000, "stock": 50},
            {"name": "Huile de palme 5L", "category": "Alimentation", "price": 60000, "stock": 35},
            {"name": "Café guinéen moulu 1kg", "category": "Alimentation", "price": 45000, "stock": 40},
            {"name": "Jus de bissap artisanal 1L", "category": "Alimentation", "price": 15000, "stock": 60},
        ],
    },
]


async def seed_demo_store_manager():
    # Bypasses the normal register-partner + admin-activation flow
    # (see PARTNER_ROLES in core/constants.py), same as the demo
    # event_organizer - usable to test the passenger catalog flow
    # immediately, without a system_administrator having to activate
    # it first.
    now = datetime.now(UTC)
    await db.users.update_one(
        {"email": DEMO_STORE_MANAGER["email"]},
        {
            "$set": {
                **DEMO_STORE_MANAGER,
                "password": hash_password(DEMO_STORE_MANAGER_PASSWORD),
                "role": UserRole.STORE_MANAGER.value,
                "is_active": True,
                "is_verified": True,
                "profile_picture": None,
                "updated_at": now,
            },
            "$setOnInsert": {"created_at": now, "last_login": None},
        },
        upsert=True,
    )
    return await db.users.find_one({"email": DEMO_STORE_MANAGER["email"]})


async def seed_demo_commerce():
    owner = await seed_demo_store_manager()
    owner_id = str(owner["_id"])

    # Only ever inserts once: re-running this after real demo orders
    # have decremented product stock must never reset those live
    # counters back to their seeded starting values.
    already_seeded = await db.stores.find_one({"owner_id": owner_id, "is_deleted": False})
    if already_seeded:
        return

    country = await db.countries.find_one({"code": "GN"})
    city = await db.cities.find_one({"country_code": "GN", "name": "Conakry"})
    if not country or not city:
        # seed_countries()/seed_cities() haven't produced Guinea/Conakry
        # yet - run_seed() always calls them first, so this shouldn't
        # happen, but skip cleanly rather than crash if it ever does.
        return

    country_id = str(country["_id"])
    city_id = str(city["_id"])
    currency_id = country["currency_id"]

    now = datetime.now(UTC)

    category_ids = {}
    for name in DEMO_CATEGORIES:
        category = await db.categories.find_one({"name": name})
        if not category:
            result = await db.categories.insert_one({
                "name": name,
                "description": None,
                "category_parent_id": None,
                "is_active": True,
                "is_deleted": False,
                "created_at": now,
                "updated_at": now,
            })
            category_ids[name] = str(result.inserted_id)
        else:
            category_ids[name] = str(category["_id"])

    for store_spec in DEMO_STORES:
        store = {
            "name": store_spec["name"],
            "description": store_spec["description"],
            "logo_url": None,
            "phone": store_spec["phone"],
            "email": store_spec["email"],
            "country_id": country_id,
            "city_id": city_id,
            "address": store_spec["address"],
            "shipping_info": store_spec["shipping_info"],
            "owner_id": owner_id,
            "is_verified": True,
            "is_active": True,
            "is_deleted": False,
            "created_at": now,
            "updated_at": now,
        }
        result = await db.stores.insert_one(store)
        store_id = str(result.inserted_id)

        for product_spec in store_spec["products"]:
            await db.products.insert_one({
                "store_id": store_id,
                "name": product_spec["name"],
                "description": None,
                "price": product_spec["price"],
                "currency_id": currency_id,
                "category_ids": [category_ids[product_spec["category"]]],
                "images": [],
                "stock": product_spec["stock"],
                "is_active": True,
                "is_deleted": False,
                "created_at": now,
                "updated_at": now,
            })


async def run_seed():
    await seed_currencies()
    await seed_countries()
    await seed_cities()
    await seed_demo_events()
    await seed_demo_commerce()
