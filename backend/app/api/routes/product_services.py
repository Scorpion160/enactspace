from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    oauth2_scheme,
    require_admin_or_team_leader,
)
from app.core.security import decode_access_token_payload
from app.db.database import get_db
from app.models.account import AuthSession, UserPreference
from app.models.product_services import (
    AppInstallation,
    AppRelease,
    AppVersionPolicy,
    ProductFeedback,
    SupportTicket,
    SupportTicketMessage,
)
from app.models.user import User
from app.services.session_service import session_seconds_remaining
from app.schemas.product_services import (
    AppReleaseCreate,
    AppReleaseRead,
    AppReleaseUpdate,
    AppVersionPolicyRead,
    AppVersionPolicyUpdate,
    InstallationRead,
    InstallationUpsert,
    PushTokenRead,
    PushTokenUpdate,
    ProductBootstrapRead,
    ProductFeedbackAdminRead,
    ProductFeedbackCreate,
    ProductFeedbackManage,
    ProductFeedbackRead,
    ProductPlatform,
    SupportTicketCreate,
    SupportTicketDetail,
    SupportTicketManage,
    SupportTicketMessageCreate,
    SupportTicketMessageRead,
    SupportTicketRead,
    VERSION_PATTERN,
    validate_store_url_for_platform,
)
from app.services.audit_service import create_audit_log
from app.services.push_lifecycle import cancel_unsent_deliveries, clear_installation_push
from app.services.push_locking import lock_push_preference, lock_user_installation
from app.services.push_tokens import encrypt_push_token, push_token_hash


installation_router = APIRouter(
    prefix="/users/me/installations", tags=["Installations"]
)
support_router = APIRouter(prefix="/support/tickets", tags=["Support"])
support_admin_router = APIRouter(
    prefix="/admin/support/tickets", tags=["Administration support"]
)
feedback_router = APIRouter(prefix="/feedback", tags=["Product feedback"])
feedback_admin_router = APIRouter(
    prefix="/admin/feedback", tags=["Administration feedback"]
)
product_router = APIRouter(prefix="/product", tags=["Product bootstrap"])
product_admin_router = APIRouter(
    prefix="/admin/product", tags=["Administration produit"]
)


SUPPORT_TRANSITIONS = {
    "open": {"in_progress", "resolved", "closed"},
    "in_progress": {"open", "resolved", "closed"},
    "resolved": {"in_progress", "closed"},
    "closed": {"open"},
}


def _enum_value(value):
    return value.value if hasattr(value, "value") else value


def _clean_optional(value: str | None) -> str | None:
    return (value or "").strip() or None


def _naive_utc(value: datetime | None) -> datetime | None:
    if value is None or value.tzinfo is None:
        return value
    return value.astimezone(timezone.utc).replace(tzinfo=None)


def _commit(db: Session, detail: str) -> None:
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=detail) from error


def _ticket_detail(db: Session, ticket: SupportTicket) -> dict:
    messages = (
        db.query(SupportTicketMessage)
        .filter(SupportTicketMessage.ticket_id == ticket.id)
        .order_by(SupportTicketMessage.created_at, SupportTicketMessage.id)
        .all()
    )
    return {
        column.name: getattr(ticket, column.name)
        for column in SupportTicket.__table__.columns
    } | {"messages": messages}


def _own_ticket_or_404(db: Session, ticket_id, user_id) -> SupportTicket:
    ticket = db.query(SupportTicket).filter(
        SupportTicket.id == ticket_id,
        SupportTicket.user_id == user_id,
    ).first()
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket introuvable")
    return ticket


def _ticket_or_404(db: Session, ticket_id) -> SupportTicket:
    ticket = db.query(SupportTicket).filter(SupportTicket.id == ticket_id).first()
    if ticket is None:
        raise HTTPException(status_code=404, detail="Ticket introuvable")
    return ticket


