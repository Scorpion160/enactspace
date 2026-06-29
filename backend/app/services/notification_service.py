from collections.abc import Iterable
from datetime import datetime

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.notification import Notification


def create_notification(
    db: Session,
    *,
    recipient_id=None,
    user_id=None,
    title: str,
    body: str | None = None,
    message: str | None = None,
    type: str | None = None,
    notification_type: str | None = None,
    category: str | None = None,
    entity_type: str | None = None,
    entity_id=None,
    related_type: str | None = None,
    related_id=None,
    priority: str | None = None,
    created_by_id=None,
    metadata: dict | None = None,
    dedupe: bool = True,
) -> Notification:
    recipient = recipient_id or user_id
    if recipient is None:
        raise ValueError("recipient_id or user_id is required")

    normalized_type = type or notification_type or category or "general"
    normalized_related_type = entity_type or related_type
    normalized_related_id = entity_id or related_id
    normalized_message = body if body is not None else message
    if normalized_message is None:
        normalized_message = ""

    if dedupe:
        query = db.query(Notification).filter(
            Notification.user_id == recipient,
            Notification.is_read.is_(False),
            Notification.type == normalized_type,
            Notification.related_type == normalized_related_type,
            Notification.related_id == normalized_related_id,
        )
        if normalized_related_id is None:
            query = query.filter(Notification.title == title)
        existing = query.order_by(Notification.created_at.desc()).first()
        if existing:
            return existing

    notification = Notification(
        user_id=recipient,
        title=title,
        message=normalized_message,
        type=normalized_type,
        related_type=normalized_related_type,
        related_id=normalized_related_id,
    )
    db.add(notification)
    return notification


def create_notifications(
    db: Session,
    *,
    recipient_ids: Iterable | None = None,
    user_ids: Iterable | None = None,
    title: str,
    body: str | None = None,
    message: str | None = None,
    type: str | None = None,
    notification_type: str | None = None,
    category: str | None = None,
    entity_type: str | None = None,
    entity_id=None,
    related_type: str | None = None,
    related_id=None,
    priority: str | None = None,
    created_by_id=None,
    metadata: dict | None = None,
    dedupe: bool = True,
) -> list[Notification]:
    notifications = []
    recipients = recipient_ids if recipient_ids is not None else user_ids
    for recipient_id in dict.fromkeys(recipients or []):
        notifications.append(
            create_notification(
                db,
                recipient_id=recipient_id,
                title=title,
                body=body,
                message=message,
                type=type,
                notification_type=notification_type,
                category=category,
                entity_type=entity_type,
                entity_id=entity_id,
                related_type=related_type,
                related_id=related_id,
                priority=priority,
                created_by_id=created_by_id,
                metadata=metadata,
                dedupe=dedupe,
            )
        )
    return notifications


def notify_user(db: Session, **kwargs) -> Notification:
    return create_notification(db, **kwargs)


def notify_users(db: Session, **kwargs) -> list[Notification]:
    return create_notifications(db, **kwargs)


def mark_read(db: Session, notification: Notification) -> Notification:
    notification.is_read = True
    notification.read_at = datetime.utcnow()
    return notification


def mark_unread(db: Session, notification: Notification) -> Notification:
    notification.is_read = False
    notification.read_at = None
    return notification


def mark_all_read(db: Session, *, user_id) -> int:
    notifications = db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read.is_(False),
    ).all()
    now = datetime.utcnow()
    for notification in notifications:
        notification.is_read = True
        notification.read_at = now
    return len(notifications)


def unread_count(db: Session, *, user_id) -> int:
    return int(
        db.query(func.count(Notification.id))
        .filter(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        .scalar()
        or 0
    )
