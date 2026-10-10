from dataclasses import dataclass, replace
from email.message import EmailMessage
from enum import Enum
import smtplib
import ssl

from pydantic import EmailStr, TypeAdapter, ValidationError

from app.core.config import settings
from app.services.email_templates import render_email_html


class EmailFailureKind(str, Enum):
    permanent = "permanent"
    transient = "transient"
    unavailable = "unavailable"


class EmailProviderError(RuntimeError):
    def __init__(self, kind: EmailFailureKind, code: str):
        super().__init__(code)
        self.kind = kind
        self.code = code


@dataclass(frozen=True)
class OutgoingEmail:
    recipient: str
    subject: str
    text_body: str
    html_body: str | None
    message_id: str


def enforce_test_recipient(message: OutgoingEmail) -> OutgoingEmail:
    """Contain even old queued messages and direct SMTP calls in test mode."""
    if not settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT:
        return message
    try:
        recipient = str(TypeAdapter(EmailStr).validate_python(
            (settings.EMAIL_TEST_RECIPIENT or "").strip()
        )).lower()
    except ValidationError as error:
        raise EmailProviderError(
            EmailFailureKind.permanent, "test_recipient_invalid"
        ) from error
    subject = message.subject
    if not subject.startswith("[TEST] "):
        subject = "[TEST] " + subject
    body = message.text_body
    if not body.startswith("MODE DE TEST ENACTSPACE\n"):
        body = ("MODE DE TEST ENACTSPACE\n"
                f"Destinataire initial : {message.recipient}\n\n{body}")
    return replace(message, recipient=recipient, subject=subject[:255],
                   text_body=body, html_body=render_email_html(subject, body))


class EmailProvider:
    def send(self, message: OutgoingEmail) -> str:
        raise NotImplementedError


class SmtpEmailProvider(EmailProvider):
    def __init__(self) -> None:
        if not settings.SMTP_HOST:
            raise EmailProviderError(
                EmailFailureKind.unavailable,
                "smtp_not_configured",
            )

    def send(self, message: OutgoingEmail) -> str:
        message = enforce_test_recipient(message)
        envelope = EmailMessage()
        envelope["From"] = settings.NOTIFICATION_EMAIL_FROM
        envelope["To"] = message.recipient
        envelope["Subject"] = message.subject
        envelope["Message-ID"] = message.message_id
        envelope.set_content(message.text_body)
        if message.html_body:
            envelope.add_alternative(message.html_body, subtype="html")

        timeout = max(1, int(settings.SMTP_TIMEOUT_SECONDS))
        context = ssl.create_default_context()
        client = None
        try:
            if settings.SMTP_USE_SSL:
                client = smtplib.SMTP_SSL(
                    settings.SMTP_HOST,
                    settings.SMTP_PORT,
                    timeout=timeout,
                    context=context,
                )
            else:
                client = smtplib.SMTP(
                    settings.SMTP_HOST,
                    settings.SMTP_PORT,
                    timeout=timeout,
                )
                client.ehlo()
                if settings.SMTP_USE_TLS:
                    client.starttls(context=context)
                    client.ehlo()

            if settings.SMTP_USERNAME:
                client.login(
                    settings.SMTP_USERNAME,
                    settings.SMTP_PASSWORD or "",
                )
            client.send_message(envelope)
            return message.message_id
        except smtplib.SMTPRecipientsRefused as error:
            raise EmailProviderError(
                EmailFailureKind.permanent,
                "recipient_rejected",
            ) from error
        except smtplib.SMTPAuthenticationError as error:
            raise EmailProviderError(
                EmailFailureKind.unavailable,
                "smtp_auth_failed",
            ) from error
        except (smtplib.SMTPServerDisconnected, TimeoutError, OSError) as error:
            raise EmailProviderError(
                EmailFailureKind.transient,
                "smtp_unavailable",
            ) from error
        except smtplib.SMTPException as error:
            raise EmailProviderError(
                EmailFailureKind.transient,
                "smtp_send_failed",
            ) from error
        finally:
            if client is not None:
                try:
                    client.quit()
                except Exception:
                    pass
