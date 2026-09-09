from datetime import datetime, timedelta

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.account import UserPreference
from app.models.notification import Notification
from app.models.product_services import AppInstallation, PushDelivery
from app.services.push_lifecycle import cancel_unsent_deliveries, clear_installation_push
from app.services.push_locking import lock_push_delivery, lock_user_installation
from app.services.push_provider import (
    FirebaseAdminPushProvider,
    PushFailureKind,
    PushMessage,
    PushProvider,
    PushProviderError,
)
from app.services.push_tokens import PushTokenConfigurationError, decrypt_push_token


MAX_PUSH_ATTEMPTS = 5
PROCESSING_LEASE = timedelta(minutes=5)


def claim_push_deliveries(
    db: Session, *, limit: int = 25, now: datetime | None = None
) -> list:
    now = now or datetime.utcnow()
    expired_before = now - PROCESSING_LEASE
    query = db.query(PushDelivery).filter(
        or_(
            and_(
                PushDelivery.status.in_(("pending", "retry")),
                PushDelivery.next_attempt_at <= now,
            ),
            and_(
                PushDelivery.status == "processing",
                PushDelivery.processing_started_at <= expired_before,
            ),
        )
    ).order_by(PushDelivery.next_attempt_at, PushDelivery.created_at)
    query = query.with_for_update(skip_locked=True)
    rows = query.limit(limit).all()
    for row in rows:
        row.status = "processing"
        row.processing_started_at = now
        row.updated_at = now
    db.commit()
    return [row.id for row in rows]


def _safe_data(notification: Notification) -> dict[str, str]:
    return {
        "notification_id": str(notification.id),
        "type": notification.type or "general",
        "related_type": notification.related_type or "",
        "related_id": str(notification.related_id) if notification.related_id else "",
    }


def process_push_delivery(db: Session, delivery_id, provider: PushProvider) -> str:
    delivery = db.query(PushDelivery).filter(PushDelivery.id == delivery_id).first()
    if delivery is None or delivery.status != "processing":
        db.rollback()
        return "ignored"
    notification = db.query(Notification).filter(Notification.id == delivery.notification_id).first()
    if notification is None:
        delivery = lock_push_delivery(db, delivery_id)
        if delivery is None or delivery.status != "processing":
            db.rollback()
            return "ignored"
        delivery.status = "cancelled"
        delivery.processing_started_at = None
        delivery.updated_at = datetime.utcnow()
        db.commit()
        return "cancelled"

    # Processing shares the mutation lock order and holds the locks through
    # provider.send(). A completed disable/revoke/logout therefore fences any
    # send that has not already entered the provider call.
    installation = lock_user_installation(
        db, notification.user_id, delivery.installation_id
    )
    delivery = lock_push_delivery(db, delivery_id)
    if delivery is None or delivery.status != "processing":
        db.rollback()
        return "ignored"
    notification = db.query(Notification).filter(
        Notification.id == delivery.notification_id
    ).populate_existing().first()
    preference = db.query(UserPreference).filter(
        UserPreference.user_id == notification.user_id
    ).populate_existing().first() if notification else None
    valid = bool(
        settings.push_enabled
        and notification
        and installation
        and installation.user_id == notification.user_id
        and installation.revoked_at is None
        and preference
        and preference.notification_push_enabled
        and installation.push_provider == "fcm"
        and installation.push_token_ciphertext
        and installation.push_token_hash == delivery.token_hash_snapshot
    )
    if not valid:
        delivery.status = "cancelled"
        delivery.processing_started_at = None
        delivery.updated_at = datetime.utcnow()
        db.commit()
        return "cancelled"
    delivery.attempt_count += 1
    try:
        token = decrypt_push_token(installation.push_token_ciphertext)
        message_id = provider.send(PushMessage(
            token=token,
            title=notification.title,
            body=notification.message,
            data=_safe_data(notification),
        ))
        delivery.status = "sent"
        delivery.processing_started_at = None
        delivery.provider_message_id = message_id[:255]
        delivery.last_error_code = None
        delivery.sent_at = datetime.utcnow()
    except PushTokenConfigurationError:
        _retry(delivery, "token_decrypt_unavailable")
    except PushProviderError as error:
        if error.kind == PushFailureKind.invalid_token:
            clear_installation_push(db, installation)
            cancel_unsent_deliveries(db, token_hash=delivery.token_hash_snapshot)
            delivery.status = "dead"
            delivery.processing_started_at = None
            delivery.last_error_code = error.code
        else:
            _retry(delivery, error.code)
    delivery.updated_at = datetime.utcnow()
    db.commit()
    return delivery.status


def _retry(delivery: PushDelivery, code: str) -> None:
    delivery.last_error_code = code[:80]
    delivery.processing_started_at = None
    if delivery.attempt_count >= MAX_PUSH_ATTEMPTS:
        delivery.status = "dead"
        return
    delivery.status = "retry"
    delivery.next_attempt_at = datetime.utcnow() + timedelta(
        seconds=min(3600, 30 * (2 ** max(0, delivery.attempt_count - 1)))
    )


def drain_push_deliveries(db: Session, *, provider: PushProvider | None = None, limit: int = 25) -> int:
    delivery_ids = claim_push_deliveries(db, limit=limit)
    if not delivery_ids:
        return 0
    try:
        selected_provider = provider or FirebaseAdminPushProvider()
    except PushProviderError as error:
        failure_kind = error.kind
        failure_code = error.code

        class UnavailableProvider:
            def send(self, message):
                del message
                raise PushProviderError(failure_kind, failure_code)

        selected_provider = UnavailableProvider()
    for delivery_id in delivery_ids:
        process_push_delivery(db, delivery_id, selected_provider)
    return len(delivery_ids)
