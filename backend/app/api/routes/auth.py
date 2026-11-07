from app.services.request_rate_limit import protect_public_request
from app.core.time import utc_now
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.database import get_db
from app.models.user import User, PasswordResetOtp
from app.models.alumni import AlumniProfile
from app.schemas.auth import (
    LoginRequest,
    TokenResponse,
    RefreshTokenRequest,
    AuthSessionRead,
    PasswordResetRequest,
    PasswordResetConfirm,
    PasswordResetRequestRead,
    JoinRequestCreate,
    JoinRequestRead,
)
from app.core.security import (
    verify_password,
    hash_password,
)
from app.api.deps import get_current_active_validated_user
from app.models.account import AuthSession
from app.services.audit_service import create_audit_log
from app.services.email_delivery_service import enqueue_email_delivery
from app.services.session_service import (
    create_session_tokens,
    revoke_current_session,
    revoke_user_sessions,
    rotate_refresh_token,
    session_seconds_remaining,
    utc_now,
)


router = APIRouter(prefix="/auth", dependencies=[Depends(protect_public_request)], tags=["Authentification"])


def optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    stripped = value.strip()
    return stripped or None


def join_request_bio(payload: JoinRequestCreate) -> str | None:
    parts = [
        f"Compétences: {payload.skills.strip()}" if optional_text(payload.skills) else None,
        f"Motivation: {payload.motivation.strip()}" if optional_text(payload.motivation) else None,
    ]
    content = "\n\n".join(part for part in parts if part)
    return content or None


def normalize_login_identifier(identifier: str | None, email: str | None) -> str:
    raw = identifier if identifier is not None else email
    normalized = (raw or "").strip().lower()
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Identifiant requis.",
        )
    return normalized

def authenticate_user(
    password: str,
    db: Session,
    identifier: str | None = None,
    email: str | None = None,
) -> User:
    normalized_identifier = normalize_login_identifier(identifier, email)
    user = (
        db.query(User)
        .filter(or_(
            func.lower(User.email) == normalized_identifier,
            func.lower(User.username) == normalized_identifier,
        ))
        .populate_existing()
        .with_for_update()
        .first()
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiant ou mot de passe incorrect",
        )

    if not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiant ou mot de passe incorrect",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé",
        )

    if user.status == "pending" and user.profile_type == "alumni":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Compte alumni en attente de validation. "
                "Vous serez notifié après validation par un responsable."
            ),
        )

    if user.status == "pending":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte en attente de validation par la Secrétaire Générale",
        )

    if user.status == "rejected":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte refusé. Contactez les responsables Enactus ESP.",
        )

    if user.status == "suspended":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte suspendu. Contactez l'administration EnactSpace.",
        )

    if user.status == "inactive":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte non autorisé",
        )

    if user.credential_setup_required:
        raise HTTPException(403, "Activez votre accès avec Première connexion.")

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email non vérifié",
        )

    return user


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request, db: Session = Depends(get_db)):
    user = authenticate_user(
        identifier=payload.identifier,
        email=payload.email,
        password=payload.password,
        db=db,
    )

    _, access_token, refresh_token = create_session_tokens(
        db,
        user,
        user_agent=request.headers.get("user-agent"),
        platform=payload.platform,
    )
    db.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        refresh_expires_in=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
    )


