import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token, decode_access_token_payload
from app.models.account import AuthSession
from app.models.user import User


def hash_refresh_token(token: str) -> str:
    return hmac.new(
        settings.refresh_token_hmac_key.encode("utf-8"),
        token.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def _new_refresh_token() -> str:
    return secrets.token_urlsafe(64)


def utc_now() -> datetime:
    # PR-2A stores UTC in timestamp-without-time-zone columns on both databases.
    return datetime.now(timezone.utc).replace(tzinfo=None)


def session_seconds_remaining(auth_session: AuthSession) -> int:
    expiry = auth_session.expires_at
    if expiry.tzinfo is None:
        expiry = expiry.replace(tzinfo=timezone.utc)
    return max(0, int((expiry - datetime.now(timezone.utc)).total_seconds()))


def _invalid_session() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Session invalide ou expirée",
    )


def _lock_user(db: Session, user_id) -> User | None:
    return (
        db.query(User)
        .filter(User.id == user_id)
        .populate_existing()
        .with_for_update()
        .first()
    )


def _eligible(user: User | None) -> bool:
    return bool(
        user is not None
        and user.is_active
        and user.email_verified
        and user.status in {"active", "alumni"}
    )


def create_session_tokens(
    db: Session,
    user: User,
    *,
    user_agent: str | None = None,
    platform: str | None = None,
) -> tuple[AuthSession, str, str]:
    # Login, rotation and logout-all lock the user before any session row.
    if not _eligible(_lock_user(db, user.id)):
        raise _invalid_session()
    refresh_token = _new_refresh_token()
    auth_session = AuthSession(
        user_id=user.id,
        refresh_token_hash=hash_refresh_token(refresh_token),
        expires_at=utc_now() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        user_agent=(user_agent or "")[:255] or None,
        platform=platform or "unknown",
    )
    db.add(auth_session)
    db.flush()
    access_token = create_access_token(str(user.id), session_id=str(auth_session.id))
    return auth_session, access_token, refresh_token


def rotate_refresh_token(
    db: Session,
    refresh_token: str,
) -> tuple[AuthSession, str, str]:
    token_hash = hash_refresh_token(refresh_token)
    user_id = (
        db.query(AuthSession.user_id)
        .filter(AuthSession.refresh_token_hash == token_hash)
        .scalar()
    )
    if user_id is None or not _eligible(_lock_user(db, user_id)):
        raise _invalid_session()

    # Held until the route commits. PostgreSQL rechecks the hash after a waiter
    # acquires the lock: one credential can produce exactly one committed pair,
    # even across workers. Refresh ORM state as well as the database snapshot.
    auth_session = (
        db.query(AuthSession)
        .filter(AuthSession.refresh_token_hash == token_hash)
        .populate_existing()
        .with_for_update()
        .first()
    )
    if (
        auth_session is None
        or auth_session.revoked_at is not None
        or session_seconds_remaining(auth_session) <= 0
    ):
        raise _invalid_session()

    next_refresh_token = _new_refresh_token()
    auth_session.refresh_token_hash = hash_refresh_token(next_refresh_token)
    auth_session.last_used_at = utc_now()
    access_token = create_access_token(str(user_id), session_id=str(auth_session.id))
    db.flush()
    return auth_session, access_token, next_refresh_token


def revoke_user_sessions(db: Session, user_id, *, except_session_id=None) -> int:
    # Select only the ID so pending password/account changes are not overwritten.
    db.query(User.id).filter(User.id == user_id).with_for_update().first()
    query = db.query(AuthSession).filter(
        AuthSession.user_id == user_id,
        AuthSession.revoked_at.is_(None),
    )
    if except_session_id is not None:
        query = query.filter(AuthSession.id != except_session_id)
    return query.update({AuthSession.revoked_at: utc_now()}, synchronize_session="fetch")


def revoke_current_session(
    db: Session, refresh_token: str, *, access_token: str | None = None,
) -> AuthSession | None:
    payload = decode_access_token_payload(access_token) if access_token else None
    query = db.query(AuthSession)
    if payload and payload.get("sid") and payload.get("sub"):
        # A valid access JWT identifies the same session even during rotation.
        query = query.filter(
            AuthSession.id == payload["sid"], AuthSession.user_id == payload["sub"],
        )
    else:
        query = query.filter(
            AuthSession.refresh_token_hash == hash_refresh_token(refresh_token),
        )
    user_id = query.with_entities(AuthSession.user_id).scalar()
    if user_id is None:
        return None
    # Preserve user -> session lock order, including the audit insert's user FK.
    db.query(User.id).filter(User.id == user_id).with_for_update().first()
    auth_session = query.populate_existing().with_for_update().first()
    if auth_session is None or auth_session.revoked_at is not None:
        return None
    auth_session.revoked_at = utc_now()
    return auth_session