def _feedback_or_404(db: Session, feedback_id) -> ProductFeedback:
    feedback = db.query(ProductFeedback).filter(ProductFeedback.id == feedback_id).first()
    if feedback is None:
        raise HTTPException(status_code=404, detail="Feedback introuvable")
    return feedback


def _release_or_404(db: Session, release_id, *, for_update: bool = False) -> AppRelease:
    query = db.query(AppRelease).filter(AppRelease.id == release_id)
    if for_update:
        query = query.with_for_update().populate_existing()
    release = query.first()
    if release is None:
        raise HTTPException(status_code=404, detail="Version applicative introuvable")
    return release


@installation_router.get("", response_model=list[InstallationRead])
def list_my_installations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(AppInstallation).filter(
        AppInstallation.user_id == current_user.id
    ).order_by(AppInstallation.last_seen_at.desc()).all()


@installation_router.post("", response_model=InstallationRead)
def register_installation(
    payload: InstallationUpsert,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    access_token: str = Depends(oauth2_scheme),
):
    lock_push_preference(db, current_user.id)
    _lock_active_request_session(db, current_user.id, access_token)
    installation = (
        db.query(AppInstallation)
        .filter(
            AppInstallation.installation_key == payload.installation_key,
            AppInstallation.user_id == current_user.id,
        )
        .populate_existing()
        .with_for_update()
        .first()
    )
    conflicting = None if installation is not None else db.query(AppInstallation).filter(
        AppInstallation.installation_key == payload.installation_key
    ).first()
    if conflicting is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette installation appartient deja a un autre compte",
        )
    now = datetime.utcnow()
    if installation is None:
        installation = AppInstallation(
            user_id=current_user.id,
            installation_key=payload.installation_key,
            platform=payload.platform.value,
        )
        db.add(installation)
    for field in (
        "app_version", "build_number", "os_version", "device_model", "locale"
    ):
        setattr(installation, field, getattr(payload, field))
    installation.platform = payload.platform.value
    installation.last_seen_at = now
    installation.updated_at = now
    if installation.revoked_at is not None:
        clear_installation_push(db, installation)
    installation.revoked_at = None
    try:
        db.commit()
    except IntegrityError as error:
        db.rollback()
        lock_push_preference(db, current_user.id)
        _lock_active_request_session(db, current_user.id, access_token)
        existing = (
            db.query(AppInstallation)
            .filter(
                AppInstallation.installation_key == payload.installation_key,
                AppInstallation.user_id == current_user.id,
            )
            .populate_existing()
            .with_for_update()
            .first()
        )
        if existing is not None and existing.user_id == current_user.id:
            return existing
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Cette installation appartient deja a un autre compte",
        ) from error
    db.refresh(installation)
    return installation


def _lock_active_request_session(db: Session, user_id, access_token) -> None:
    """Revalidate a session-bearing request after the stable user lock.

    This fences an already-authenticated installation POST that was waiting
    while logout-all revoked its session. Legacy access tokens without a
    session ID retain their existing compatibility behavior.
    """
    if not isinstance(access_token, str):
        return
    payload = decode_access_token_payload(access_token)
    session_id = payload.get("sid") if payload else None
    if not session_id:
        return
    auth_session = (
        db.query(AuthSession)
        .filter(AuthSession.id == session_id, AuthSession.user_id == user_id)
        .populate_existing()
        .with_for_update()
        .first()
    )
    if (
        auth_session is None
        or auth_session.revoked_at is not None
        or session_seconds_remaining(auth_session) <= 0
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session révoquée ou expirée",
        )