@router.post("/join-requests", response_model=JoinRequestRead)
def create_join_request(
    payload: JoinRequestCreate,
    db: Session = Depends(get_db),
):
    profile_type = payload.profile_type.strip().lower()
    if profile_type not in {"enacteur", "alumni"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de profil invalide",
        )
    gender = (payload.gender or "").strip().lower()
    if gender not in {"homme", "femme"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Genre invalide",
        )
    if len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe doit contenir au moins 8 caractères",
        )

    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()
    username = payload.username.strip()
    phone = payload.phone.strip()
    department = optional_text(payload.department)
    promotion = optional_text(payload.promotion)
    if not first_name or not last_name or not department:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complétez au moins identité, email et filière",
        )
    if not username or not phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nom d'utilisateur et le téléphone sont obligatoires",
        )
    if profile_type == "alumni" and (not promotion or payload.enactus_join_year is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un Alumni doit renseigner promotion et année d'entrée à Enactus ESP",
        )

    normalized_email = payload.email.strip().lower()
    normalized_username = username.lower()
    existing = db.query(User).filter(or_(
        func.lower(User.email) == normalized_email,
        func.lower(User.username) == normalized_username,
    )).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email ou ce nom d'utilisateur",
        )

    user = User(
        first_name=first_name,
        last_name=last_name,
        email=normalized_email,
        username=normalized_username,
        enactus_join_year=payload.enactus_join_year,
        phone=phone,
        gender=gender,
        profile_type=profile_type,
        password_hash=hash_password(payload.password.strip()),
        onboarding_required=True,
        photo_url=optional_text(payload.photo_url),
        department=department,
        study_level=optional_text(payload.level),
        promotion=promotion,
        bio=join_request_bio(payload),
        linkedin_url=optional_text(payload.linkedin_url),
        github_url=optional_text(payload.github_url),
        portfolio_url=optional_text(payload.portfolio_url),
        status="pending",
        email_verified=False,
        is_active=True,
    )

    db.add(user)
    try:
        db.flush()
        if profile_type == "alumni":
            db.add(AlumniProfile(
                user_id=user.id,
                enactus_join_year=payload.enactus_join_year,
            ))
        enqueue_email_delivery(
            db,
            recipient_email=user.email,
            user_id=user.id,
            subject="EnactSpace - Demande d'adhésion reçue",
            text_body=(
                f"Bonjour {user.first_name},\n\n"
                "Votre demande d'adhésion à Enactus ESP a bien été reçue. "
                "Elle sera examinée par les responsables autorisés.\n\n"
                "Enactus ESP"
            ),
            dedupe_key=f"join-request:{user.id}",
        )
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Un compte existe déjà avec cet email",
        ) from exc
    db.refresh(user)

    return JoinRequestRead(
        message=(
            "Demande envoyée. Le compte sera activé après validation par les "
            "responsables autorisés."
        ),
        user_id=str(user.id),
    )


@router.post("/password-reset/request", response_model=PasswordResetRequestRead)
def request_password_reset(
    payload: PasswordResetRequest,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(
        func.lower(User.email) == payload.email.strip().lower()
    ).populate_existing().with_for_update().first()
    otp = f"{secrets.randbelow(1_000_000):06d}"

    if user and user.is_active:
        reset_otp = db.query(PasswordResetOtp).filter(
            PasswordResetOtp.user_id == user.id,
        ).populate_existing().with_for_update().first()
        if not reset_otp:
            reset_otp = PasswordResetOtp(
                user_id=user.id,
                otp_hash=hash_password(otp),
                expires_at=utc_now() + timedelta(minutes=15),
            )
            db.add(reset_otp)
        else:
            reset_otp.failed_attempts = 0
            reset_otp.otp_hash = hash_password(otp)
            reset_otp.expires_at = utc_now() + timedelta(minutes=15)
            reset_otp.created_at = utc_now()
        enqueue_email_delivery(
            db,
            recipient_email=user.email,
            user_id=user.id,
            subject="EnactSpace - Code de réinitialisation",
            text_body=(
                f"Bonjour {user.first_name},\n\n"
                f"Votre code de réinitialisation est : {otp}\n"
                "Il expire dans 15 minutes.\n\n"
                "Si vous n'êtes pas à l'origine de cette demande, ignorez cet email."
            ),
        )
        db.commit()

    return PasswordResetRequestRead(
        message=(
            "Si un compte existe avec cet email, un code OTP a été préparé."
        ),
        debug_otp=otp if settings.APP_ENV != "production" else None,
    )


@router.post("/password-reset/confirm")
def confirm_password_reset(
    payload: PasswordResetConfirm,
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(
        func.lower(User.email) == payload.email.strip().lower()
    ).populate_existing().with_for_update().first()
    reset_otp = None
    if user:
        reset_otp = db.query(PasswordResetOtp).filter(
            PasswordResetOtp.user_id == user.id,
        ).populate_existing().with_for_update().first()

    if not user or not user.is_active or not reset_otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code OTP invalide ou expiré",
        )

    if reset_otp.expires_at <= utc_now() or reset_otp.failed_attempts >= 5:
        db.delete(reset_otp)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code OTP invalide ou expiré",
        )

    if not verify_password(payload.otp.strip(), reset_otp.otp_hash):
        reset_otp.failed_attempts += 1
        if reset_otp.failed_attempts >= 5:
            db.delete(reset_otp)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code OTP invalide ou expiré",
        )

    new_password = payload.new_password.strip()
    if len(new_password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe doit contenir au moins 8 caractères",
        )

    user.password_hash = hash_password(new_password)
    revoked_count = revoke_user_sessions(db, user.id)
    if revoked_count:
        create_audit_log(
            db,
            action="session_revoked",
            user_id=user.id,
            entity_type="user",
            entity_id=user.id,
            new_value={"reason": "password_reset", "count": revoked_count},
        )
    db.delete(reset_otp)
    user.updated_at = utc_now()
    db.commit()

    return {"ok": True, "message": "Mot de passe réinitialisé avec succès"}


