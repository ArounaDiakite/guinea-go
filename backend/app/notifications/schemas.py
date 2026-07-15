from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    id: str
    user_id: str
    # Free string, not an enum - deliberately open-ended so any module
    # can send a new notification type without editing a shared enum
    # here every time (same reasoning as FeeSchedule.period). Known
    # values in use today: booking_confirmed, fee_payment_received,
    # account_activated, review_received.
    type: str
    title: str
    message: str
    data: dict = {}
    # Always "in_app" for now - no real SMS/email/push provider exists
    # yet (see notifications/email.py, sms.py, whatsapp.py), same
    # sandbox-only stance as payments until real provider credentials
    # exist.
    channel: str = "in_app"
    is_read: bool
    created_at: Optional[datetime] = None