@installation_router.post("/{installation_id}/revoke", response_model=InstallationRead)
def revoke_installation(
    installation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    installation = lock_user_installation(db, current_user.id, installation_id)
    if installation is None:
        raise HTTPException(status_code=404, detail="Installation introuvable")
    if installation.revoked_at is None:
        installation.revoked_at = datetime.utcnow()
        installation.updated_at = installation.revoked_at
    clear_installation_push(db, installation)
    db.commit()
    db.refresh(installation)
    return installation


def _own_installation_or_404(db: Session, installation_id: str, user_id) -> AppInstallation:
    installation = lock_user_installation(db, user_id, installation_id)
    if installation is None:
        raise HTTPException(status_code=404, detail="Installation introuvable")
    return installation


@installation_router.put("/{installation_id}/push-token", response_model=PushTokenRead)
def register_push_token(
    installation_id: str,
    payload: PushTokenUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    installation = _own_installation_or_404(db, installation_id, current_user.id)
    if installation.revoked_at is not None:
        raise HTTPException(status_code=409, detail="Installation révoquée")
    preference = db.query(UserPreference).filter(
        UserPreference.user_id == current_user.id
    ).populate_existing().first()
    if preference is None:
        if not payload.enable_account_push:
            raise HTTPException(status_code=409, detail="Notifications push désactivées")
        preference = UserPreference(
            user_id=current_user.id,
            notification_push_enabled=True,
        )
        db.add(preference)
    elif not preference.notification_push_enabled:
        if not payload.enable_account_push:
            raise HTTPException(status_code=409, detail="Notifications push désactivées")
        preference.notification_push_enabled = True
        preference.updated_at = datetime.utcnow()
    normalized_hash = push_token_hash(payload.token)
    encrypted = encrypt_push_token(payload.token)
    if installation.push_token_hash and installation.push_token_hash != normalized_hash:
        cancel_unsent_deliveries(
            db, installation_id=installation.id,
            token_hash=installation.push_token_hash,
        )
    now = datetime.utcnow()
    installation.push_provider = "fcm"
    installation.push_token_ciphertext = encrypted
    installation.push_token_hash = normalized_hash
    installation.push_token_updated_at = now
    installation.updated_at = now
    _commit(db, "Ce jeton push est déjà associé à une autre installation")
    return PushTokenRead(
        installation_id=installation.id,
        provider=installation.push_provider,
        registered=True,
        updated_at=installation.push_token_updated_at,
    )


@installation_router.delete("/{installation_id}/push-token", response_model=PushTokenRead)
def delete_push_token(
    installation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    installation = _own_installation_or_404(db, installation_id, current_user.id)
    clear_installation_push(db, installation)
    db.commit()
    return PushTokenRead(
        installation_id=installation.id,
        provider=None,
        registered=False,
        updated_at=None,
    )


@support_router.post("", response_model=SupportTicketRead, status_code=201)
def create_support_ticket(
    payload: SupportTicketCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    ticket = SupportTicket(
        user_id=current_user.id,
        subject=payload.subject.strip(),
        category=payload.category.value,
        priority=payload.priority.value,
    )
    db.add(ticket)
    db.flush()
    db.add(SupportTicketMessage(
        ticket_id=ticket.id,
        author_id=current_user.id,
        message=payload.message.strip(),
    ))
    db.commit()
    db.refresh(ticket)
    return ticket


@support_router.get("", response_model=list[SupportTicketRead])
def list_my_support_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(SupportTicket).filter(
        SupportTicket.user_id == current_user.id
    ).order_by(SupportTicket.updated_at.desc()).all()


@support_router.get("/{ticket_id}", response_model=SupportTicketDetail)
def get_my_support_ticket(
    ticket_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return _ticket_detail(db, _own_ticket_or_404(db, ticket_id, current_user.id))


@support_router.post(
    "/{ticket_id}/messages", response_model=SupportTicketMessageRead, status_code=201
)
def add_my_support_message(
    ticket_id: str,
    payload: SupportTicketMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    ticket = _own_ticket_or_404(db, ticket_id, current_user.id)
    if ticket.status == "closed":
        raise HTTPException(status_code=409, detail="Ce ticket est ferme")
    message = SupportTicketMessage(
        ticket_id=ticket.id,
        author_id=current_user.id,
        message=payload.message.strip(),
    )
    db.add(message)
    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(message)
    return message


@support_admin_router.get("", response_model=list[SupportTicketRead])
def list_all_support_tickets(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    return db.query(SupportTicket).order_by(SupportTicket.updated_at.desc()).all()


@support_admin_router.get("/{ticket_id}", response_model=SupportTicketDetail)
def get_support_ticket_for_management(
    ticket_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    return _ticket_detail(db, _ticket_or_404(db, ticket_id))


@support_admin_router.patch("/{ticket_id}", response_model=SupportTicketRead)
def manage_support_ticket(
    ticket_id: str,
    payload: SupportTicketManage,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    ticket = _ticket_or_404(db, ticket_id)
    changes = {}
    fields = payload.model_fields_set
    if "status" in fields and payload.status is not None:
        next_status = payload.status.value
        if next_status != ticket.status and next_status not in SUPPORT_TRANSITIONS[ticket.status]:
            raise HTTPException(status_code=409, detail="Transition de statut invalide")
        if next_status != ticket.status:
            changes["status"] = {"old": ticket.status, "new": next_status}
            ticket.status = next_status
            now = datetime.utcnow()
            if next_status == "resolved":
                ticket.resolved_at = now
                ticket.closed_at = None
            elif next_status == "closed":
                ticket.closed_at = now
            elif next_status in {"open", "in_progress"}:
                ticket.resolved_at = None
                ticket.closed_at = None
    if "priority" in fields and payload.priority is not None:
        next_priority = payload.priority.value
        if next_priority != ticket.priority:
            changes["priority"] = {"old": ticket.priority, "new": next_priority}
            ticket.priority = next_priority
    if "assigned_to_id" in fields:
        if payload.assigned_to_id is not None and db.get(User, payload.assigned_to_id) is None:
            raise HTTPException(status_code=400, detail="Responsable introuvable")
        if payload.assigned_to_id != ticket.assigned_to_id:
            changes["assigned_to_id"] = {
                "old": str(ticket.assigned_to_id) if ticket.assigned_to_id else None,
                "new": str(payload.assigned_to_id) if payload.assigned_to_id else None,
            }
            ticket.assigned_to_id = payload.assigned_to_id
    if changes:
        ticket.updated_at = datetime.utcnow()
        create_audit_log(
            db, "support_ticket_managed", current_user.id,
            "support_ticket", ticket.id, new_value=changes,
        )
        db.commit()
        db.refresh(ticket)
    return ticket


@support_admin_router.post(
    "/{ticket_id}/messages", response_model=SupportTicketMessageRead, status_code=201
)
def add_support_management_message(
    ticket_id: str,
    payload: SupportTicketMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    ticket = _ticket_or_404(db, ticket_id)
    message = SupportTicketMessage(
        ticket_id=ticket.id,
        author_id=current_user.id,
        message=payload.message.strip(),
    )
    db.add(message)
    ticket.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(message)
    return message


@feedback_router.post("", response_model=ProductFeedbackRead, status_code=201)
def create_product_feedback(
    payload: ProductFeedbackCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    feedback = ProductFeedback(
        user_id=current_user.id,
        category=payload.category.value,
        message=payload.message.strip(),
        rating=payload.rating,
        platform=payload.platform.value if payload.platform else None,
        app_version=_clean_optional(payload.app_version),
        build_number=payload.build_number,
    )
    db.add(feedback)
    db.commit()
    db.refresh(feedback)
    return feedback


@feedback_router.get("", response_model=list[ProductFeedbackRead])
def list_my_product_feedback(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(ProductFeedback).filter(
        ProductFeedback.user_id == current_user.id
    ).order_by(ProductFeedback.created_at.desc()).all()


@feedback_router.get("/{feedback_id}", response_model=ProductFeedbackRead)
def get_my_product_feedback(
    feedback_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    feedback = db.query(ProductFeedback).filter(
        ProductFeedback.id == feedback_id,
        ProductFeedback.user_id == current_user.id,
    ).first()
    if feedback is None:
        raise HTTPException(status_code=404, detail="Feedback introuvable")
    return feedback


@feedback_admin_router.get("", response_model=list[ProductFeedbackAdminRead])
def list_all_product_feedback(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    return db.query(ProductFeedback).order_by(ProductFeedback.created_at.desc()).all()


@feedback_admin_router.patch("/{feedback_id}", response_model=ProductFeedbackAdminRead)
def manage_product_feedback(
    feedback_id: str,
    payload: ProductFeedbackManage,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    feedback = _feedback_or_404(db, feedback_id)
    if "status" in payload.model_fields_set and payload.status is None:
        raise HTTPException(status_code=400, detail="Statut de feedback invalide")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(feedback, field, _enum_value(value) if field == "status" else _clean_optional(value))
    feedback.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(feedback)
    return feedback


@product_router.get("/bootstrap", response_model=ProductBootstrapRead)
def product_bootstrap(
    platform: ProductPlatform,
    version: str = Query(min_length=3, max_length=40, pattern=VERSION_PATTERN),
    build_number: int = Query(gt=0),
    db: Session = Depends(get_db),
):
    platform_value = platform.value
    policy = db.query(AppVersionPolicy).filter(
        AppVersionPolicy.platform == platform_value
    ).first()
    if policy is None:
        return {
            "configured": False,
            "platform": platform_value,
            "client_version": version,
            "client_build_number": build_number,
            "current_version": None,
            "current_build_number": None,
            "minimum_supported_version": None,
            "minimum_supported_build_number": None,
            "update_available": False,
            "update_required": False,
            "force_update": False,
            "store_url": None,
            "maintenance": {"active": False, "message": None},
        }
    current = db.get(AppRelease, policy.current_release_id) if policy.current_release_id else None
    minimum = (
        db.get(AppRelease, policy.minimum_supported_release_id)
        if policy.minimum_supported_release_id else None
    )
    update_available = bool(current and build_number < current.build_number)
    update_required = bool(minimum and build_number < minimum.build_number)
    now = datetime.utcnow()
    maintenance_active = policy.maintenance_enabled and (
        policy.maintenance_starts_at is None
        or policy.maintenance_starts_at <= now < policy.maintenance_ends_at
    )
    return {
        "configured": True,
        "platform": platform_value,
        "client_version": version,
        "client_build_number": build_number,
        "current_version": current.version if current else None,
        "current_build_number": current.build_number if current else None,
        "minimum_supported_version": minimum.version if minimum else None,
        "minimum_supported_build_number": minimum.build_number if minimum else None,
        "update_available": update_available,
        "update_required": update_required,
        "force_update": update_required or (
            policy.force_update_to_current and update_available
        ),
        "store_url": current.store_url if current else None,
        "maintenance": {
            "active": maintenance_active,
            "message": policy.maintenance_message if maintenance_active else None,
        },
    }


@product_admin_router.post("/releases", response_model=AppReleaseRead, status_code=201)
def create_app_release(
    payload: AppReleaseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    try:
        store_url = validate_store_url_for_platform(
            payload.store_url, payload.platform
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    release = AppRelease(
        platform=payload.platform.value,
        version=payload.version,
        build_number=payload.build_number,
        release_notes=_clean_optional(payload.release_notes),
        store_url=store_url,
        created_by_id=current_user.id,
    )
    db.add(release)
    _commit(db, "Cette version applicative existe deja")
    db.refresh(release)
    return release


@product_admin_router.get("/releases", response_model=list[AppReleaseRead])
def list_app_releases(
    platform: ProductPlatform | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    query = db.query(AppRelease)
    if platform is not None:
        query = query.filter(AppRelease.platform == platform.value)
    return query.order_by(AppRelease.platform, AppRelease.build_number.desc()).all()


@product_admin_router.patch("/releases/{release_id}", response_model=AppReleaseRead)
def update_app_release(
    release_id: str,
    payload: AppReleaseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    release = _release_or_404(db, release_id, for_update=True)
    if release.status != "draft":
        raise HTTPException(status_code=409, detail="Seule une version brouillon est modifiable")
    if any(
        field in payload.model_fields_set and getattr(payload, field) is None
        for field in ("version", "build_number")
    ):
        raise HTTPException(status_code=400, detail="Version applicative invalide")
    if "store_url" in payload.model_fields_set:
        try:
            validate_store_url_for_platform(payload.store_url, release.platform)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(release, field, _clean_optional(value) if isinstance(value, str) or value is None else value)
    release.updated_at = datetime.utcnow()
    _commit(db, "Cette version applicative existe deja")
    db.refresh(release)
    return release


@product_admin_router.post("/releases/{release_id}/publish", response_model=AppReleaseRead)
def publish_app_release(
    release_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    release = _release_or_404(db, release_id, for_update=True)
    if release.status != "draft":
        raise HTTPException(status_code=409, detail="Cette version ne peut pas etre publiee")
    now = datetime.utcnow()
    release.status = "published"
    release.published_at = now
    release.updated_at = now
    create_audit_log(
        db, "app_release_published", current_user.id,
        "app_release", release.id,
        new_value={"platform": release.platform, "build_number": release.build_number},
    )
    db.commit()
    db.refresh(release)
    return release


@product_admin_router.post("/releases/{release_id}/withdraw", response_model=AppReleaseRead)
def withdraw_app_release(
    release_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    release = _release_or_404(db, release_id, for_update=True)
    if release.status != "published":
        raise HTTPException(status_code=409, detail="Cette version ne peut pas etre retiree")
    referenced = db.query(AppVersionPolicy.id).filter(
        (AppVersionPolicy.current_release_id == release.id)
        | (AppVersionPolicy.minimum_supported_release_id == release.id)
    ).first()
    if referenced is not None:
        raise HTTPException(
            status_code=409,
            detail="Cette version est encore referencee par une politique active",
        )
    release.status = "withdrawn"
    release.updated_at = datetime.utcnow()
    create_audit_log(
        db, "app_release_withdrawn", current_user.id,
        "app_release", release.id,
        new_value={"platform": release.platform, "build_number": release.build_number},
    )
    db.commit()
    db.refresh(release)
    return release


@product_admin_router.get("/policies/{platform}", response_model=AppVersionPolicyRead | None)
def get_app_version_policy(
    platform: ProductPlatform,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    return db.query(AppVersionPolicy).filter(
        AppVersionPolicy.platform == platform.value
    ).first()


def _policy_releases(db: Session, release_ids, platform: str) -> dict:
    ordered_ids = sorted({release_id for release_id in release_ids if release_id}, key=str)
    if not ordered_ids:
        return {}
    releases = (
        db.query(AppRelease)
        .filter(AppRelease.id.in_(ordered_ids))
        .order_by(AppRelease.id)
        .with_for_update()
        .populate_existing()
        .all()
    )
    releases_by_id = {release.id: release for release in releases}
    for release_id in ordered_ids:
        release = releases_by_id.get(release_id)
        if release is None:
            raise HTTPException(status_code=400, detail="Version applicative introuvable")
        if release.platform != platform:
            raise HTTPException(status_code=400, detail="Plateforme de version incompatible")
        if release.status != "published":
            raise HTTPException(status_code=409, detail="La version doit etre publiee")
    return releases_by_id


@product_admin_router.put("/policies/{platform}", response_model=AppVersionPolicyRead)
def update_app_version_policy(
    platform: ProductPlatform,
    payload: AppVersionPolicyUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    platform_value = platform.value
    policy = db.query(AppVersionPolicy).filter(
        AppVersionPolicy.platform == platform_value
    ).first()
    is_new = policy is None
    if policy is None:
        policy = AppVersionPolicy(
            platform=platform_value,
            force_update_to_current=False,
            maintenance_enabled=False,
        )
    fields = payload.model_fields_set
    if any(
        field in fields and getattr(payload, field) is None
        for field in ("force_update_to_current", "maintenance_enabled")
    ):
        raise HTTPException(status_code=400, detail="Politique applicative invalide")
    current_id = (
        payload.current_release_id if "current_release_id" in fields
        else policy.current_release_id
    )
    minimum_id = (
        payload.minimum_supported_release_id
        if "minimum_supported_release_id" in fields
        else policy.minimum_supported_release_id
    )
    releases = _policy_releases(db, (current_id, minimum_id), platform_value)
    current = releases.get(current_id)
    minimum = releases.get(minimum_id)
    if minimum is not None and current is None:
        raise HTTPException(status_code=400, detail="Une version courante est requise")
    if current is not None and minimum is not None and minimum.build_number > current.build_number:
        raise HTTPException(
            status_code=400,
            detail="La version minimale ne peut pas depasser la version courante",
        )
    force_to_current = (
        payload.force_update_to_current
        if "force_update_to_current" in fields
        else policy.force_update_to_current
    )
    force_capable = minimum_id is not None or force_to_current is True
    if force_capable:
        if current is None:
            raise HTTPException(
                status_code=400, detail="Une version courante est requise"
            )
        try:
            store_url = validate_store_url_for_platform(
                current.store_url, platform_value
            )
        except ValueError as exc:
            raise HTTPException(
                status_code=400,
                detail="La version courante doit avoir une URL de mise a jour valide",
            ) from exc
        if store_url is None:
            raise HTTPException(
                status_code=400,
                detail="La version courante doit avoir une URL de mise a jour valide",
            )
    starts = (
        _naive_utc(payload.maintenance_starts_at)
        if "maintenance_starts_at" in fields else policy.maintenance_starts_at
    )
    ends = (
        _naive_utc(payload.maintenance_ends_at)
        if "maintenance_ends_at" in fields else policy.maintenance_ends_at
    )
    if (starts is None) != (ends is None) or (
        starts is not None and ends is not None and starts >= ends
    ):
        raise HTTPException(status_code=400, detail="Fenetre de maintenance invalide")
    old_values = {
        "minimum_supported_release_id": policy.minimum_supported_release_id,
        "force_update_to_current": policy.force_update_to_current,
        "maintenance_enabled": policy.maintenance_enabled,
    }
    policy.current_release_id = current_id
    policy.minimum_supported_release_id = minimum_id
    for field in ("force_update_to_current", "maintenance_enabled"):
        if field in fields:
            setattr(policy, field, getattr(payload, field))
    if "maintenance_message" in fields:
        policy.maintenance_message = _clean_optional(payload.maintenance_message)
    policy.maintenance_starts_at = starts
    policy.maintenance_ends_at = ends
    policy.updated_by_id = current_user.id
    policy.updated_at = datetime.utcnow()
    if is_new:
        db.add(policy)
    db.flush()
    audit_events = []
    if old_values["minimum_supported_release_id"] != policy.minimum_supported_release_id:
        audit_events.append("minimum_supported_release_changed")
    if old_values["force_update_to_current"] != policy.force_update_to_current:
        audit_events.append("force_update_toggled")
    if old_values["maintenance_enabled"] != policy.maintenance_enabled:
        audit_events.append("maintenance_toggled")
    audit_values = {
        "minimum_supported_release_changed": {
            "minimum_supported_release_id": (
                str(policy.minimum_supported_release_id)
                if policy.minimum_supported_release_id else None
            )
        },
        "force_update_toggled": {
            "force_update_to_current": policy.force_update_to_current
        },
        "maintenance_toggled": {
            "maintenance_enabled": policy.maintenance_enabled
        },
    }
    for event in audit_events:
        create_audit_log(
            db, event, current_user.id, "app_version_policy", policy.id,
            new_value={"platform": platform_value, **audit_values[event]},
        )
    db.commit()
    db.refresh(policy)
    return policy
