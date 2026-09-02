from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, require_admin_or_team_leader
from app.core.config import settings
from app.db.database import get_db
from app.models.account import AccountDeletionRequest, UserPreference
from app.models.user import User
from app.schemas.account import (
    AccountDeletionCreate,
    AccountDeletionProcess,
    AccountDeletionRead,
    AccountDeletionUserRead,
    DataExportRead,
    UserPreferenceRead,
    UserPreferenceUpdate,
)
from app.services.account_service import build_user_data_export
from app.services.audit_service import create_audit_log


router = APIRouter(prefix="/users/me", tags=["Compte et confidentialité"])
admin_router = APIRouter(prefix="/admin/account-deletion-requests", tags=["Administration comptes"])


def _current_deletion_request(db: Session, user_id) -> AccountDeletionRequest | None:
    return (
        db.query(AccountDeletionRequest)
        .filter(AccountDeletionRequest.user_id == user_id)
        .order_by(AccountDeletionRequest.requested_at.desc())
        .first()
    )


@router.get("/preferences", response_model=UserPreferenceRead)
def get_preferences(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    preference = db.query(UserPreference).filter(UserPreference.user_id == current_user.id).first()
    if preference is None:
        preference = UserPreference(user_id=current_user.id)
        db.add(preference)
        db.commit()
        db.refresh(preference)
    return preference


@router.patch("/preferences", response_model=UserPreferenceRead)
def update_preferences(
    payload: UserPreferenceUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    preference = db.query(UserPreference).filter(UserPreference.user_id == current_user.id).first()
    if preference is None:
        preference = UserPreference(user_id=current_user.id)
        db.add(preference)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(preference, field, value.value if hasattr(value, "value") else value)
    preference.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(preference)
    return preference


@router.post("/data-export", response_model=DataExportRead)
def export_my_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    create_audit_log(
        db, "data_export_requested", current_user.id, "user", current_user.id
    )
    export = build_user_data_export(db, current_user, settings.APP_VERSION)
    create_audit_log(
        db,
        "data_export_generated",
        current_user.id,
        "user",
        current_user.id,
        new_value={"schema_version": export["metadata"]["schema_version"]},
    )
    db.commit()
    return export


@router.post("/deletion-request", response_model=AccountDeletionUserRead, status_code=201)
def request_account_deletion(
    payload: AccountDeletionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    duplicate = db.query(AccountDeletionRequest).filter(
        AccountDeletionRequest.user_id == current_user.id,
        AccountDeletionRequest.status == "pending",
    ).first()
    if duplicate:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Une demande est déjà en attente")
    deletion_request = AccountDeletionRequest(
        user_id=current_user.id,
        reason=(payload.reason or "").strip() or None,
    )
    db.add(deletion_request)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une demande est déjà en attente",
        )
    create_audit_log(
        db, "account_deletion_requested", current_user.id,
        "account_deletion_request", deletion_request.id,
    )
    db.commit()
    db.refresh(deletion_request)
    return deletion_request


@router.get("/deletion-request", response_model=AccountDeletionUserRead | None)
def get_account_deletion_request(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return _current_deletion_request(db, current_user.id)


@router.post("/deletion-request/cancel", response_model=AccountDeletionUserRead)
def cancel_account_deletion(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    deletion_request = db.query(AccountDeletionRequest).filter(
        AccountDeletionRequest.user_id == current_user.id,
        AccountDeletionRequest.status == "pending",
    ).first()
    if deletion_request is None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Aucune demande annulable")
    deletion_request.status = "cancelled"
    deletion_request.cancelled_at = datetime.utcnow()
    create_audit_log(
        db, "account_deletion_cancelled", current_user.id,
        "account_deletion_request", deletion_request.id,
    )
    db.commit()
    db.refresh(deletion_request)
    return deletion_request


@admin_router.get("", response_model=list[AccountDeletionRead])
def list_account_deletion_requests(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    return db.query(AccountDeletionRequest).order_by(
        AccountDeletionRequest.requested_at.desc()
    ).all()


@admin_router.patch("/{request_id}", response_model=AccountDeletionRead)
def process_account_deletion_request(
    request_id: str,
    payload: AccountDeletionProcess,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    deletion_request = db.query(AccountDeletionRequest).filter(
        AccountDeletionRequest.id == request_id
    ).first()
    if deletion_request is None:
        raise HTTPException(status_code=404, detail="Demande introuvable")
    next_status = payload.status.value
    allowed = {
        "pending": {"approved", "rejected"},
        "approved": {"completed", "rejected"},
    }
    if next_status not in allowed.get(deletion_request.status, set()):
        raise HTTPException(status_code=409, detail="Transition de statut invalide")
    deletion_request.status = next_status
    deletion_request.admin_note = (payload.admin_note or "").strip() or None
    deletion_request.processed_at = datetime.utcnow()
    create_audit_log(
        db, "account_deletion_processed", current_user.id,
        "account_deletion_request", deletion_request.id,
        new_value={"status": next_status},
    )
    db.commit()
    db.refresh(deletion_request)
    return deletion_request
