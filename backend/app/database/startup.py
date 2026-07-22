from app.database.indexes import create_indexes
from app.database.migrations import backfill_legacy_invite_codes, run_migrations
from app.database.seed import run_seed


async def init_database():
    try:
        # Must run before create_indexes(): teachers/students documents
        # predating the invite_code field have it missing/null, which
        # collides under the new unique index the moment more than one
        # exists - see backfill_legacy_invite_codes' own docstring.
        await backfill_legacy_invite_codes()
        await create_indexes()
        await run_seed()
        await run_migrations()
        print("✅ Database initialized successfully")
    except Exception as error:
        print("⚠️ Database initialization skipped")
        print(f"Reason: {error}")