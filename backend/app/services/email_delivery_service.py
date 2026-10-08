from datetime import datetime, timedelta

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.time import utc_now
from app.models.account import UserPreference
from app.models.email_delivery import EmailDelivery
from app.models.notification import Notification
from app.services.email_templates import render_email_html
from app.services.email_provider import (
    EmailFailureKind,
    EmailProvider,
    EmailProviderError,
    OutgoingEmail,
    SmtpEmailProvider,
    enforce_test_recipient,
)


MAX_EMAIL_ATTEMPTS = 5
PROCESSING_LEASE = timedelta(minutes=5)


def _message_id(delivery: EmailDelivery) -> str:
    sender = settings.NOTIFICATION_EMAIL_FROM or "noreply@enactspace.local"
    domain = sender.rsplit("@", 1)[-1] if "@" in sender else "enactspace.local"
    return f"<{delivery.id}@{domain}>"


def enqueue_email_delivery(
    db: Session,
    *,
    recipient_email: str,
    subject: str,
    text_body: str,
    html_body: str | None = None,
    user_id=None,
    notification_id=None,
    dedupe_key: str | None = None,
) -> EmailDelivery | None:
    if not settings.email_enabled or not settings.SMTP_HOST:
        return None
    original_recipient = recipient_email.strip().lower()
    if not original_recipient:
        return None
    normalized_email = original_recipient
    delivery_subject = subject.strip()
    if settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT:
        normalized_email = (settings.EMAIL_TEST_RECIPIENT or "").strip().lower()
        if not normalized_email:
            return None
        delivery_subject = f"[TEST] {delivery_subject}"
        text_body = (
            "MODE DE TEST ENACTSPACE\n"
            f"Destinataire initial : {original_recipient}\n\n"
            f"{text_body}"
        )
    if dedupe_key:
        existing = db.query(EmailDelivery).filter(
            EmailDelivery.dedupe_key == dedupe_key
        ).first()
        if existing is not None:
            return existing
    delivery = EmailDelivery(
        notification_id=notification_id,
        user_id=user_id,
        recipient_email=normalized_email,
        subject=delivery_subject[:255],
        text_body=text_body,
        html_body=html_body if html_body is not None else render_email_html(subject, text_body),
        dedupe_key=dedupe_key,
    )
    db.add(delivery)
    return delivery


def enqueue_notification_email(
    db: Session,
    notification: Notification,
    recipient_email: str,
    *,
    user_id=None,
) -> EmailDelivery | None:
    db.flush()
    return enqueue_email_delivery(
        db,
        recipient_email=recipient_email,
        subject=notification.title,
        text_body=notification.message,
        user_id=user_id,
        notification_id=notification.id,
        dedupe_key=f"notification:{notification.id}",
    )


def claim_email_deliveries(
    db: Session,
    *,
    limit: int = 25,
    now: datetime | None = None,
) -> list:
    now = now or utc_now()
    expired_before = now - PROCESSING_LEASE
    query = db.query(EmailDelivery).filter(
        or_(
            and_(
                EmailDelivery.status.in_(("pending", "retry")),
                EmailDelivery.next_attempt_at <= now,
            ),
            and_(
                EmailDelivery.status == "processing",
                EmailDelivery.processing_started_at <= expired_before,
            ),
        )
    ).order_by(EmailDelivery.next_attempt_at, EmailDelivery.created_at)
    rows = query.with_for_update(skip_locked=True).limit(limit).all()
    for row in rows:
        row.status = "processing"
        row.processing_started_at = now
        row.updated_at = now
    db.commit()
    return [row.id for row in rows]


def _retry(delivery: EmailDelivery, code: str) -> None:
    delivery.last_error_code = code[:120]
    delivery.processing_started_at = None
    if delivery.attempt_count >= MAX_EMAIL_ATTEMPTS:
        delivery.status = "dead"
        return
    delivery.status = "retry"
    delivery.next_attempt_at = utc_now() + timedelta(
        seconds=min(3600, 30 * (2 ** max(0, delivery.attempt_count - 1)))
    )


def _notification_delivery_still_allowed(
    db: Session,
    delivery: EmailDelivery,
) -> bool:
    if delivery.notification_id is None:
        return True
    notification = db.query(Notification).filter(
        Notification.id == delivery.notification_id
    ).first()
    if notification is None:
        return False
    preference = db.query(UserPreference).filter(
        UserPreference.user_id == notification.user_id
    ).first()
    return bool(
        preference is None or preference.notification_email_enabled
    )


def process_email_delivery(
    db: Session,
    delivery_id,
    provider: EmailProvider,
) -> str:
    delivery = db.query(EmailDelivery).filter(
        EmailDelivery.id == delivery_id
    ).first()
    if delivery is None or delivery.status != "processing":
        db.rollback()
        return "ignored"
    if not settings.email_enabled or not _notification_delivery_still_allowed(db, delivery):
        delivery.status = "cancelled"
        delivery.processing_started_at = None
        delivery.updated_at = utc_now()
        db.commit()
        return "cancelled"

    delivery.attempt_count += 1
    message = OutgoingEmail(
        recipient=delivery.recipient_email,
        subject=delivery.subject,
        text_body=delivery.text_body,
        html_body=delivery.html_body,
        message_id=_message_id(delivery),
    )
    try:
        message = enforce_test_recipient(message)
        delivery.recipient_email = message.recipient
        delivery.subject = message.subject
        delivery.text_body = message.text_body
        delivery.html_body = message.html_body
        delivery.provider_message_id = provider.send(message)[:255]
        delivery.status = "sent"
        delivery.processing_started_at = None
        delivery.last_error_code = None
        delivery.sent_at = utc_now()
    except EmailProviderError as error:
        if error.kind == EmailFailureKind.permanent:
            delivery.status = "dead"
            delivery.processing_started_at = None
            delivery.last_error_code = error.code[:120]
        else:
            _retry(delivery, error.code)
    delivery.updated_at = utc_now()
    db.commit()
    return delivery.status


def drain_email_deliveries(
    db: Session,
    *,
    provider: EmailProvider | None = None,
    limit: int = 25,
) -> int:
    delivery_ids = claim_email_deliveries(db, limit=limit)
    if not delivery_ids:
        return 0
    try:
        selected_provider = provider or SmtpEmailProvider()
    except EmailProviderError as error:
        failure_kind = error.kind
        failure_code = error.code

        class UnavailableProvider(EmailProvider):
            def send(self, message: OutgoingEmail) -> str:
                del message
                raise EmailProviderError(failure_kind, failure_code)

        selected_provider = UnavailableProvider()
    for delivery_id in delivery_ids:
        process_email_delivery(db, delivery_id, selected_provider)
    return len(delivery_ids)
