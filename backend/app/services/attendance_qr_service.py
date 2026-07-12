import base64
import hashlib
import hmac
import json
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any

from app.core.config import settings


TOKEN_VERSION = "v1"


class AttendanceQrTokenError(ValueError):
    pass


class AttendanceQrExpiredError(AttendanceQrTokenError):
    pass


class AttendanceQrInvalidError(AttendanceQrTokenError):
    pass


@dataclass(frozen=True)
class AttendanceQrPayload:
    session_id: str
    issued_at: datetime
    expires_at: datetime
    nonce: str
    version: str = TOKEN_VERSION

    def to_public_dict(self) -> dict[str, Any]:
        return {
            "session_id": self.session_id,
            "issued_at": self.issued_at.isoformat(),
            "expires_at": self.expires_at.isoformat(),
            "nonce": self.nonce,
            "version": self.version,
        }


def generate_attendance_qr_token(
    *,
    session_id: str,
    ttl_seconds: int | None = None,
    now: datetime | None = None,
) -> tuple[str, AttendanceQrPayload]:
    issued_at = now or datetime.utcnow()
    ttl = ttl_seconds or settings.ATTENDANCE_QR_TTL_SECONDS
    payload = AttendanceQrPayload(
        session_id=str(session_id),
        issued_at=issued_at,
        expires_at=issued_at + timedelta(seconds=ttl),
        nonce=secrets.token_urlsafe(16),
    )
    encoded_payload = _base64url_json(payload.to_public_dict())
    signature = _sign(encoded_payload)
    return f"{encoded_payload}.{signature}", payload


def validate_attendance_qr_token(
    token: str,
    *,
    now: datetime | None = None,
) -> AttendanceQrPayload:
    if not token or "." not in token:
        raise AttendanceQrInvalidError("invalid_token")

    encoded_payload, encoded_signature = token.split(".", 1)
    expected_signature = _sign(encoded_payload)
    if not hmac.compare_digest(encoded_signature, expected_signature):
        raise AttendanceQrInvalidError("invalid_token")

    try:
        raw_payload = _decode_base64url_json(encoded_payload)
        payload = AttendanceQrPayload(
            session_id=str(raw_payload["session_id"]),
            issued_at=datetime.fromisoformat(raw_payload["issued_at"]),
            expires_at=datetime.fromisoformat(raw_payload["expires_at"]),
            nonce=str(raw_payload["nonce"]),
            version=str(raw_payload.get("version", "")),
        )
    except (KeyError, TypeError, ValueError):
        raise AttendanceQrInvalidError("invalid_token") from None

    if payload.version != TOKEN_VERSION:
        raise AttendanceQrInvalidError("invalid_token")

    if (now or datetime.utcnow()) > payload.expires_at:
        raise AttendanceQrExpiredError("expired_token")

    return payload


def _sign(encoded_payload: str) -> str:
    digest = hmac.new(
        settings.attendance_qr_secret.encode("utf-8"),
        encoded_payload.encode("utf-8"),
        hashlib.sha256,
    ).digest()
    return _base64url(digest)


def _base64url_json(value: dict[str, Any]) -> str:
    raw = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")
    return _base64url(raw)


def _decode_base64url_json(value: str) -> dict[str, Any]:
    decoded = base64.urlsafe_b64decode(_pad_base64(value)).decode("utf-8")
    parsed = json.loads(decoded)
    if not isinstance(parsed, dict):
        raise ValueError("payload must be an object")
    return parsed


def _base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def _pad_base64(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return f"{value}{padding}".encode("ascii")
