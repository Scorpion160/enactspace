from datetime import datetime

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.product_services import AppInstallation, PushDelivery
from app.services.push_locking import lock_user_installations


UNSENT_PUSH_STATUSES = ("pending", "retry", "processing")


def cancel_unsent_deliveries(
    db: Session, *, installation_id=None, user_id=None, token_hash: str | None = None
) -> int:
    query = db.query(PushDelivery).filter(PushDelivery.status.in_(UNSENT_PUSH_STATUSES))
    if installation_id is not None:
        query = query.filter(PushDelivery.installation_id == installation_id)
    if user_id is not None:
        query = query.join(
            AppInstallation, AppInstallation.id == PushDelivery.installation_id
        ).filter(AppInstallation.user_id == user_id)
    if token_hash is not None:
        query = query.filter(PushDelivery.token_hash_snapshot == token_hash)
    now = datetime.utcnow()
    rows = query.order_by(PushDelivery.id).populate_existing().with_for_update().all()
    for delivery in rows:
        delivery.status = "cancelled"
        delivery.processing_started_at = None
        delivery.updated_at = now
    return len(rows)


def clear_installation_push(db: Session, installation: AppInstallation) -> int:
    cancelled = cancel_unsent_deliveries(
        db, installation_id=installation.id
    )
    installation.push_provider = None
    installation.push_token_ciphertext = None
    installation.push_token_hash = None
    installation.push_token_updated_at = None
    installation.updated_at = datetime.utcnow()
    return cancelled


def disable_user_push(db: Session, user_id, *, revoke: bool = False) -> tuple[int, int]:
    installations = lock_user_installations(db, user_id)
    cleared = 0
    revoked = 0
    cancelled = 0
    now = datetime.utcnow()
    for installation in installations:
        if installation.push_token_hash:
            cleared += 1
        cancelled += clear_installation_push(db, installation)
        if revoke and installation.revoked_at is None:
            installation.revoked_at = now
            revoked += 1
    return (revoked if revoke else cleared), cancelled


def enqueue_push_deliveries(
    db: Session,
    notification: Notification,
    preference: UserPreference | None,
) -> int:
    if not settings.push_enabled or preference is None:
        return 0
    # Preserve changes already made by the current transaction before the
    # lock refreshes database-backed state.
    db.flush()
    installations = lock_user_installations(db, notification.user_id)
    preference = db.query(UserPreference).filter(
        UserPreference.user_id == notification.user_id
    ).populate_existing().first()
    if preference is None or not preference.notification_push_enabled:
        return 0
    db.flush()
    queued = 0
    for installation in installations:
        if (
            installation.revoked_at is not None
            or installation.push_provider != "fcm"
            or installation.push_token_hash is None
            or installation.push_token_ciphertext is None
        ):
            continue
        exists = db.query(PushDelivery.id).filter(
            PushDelivery.notification_id == notification.id,
            PushDelivery.installation_id == installation.id,
            PushDelivery.token_hash_snapshot == installation.push_token_hash,
        ).first()
        if exists is None:
            db.add(PushDelivery(
                notification_id=notification.id,
                installation_id=installation.id,
                token_hash_snapshot=installation.push_token_hash,
            ))
            queued += 1
    return queued
