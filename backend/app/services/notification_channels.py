import logging

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.user import User
from app.services.push_lifecycle import enqueue_push_deliveries


logger = logging.getLogger("enactspace.notifications")


def dispatch_notification_channels(
    db: Session,
    notification: Notification,
    recipient: User | None,
    preference: UserPreference | None = None,
) -> dict[str, bool]:
    """Prepare external delivery without making network calls by default."""
    return {
        "email": _dispatch_email(notification, recipient, preference),
        "push": bool(
            recipient is not None
            and enqueue_push_deliveries(db, notification, preference)
        ),
    }


def _dispatch_email(
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

    if not settings.SMTP_HOST:
        logger.warning("Notification email enabled but SMTP_HOST is not set")
        return False

    logger.info(
        "Notification email queued for user %s: %s",
        recipient.id,
        notification.title,
    )
    return True


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
