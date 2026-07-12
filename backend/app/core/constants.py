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


class BookingType:
    TRANSPORT = "transport"
    HOTEL = "hotel"
    EVENT = "event"


class PaymentStatus:
    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"