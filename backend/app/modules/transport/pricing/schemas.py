from app.modules.transport.seats.schemas import SeatType

# Simple static multiplier per seat type, applied to a trip's base price.
# No demand/time-based dynamic pricing yet - that's a later iteration.
SEAT_TYPE_MULTIPLIERS: dict[str, float] = {
    SeatType.WINDOW.value: 1.10,
    SeatType.AISLE.value: 1.0,
    SeatType.STANDARD.value: 1.0,
}
