from collections.abc import Iterable

from sqlalchemy.orm import Session

from app.models.notification import Notification


def notify_user(
    db: Session,
    *,
    user_id,
    title: str,
    message: str,
    notification_type: str,
    related_type: str | None = None,
    related_id=None,
) -> Notification:
    notification = Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=notification_type,
        related_type=related_type,
        related_id=related_id,
    )
    db.add(notification)
    return notification


def notify_users(
    db: Session,
    *,
    user_ids: Iterable,
    title: str,
    message: str,
    notification_type: str,
    related_type: str | None = None,
    related_id=None,
) -> list[Notification]:
    notifications = []
    for user_id in dict.fromkeys(user_ids):
        notifications.append(
            notify_user(
                db,
                user_id=user_id,
                title=title,
                message=message,
                notification_type=notification_type,
                related_type=related_type,
                related_id=related_id,
            )
        )
    return notifications
