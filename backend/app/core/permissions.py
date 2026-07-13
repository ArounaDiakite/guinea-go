from fastapi import HTTPException, status

from app.core.constants import UserRole

ALL_PERMISSIONS = "*"

ROLE_PERMISSIONS: dict[UserRole, set[str]] = {
    UserRole.PASSENGER: {
        "trips:search",
        "trips:book",
        "payments:make",
        "tickets:view_own",
        "bookings:view_own",
    },
    UserRole.COMPANY_OWNER: {
        "companies:create",
        "companies:manage",
        "buses:manage",
        "drivers:manage",
        "stations:manage",
        "routes:manage",
        "schedules:manage",
        "trips:manage",
        "reports:view",
    },
    UserRole.DRIVER: {
        "trips:view_assigned",
        "tickets:scan",
        "trips:update_status",
    },
    UserRole.HOTEL_OWNER: {
        "hotels:manage",
        "rooms:manage",
        "reservations:manage",
        "reports:view_occupancy",
    },
    UserRole.EVENT_ORGANIZER: {
        "events:manage",
        "tickets:sell",
        "qrcodes:generate",
        "attendance:monitor",
    },
    UserRole.SCHOOL_ADMINISTRATOR: {
        "students:manage",
        "teachers:manage",
        "classes:manage",
        "exams:manage",
        "attendance:manage",
        "fees:manage",
    },
    UserRole.STORE_MANAGER: {
        "stores:manage",
        "inventory:manage",
        "products:manage",
        "categories:manage",
        "suppliers:manage",
        "customers:manage",
        "invoices:manage",
        "reports:generate",
    },
    UserRole.SYSTEM_ADMINISTRATOR: {ALL_PERMISSIONS},
}


def get_permissions_for_role(role: str) -> list[str]:
    return sorted(ROLE_PERMISSIONS.get(role, set()))


def role_has_permission(role: str, permission: str) -> bool:
    role_permissions = ROLE_PERMISSIONS.get(role, set())
    return ALL_PERMISSIONS in role_permissions or permission in role_permissions


def ensure_owner(resource_owner_id: str, current_user_id: str):
    if resource_owner_id != current_user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not allowed to perform this action.",
        )