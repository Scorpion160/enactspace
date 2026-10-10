import logging

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.user import User
from app.services.email_delivery_service import enqueue_notification_email
from app.services.push_lifecycle import enqueue_push_deliveries


logger = logging.getLogger("enactspace.notifications")


def dispatch_notification_channels(
    db: Session,
    notification: Notification,
    recipient: User | None,
    preference: UserPreference | None = None,
    *, send_email: bool = True,
) -> dict[str, bool]:
    """Prepare durable external deliveries without making network calls."""
    return {
        "email": send_email and _dispatch_email(db, notification, recipient, preference),
        "push": bool(
            recipient is not None
            and enqueue_push_deliveries(db, notification, preference)
        ),
    }


def _dispatch_email(
    db: Session,
    notification: Notification,
    recipient: User | None,
    preference: UserPreference | None = None,
) -> bool:
    if not settings.email_enabled or (
        preference is not None and not preference.notification_email_enabled
    ):
        return False
    if not recipient or not recipient.email:
        logger.info("Notification email skipped: recipient email missing")
        return False
    delivery = enqueue_notification_email(
        db,
        notification,
        recipient.email,
        user_id=recipient.id,
    )
    return delivery is not None


def _dispatch_push(
    notification: Notification,
    recipient: User | None,
    preference: UserPreference | None = None,
) -> bool:
    """Compatibility eligibility helper; delivery is handled only by the outbox."""
    return bool(
        settings.push_enabled
        and recipient is not None
        and preference is not None
        and preference.notification_push_enabled
    )
