from app.database.indexes import create_indexes
from app.database.seed import run_seed


async def init_database():
    try:
        await create_indexes()
        await run_seed()
        print("✅ Database initialized successfully")
    except Exception as error:
        print("⚠️ Database initialization skipped")
        print(f"Reason: {error}")