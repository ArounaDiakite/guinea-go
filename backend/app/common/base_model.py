from datetime import datetime, UTC


def now():
    return datetime.now(UTC)


class BaseDocument:

    @staticmethod
    def create():
        return {
            "created_at": now(),
            "updated_at": now(),
            "is_active": True,
            "is_deleted": False,
        }

    @staticmethod
    def update():
        return {
            "updated_at": now(),
        }