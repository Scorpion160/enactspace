from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session

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
from app.services.notification_service import (
    create_notification as create_notification_entry,
    create_notifications,
    mark_all_read,
    mark_read,
    mark_unread,
    unread_count,
)


router = APIRouter(prefix="/notifications", tags=["Notifications"])


VALID_NOTIFICATION_TYPES = {
    "task_assigned",
    "task_updated",
    "task_validated",
    "task_due_soon",
    "deadline_near",
    "task_late",
    "new_announcement",
    "post_comment",
    "post_reaction",
    "post_mention",
    "comment_mention",
    "official_post",
    "event_created",
    "event_scheduled",
    "attendance_absent",
    "attendance_late",
    "absence_recorded",
    "finance_fee",
    "finance_penalty",
    "fee_due",
    "payment_validated",
    "payment_submitted",
    "payment_cancelled",
    "application_received",
    "recruitment_status",
    "recruitment_update",
    "account_approved",
    "account_rejected",
    "role_assigned",
    "document_shared",
    "document_submitted",
    "document_validated",
    "document_rejected",
    "mentorship_assigned",
    "academy_completed",
    "quiz_passed",
    "badge_awarded",
    "chat_message",
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

    notification = create_notification_entry(
        db,
        user_id=payload.user_id,
        title=payload.title,
        body=payload.body,
        message=payload.message,
        notification_type=payload.type,
        category=payload.category,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        related_type=payload.related_type,
        related_id=payload.related_id,
        priority=payload.priority,
        created_by_id=payload.created_by_id or current_user.id,
        metadata=payload.metadata,
    )

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

    notifications = create_notifications(
        db,
        user_ids=payload.user_ids,
        title=payload.title,
        body=payload.body,
        message=payload.message,
        notification_type=payload.type,
        category=payload.category,
        entity_type=payload.entity_type,
        entity_id=payload.entity_id,
        related_type=payload.related_type,
        related_id=payload.related_id,
        priority=payload.priority,
        created_by_id=payload.created_by_id or current_user.id,
        metadata=payload.metadata,
    )

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
    return NotificationCountRead(unread_count=unread_count(db, user_id=current_user.id))


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

    mark_read(db, notification)

    db.commit()
    db.refresh(notification)

    return notification


@router.post("/{notification_id}/unread", response_model=NotificationRead)
def mark_notification_as_unread(
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

    mark_unread(db, notification)

    db.commit()
    db.refresh(notification)

    return notification


@router.post("/read-all")
def mark_all_notifications_as_read(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    updated = mark_all_read(db, user_id=current_user.id)

    db.commit()

    return {
        "ok": True,
        "message": "Toutes les notifications ont été marquées comme lues",
        "updated": updated,
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
