import hashlib
import hmac
import secrets
from datetime import datetime, timedelta

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token
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


def create_session_tokens(
    db: Session,
    user: User,
    *,
    user_agent: str | None = None,
    platform: str | None = None,
) -> tuple[AuthSession, str, str]:
    refresh_token = _new_refresh_token()
    auth_session = AuthSession(
        user_id=user.id,
        refresh_token_hash=hash_refresh_token(refresh_token),
        expires_at=datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
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
    now = datetime.utcnow()
    token_hash = hash_refresh_token(refresh_token)
    auth_session = (
        db.query(AuthSession)
        .filter(AuthSession.refresh_token_hash == token_hash)
        .with_for_update()
        .first()
    )
    if (
        auth_session is None
        or auth_session.revoked_at is not None
        or auth_session.expires_at <= now
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalide, expiré ou révoqué",
        )

    user = db.query(User).filter(User.id == auth_session.user_id).first()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session utilisateur indisponible",
        )

    next_refresh_token = _new_refresh_token()
    auth_session.refresh_token_hash = hash_refresh_token(next_refresh_token)
    auth_session.last_used_at = now
    access_token = create_access_token(str(user.id), session_id=str(auth_session.id))
    return auth_session, access_token, next_refresh_token


def revoke_user_sessions(db: Session, user_id, *, except_session_id=None) -> int:
    now = datetime.utcnow()
    query = db.query(AuthSession).filter(
        AuthSession.user_id == user_id,
        AuthSession.revoked_at.is_(None),
    )
    if except_session_id is not None:
        query = query.filter(AuthSession.id != except_session_id)
    sessions = query.all()
    for auth_session in sessions:
        auth_session.revoked_at = now
    return len(sessions)
