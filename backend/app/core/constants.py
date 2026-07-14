from enum import Enum


class UserRole(str, Enum):
    PASSENGER = "passenger"
    COMPANY_OWNER = "company_owner"
    DRIVER = "driver"
    HOTEL_OWNER = "hotel_owner"
    EVENT_ORGANIZER = "event_organizer"
    SCHOOL_ADMINISTRATOR = "school_administrator"
    STORE_MANAGER = "store_manager"
    SYSTEM_ADMINISTRATOR = "system_administrator"


# Roles that self-register via POST /auth/register-partner and require
# admin validation (is_active=False) before they can log in.
PARTNER_ROLES = {
    UserRole.COMPANY_OWNER,
    UserRole.HOTEL_OWNER,
    UserRole.EVENT_ORGANIZER,
    UserRole.STORE_MANAGER,
}

# school_administrator doesn't go through the generic register-partner
# form - a private institution needs an Institution created atomically
# alongside the account, not just a bare user profile, so it has its own
# POST /auth/register-institution instead (see education/institutions/
# service.py). It still needs the same admin validation gate as
# PARTNER_ROLES above, which is what this broader set is for - used by
# the pending-users list/activation flow, not by register-partner's
# role validator.
ADMIN_VALIDATED_ROLES = PARTNER_ROLES | {UserRole.SCHOOL_ADMINISTRATOR}


class BookingType:
    TRANSPORT = "transport"
    HOTEL = "hotel"
    EVENT = "event"


class PaymentStatus:
    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"