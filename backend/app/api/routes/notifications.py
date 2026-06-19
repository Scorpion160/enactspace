from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.database import get_db
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import (
    NotificationCreate,
    BulkNotificationCreate,
    NotificationRead,
    NotificationCountRead,
)
from app.api.deps import get_current_user, require_enacchef_or_admin


router = APIRouter(prefix="/notifications", tags=["Notifications"])


VALID_NOTIFICATION_TYPES = {
    "task_assigned",
    "task_updated",
    "task_validated",
    "deadline_near",
    "task_late",
    "new_announcement",
    "event_scheduled",
    "absence_recorded",
    "fee_due",
    "payment_validated",
    "application_received",
    "recruitment_update",
    "account_approved",
    "account_rejected",
    "role_assigned",
    "document_shared",
    "mentorship_assigned",
    "general",
}


def get_notification_or_404(db: Session, notification_id: str) -> Notification:
    notification = db.query(Notification).filter(
        Notification.id == notification_id
    ).first()

    if not notification:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notification introuvable",
        )

    return notification


def create_notification_object(
    user_id,
    title: str,
    message: str,
    type: str | None = None,
    related_type: str | None = None,
    related_id=None,
) -> Notification:
    return Notification(
        user_id=user_id,
        title=title,
        message=message,
        type=type,
        related_type=related_type,
        related_id=related_id,
    )


@router.post("/", response_model=NotificationRead)
def create_notification(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    if payload.type and payload.type not in VALID_NOTIFICATION_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de notification invalide",
        )

    notification = create_notification_object(
        user_id=payload.user_id,
        title=payload.title,
        message=payload.message,
        type=payload.type,
        related_type=payload.related_type,
        related_id=payload.related_id,
    )

    db.add(notification)
    db.commit()
    db.refresh(notification)

    return notification


@router.post("/bulk", response_model=list[NotificationRead])
def create_bulk_notifications(
    payload: BulkNotificationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    if payload.type and payload.type not in VALID_NOTIFICATION_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de notification invalide",
        )

    notifications = []

    for user_id in payload.user_ids:
        notification = create_notification_object(
            user_id=user_id,
            title=payload.title,
            message=payload.message,
            type=payload.type,
            related_type=payload.related_type,
            related_id=payload.related_id,
        )
        db.add(notification)
        notifications.append(notification)

    db.commit()

    for notification in notifications:
        db.refresh(notification)

    return notifications


@router.get("/", response_model=list[NotificationRead])
def list_my_notifications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    unread_only: bool | None = Query(default=None),
    type_filter: str | None = Query(default=None),
):
    query = db.query(Notification).filter(
        Notification.user_id == current_user.id
    )

    if unread_only is True:
        query = query.filter(Notification.is_read == False)

    if type_filter:
        query = query.filter(Notification.type == type_filter)

    return query.order_by(Notification.created_at.desc()).all()


@router.get("/unread-count", response_model=NotificationCountRead)
def get_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    count = db.query(func.count(Notification.id)).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False,
    ).scalar() or 0

    return NotificationCountRead(unread_count=count)


@router.post("/{notification_id}/read", response_model=NotificationRead)
def mark_notification_as_read(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = get_notification_or_404(db, notification_id)

    if notification.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas modifier cette notification",
        )

    notification.is_read = True
    notification.read_at = datetime.utcnow()

    db.commit()
    db.refresh(notification)

    return notification


@router.post("/read-all")
def mark_all_notifications_as_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notifications = db.query(Notification).filter(
        Notification.user_id == current_user.id,
        Notification.is_read == False,
    ).all()

    now = datetime.utcnow()

    for notification in notifications:
        notification.is_read = True
        notification.read_at = now

    db.commit()

    return {
        "ok": True,
        "message": "Toutes les notifications ont été marquées comme lues",
        "updated": len(notifications),
    }


@router.delete("/{notification_id}")
def delete_notification(
    notification_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    notification = get_notification_or_404(db, notification_id)

    if notification.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas supprimer cette notification",
        )

    db.delete(notification)
    db.commit()

    return {
        "ok": True,
        "message": "Notification supprimée",
    }
