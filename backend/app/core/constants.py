class UserRole:
    CUSTOMER = "customer"
    COMPANY = "company"
    ADMIN = "admin"
    SUPER_ADMIN = "super_admin"


class BookingType:
    TRANSPORT = "transport"
    HOTEL = "hotel"
    EVENT = "event"


class PaymentStatus:
    PENDING = "pending"
    PAID = "paid"
    FAILED = "failed"
    REFUNDED = "refunded"