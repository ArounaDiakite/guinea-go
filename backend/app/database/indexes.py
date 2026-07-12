from app.database.mongodb import db


async def create_indexes():
    await db.users.create_index("email", unique=True)
    await db.users.create_index("phone")
    await db.users.create_index("country_code")

    await db.countries.create_index("code", unique=True)
    await db.cities.create_index([("country_code", 1), ("name", 1)], unique=True)