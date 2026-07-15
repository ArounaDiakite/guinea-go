from fastapi import HTTPException

from app.common.base_model import BaseDocument
from app.core.permissions import ensure_owner
from app.notifications.repository import NotificationRepository

# type -> (title, message-template) rendered from whatever `data` the
# caller passes. Centralizing copy here means callers just report facts
# (send(user_id, "booking_confirmed", {"amount": ..., "currency": ...}))
# instead of every module hand-formatting its own notification text.
# Falls back to a generic message for any type not listed here, so a
# new module can start sending a new notification type immediately
# without having to touch this file first (see NotificationResponse's
# `type` field docstring - it's deliberately not a closed enum).
_TEMPLATES = {
    "booking_confirmed": lambda data: (
        "Réservation confirmée",
        (
            f"Votre paiement de {data.get('amount')} {data.get('currency', 'GNF')} "
            f"a été confirmé et votre réservation est validée."
        ),
    ),
    "fee_payment_received": lambda data: (
        "Paiement de frais reçu",
        (
            f"Un paiement de {data.get('amount')} {data.get('currency', 'GNF')} a été "
            f"reçu pour {data.get('student_name', 'un élève')}. "
            f"Solde restant : {data.get('remaining')} ({data.get('status')})."
        ),
    ),
    "account_activated": lambda data: (
        "Compte activé",
        "Votre compte partenaire a été validé par un administrateur. Vous pouvez maintenant vous connecter.",
    ),
    "review_received": lambda data: (
        "Nouvel avis reçu",
        f"Vous avez reçu un nouvel avis ({data.get('rating')}/5) sur votre {data.get('target_type', 'ressource')}.",
    ),
}


class NotificationService:
    def __init__(self):
        self.repository = NotificationRepository()

    async def send(self, user_id: str, notification_type: str, data: dict | None = None):
        """Internal call, not an HTTP endpoint - other modules' services
        call this directly (see payments/service.py, admin/service.py,
        reviews/service.py) to record an in-app notification. Never lets
        a notification failure break the caller's actual operation (a
        confirmed payment, an activated account, a saved review must
        still succeed even if this insert somehow fails) - swallows and
        logs instead of raising."""
        data = data or {}
        render = _TEMPLATES.get(notification_type)

        if render:
            title, message = render(data)
        else:
            title, message = notification_type.replace("_", " ").title(), "Vous avez une nouvelle notification."

        notification = {
            "user_id": user_id,
            "type": notification_type,
            "title": title,
            "message": message,
            "data": data,
            "channel": "in_app",
            "is_read": False,
        }
        notification.update(BaseDocument.create())

        try:
            return await self.repository.create(notification)
        except Exception as error:
            print(f"⚠️ Failed to send notification ({notification_type}) to {user_id}: {error}")
            return None

    async def get_my_notifications(self, user_id: str, page: int, limit: int):
        notifications = await self.repository.get_by_user(user_id, page, limit)
        return [self._format(notification) for notification in notifications]

    async def mark_as_read(self, notification_id: str, user_id: str):
        notification = await self.repository.get_by_id(notification_id)

        if not notification:
            raise HTTPException(status_code=404, detail="Notification not found.")

        ensure_owner(notification["user_id"], user_id)

        updated = await self.repository.update(
            notification_id, {"is_read": True, **BaseDocument.update()}
        )
        return self._format(updated)

    def _format(self, notification):
        return {
            "id": str(notification["_id"]),
            "user_id": notification["user_id"],
            "type": notification["type"],
            "title": notification["title"],
            "message": notification["message"],
            "data": notification.get("data", {}),
            "channel": notification.get("channel", "in_app"),
            "is_read": notification["is_read"],
            "created_at": notification.get("created_at"),
        }
