from app.modules.transport.pricing.schemas import SEAT_TYPE_MULTIPLIERS


class PricingService:
    def calculate_seat_price(self, base_price: float, seat_type: str) -> float:
        multiplier = SEAT_TYPE_MULTIPLIERS.get(seat_type, 1.0)
        return round(base_price * multiplier, 2)