@router.post("/token", response_model=TokenResponse)
def login_for_swagger(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = authenticate_user(
        identifier=form_data.username,
        password=form_data.password,
        db=db,
    )

    _, access_token, refresh_token = create_session_tokens(
        db,
        user,
        user_agent=request.headers.get("user-agent"),
        platform="api",
    )
    db.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        refresh_expires_in=settings.REFRESH_TOKEN_EXPIRE_DAYS * 86400,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh_access_token(payload: RefreshTokenRequest, db: Session = Depends(get_db)):
    auth_session, access_token, refresh_token = rotate_refresh_token(db, payload.refresh_token)
    remaining = session_seconds_remaining(auth_session)
    db.commit()
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        refresh_expires_in=remaining,
    )


@router.post("/logout", status_code=204)
def logout(payload: RefreshTokenRequest, request: Request, db: Session = Depends(get_db)):
    authorization = request.headers.get("authorization", "")
    access_token = authorization[7:] if authorization.lower().startswith("bearer ") else None
    auth_session = revoke_current_session(db, payload.refresh_token, access_token=access_token)
    if auth_session is not None:
        create_audit_log(
            db, "session_revoked", auth_session.user_id, "auth_session", auth_session.id,
        )
    db.commit()
    return Response(status_code=204)


@router.get("/sessions", response_model=list[AuthSessionRead])
def list_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(AuthSession).filter(
        AuthSession.user_id == current_user.id,
        AuthSession.revoked_at.is_(None),
        AuthSession.expires_at > utc_now(),
    ).order_by(AuthSession.created_at.desc()).all()


@router.delete("/sessions/{session_id}", status_code=204)
def revoke_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    # Match rotation's lock order before touching the session or its audit FK.
    db.query(User.id).filter(User.id == current_user.id).with_for_update().first()
    auth_session = db.query(AuthSession).filter(
        AuthSession.id == session_id,
        AuthSession.user_id == current_user.id,
    ).populate_existing().with_for_update().first()
    if auth_session is None:
        raise HTTPException(status_code=404, detail="Session introuvable")
    if auth_session.revoked_at is None:
        auth_session.revoked_at = utc_now()
        create_audit_log(
            db, "session_revoked", current_user.id,
            "auth_session", auth_session.id,
        )
        db.commit()
    return Response(status_code=204)


@router.post("/logout-all")
def logout_all(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    from app.services.push_lifecycle import disable_user_push

    revoked_count = revoke_user_sessions(db, current_user.id)
    revoked_installations, cancelled_push = disable_user_push(
        db, current_user.id, revoke=True
    )
    create_audit_log(
        db, "logout_all", current_user.id, "user", current_user.id,
        new_value={
            "revoked_sessions": revoked_count,
            "revoked_installations": revoked_installations,
            "cancelled_push_deliveries": cancelled_push,
        },
    )
    db.commit()
    return {
        "ok": True,
        "revoked_sessions": revoked_count,
        "revoked_installations": revoked_installations,
        "cancelled_push_deliveries": cancelled_push,
    }
