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
        "institutions:manage",
        "academic_units:manage",
        "subjects:manage",
        "timeslots:manage",
        "students:manage",
        "teachers:manage",
        "classes:manage",
        "exams:manage",
        "attendance:manage",
        "grades:manage",
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
    # Self-registers via invite code (POST /auth/register-school-member)
    # rather than school_administrator:manage - a teacher only manages
    # attendance for the timeslots actually assigned to them (checked in
    # AttendanceService, not expressible as a bare permission string),
    # everything else here is read-only.
    UserRole.TEACHER: {
        "academic_units:view_own",
        "students:view_own",
        "timeslots:view_own",
        "attendance:manage_own",
        "grades:view_own",
    },
    # Same self-registration path as teacher. Entirely read-only - a
    # student has no write permission anywhere in this app.
    UserRole.STUDENT: {
        "timeslots:view_self",
        "grades:view_self",
        "report_card:view_self",
        "attendance:view_self",
        "fees:view_self",
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