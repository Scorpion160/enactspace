import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.database import get_db
from app.models.user import User, PasswordResetOtp
from app.schemas.auth import (
    LoginRequest,
    TokenResponse,
    PasswordResetRequest,
    PasswordResetConfirm,
    PasswordResetRequestRead,
    JoinRequestCreate,
    JoinRequestRead,
)
from app.core.security import (
    verify_password,
    hash_password,
    create_access_token,
)


router = APIRouter(prefix="/auth", tags=["Authentification"])


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


def authenticate_user(email: str, password: str, db: Session) -> User:
    user = db.query(User).filter(User.email == email).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
        )

    if not verify_password(password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé",
        )

    if user.status == "pending":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte en attente de validation par la Secrétaire Générale",
        )

    if user.status in {"rejected", "suspended", "inactive"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte non autorisé",
        )

    if not user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email non vérifié",
        )

    return user


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = authenticate_user(
        email=payload.email,
        password=payload.password,
        db=db,
    )

    token = create_access_token(str(user.id))

    return TokenResponse(access_token=token)


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
    gender = payload.gender.strip().lower()
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
    department = optional_text(payload.department)
    if not first_name or not last_name or not department:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complétez au moins identité, email et filière",
        )

    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email",
        )

    user = User(
        first_name=first_name,
        last_name=last_name,
        email=payload.email,
        phone=optional_text(payload.phone),
        gender=gender,
        profile_type=profile_type,
        password_hash=hash_password(payload.password.strip()),
        photo_url=optional_text(payload.photo_url),
        department=department,
        study_level=optional_text(payload.level),
        promotion=optional_text(payload.promotion),
        bio=join_request_bio(payload),
        linkedin_url=optional_text(payload.linkedin_url),
        github_url=optional_text(payload.github_url),
        portfolio_url=optional_text(payload.portfolio_url),
        status="pending",
        email_verified=False,
        is_active=True,
    )

    db.add(user)
    db.commit()
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
    user = db.query(User).filter(User.email == payload.email).first()
    otp = f"{secrets.randbelow(1_000_000):06d}"

    if user and user.is_active:
        reset_otp = db.query(PasswordResetOtp).filter(
            PasswordResetOtp.user_id == user.id,
        ).first()
        if not reset_otp:
            reset_otp = PasswordResetOtp(
                user_id=user.id,
                otp_hash=hash_password(otp),
                expires_at=datetime.utcnow() + timedelta(minutes=15),
            )
            db.add(reset_otp)
        else:
            reset_otp.otp_hash = hash_password(otp)
            reset_otp.expires_at = datetime.utcnow() + timedelta(minutes=15)
            reset_otp.created_at = datetime.utcnow()
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
    user = db.query(User).filter(User.email == payload.email).first()
    reset_otp = None
    if user:
        reset_otp = db.query(PasswordResetOtp).filter(
            PasswordResetOtp.user_id == user.id,
        ).first()

    if not user or not reset_otp:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code OTP invalide ou expiré",
        )

    if reset_otp.expires_at < datetime.utcnow():
        db.delete(reset_otp)
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Code OTP invalide ou expiré",
        )

    if not verify_password(payload.otp.strip(), reset_otp.otp_hash):
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
    db.delete(reset_otp)
    user.updated_at = datetime.utcnow()
    db.commit()

    return {"ok": True, "message": "Mot de passe réinitialisé avec succès"}


@router.post("/token", response_model=TokenResponse)
def login_for_swagger(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = authenticate_user(
        email=form_data.username,
        password=form_data.password,
        db=db,
    )

    token = create_access_token(str(user.id))

    return TokenResponse(access_token=token)
