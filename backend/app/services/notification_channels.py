import logging

from app.core.config import settings
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.user import User


logger = logging.getLogger("enactspace.notifications")


def dispatch_notification_channels(
    notification: Notification,
    recipient: User | None,
    preference: UserPreference | None = None,
) -> dict[str, bool]:
    """Prepare external delivery without making network calls by default."""
    return {
        "email": _dispatch_email(notification, recipient, preference),
        "push": _dispatch_push(notification, recipient, preference),
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
    if (
        not settings.push_enabled
        or preference is None
        or not preference.notification_push_enabled
    ):
        return False

    if not recipient:
        logger.info("Notification push skipped: recipient missing")
        return False

    if not settings.FCM_SERVER_KEY:
        logger.warning("Notification push enabled but FCM_SERVER_KEY is not set")
        return False

    logger.info(
        "Notification push queued for user %s: %s",
        recipient.id,
        notification.title,
    )
    return True
