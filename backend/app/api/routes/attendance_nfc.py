from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
)
from app.core.roles import SECRETARIAT_ROLES
from app.db.database import get_db
from app.models.attendance import AttendanceNfcTag
from app.models.user import User
from app.schemas.attendance import (
    AttendanceNfcTagEnrollRequest,
    AttendanceNfcTagRead,
    AttendanceNfcTagReplaceRequest,
    AttendanceNfcTagRevokeRequest,
)
from app.services.attendance_nfc_service import (
    ACTIVE_NFC_TAG_STATUS,
    NFC_TAG_STATUSES,
    REVOKED_NFC_TAG_STATUSES,
    hash_nfc_tag_payload,
    mask_nfc_tag_hash,
    nfc_tag_read_payload,
)
from app.services.audit_service import create_audit_log, get_client_ip


router = APIRouter(prefix="/attendance/nfc", tags=["Presences NFC"])


def _require_nfc_manager(db: Session, current_user: User) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(SECRETARIAT_ROLES):
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Gestion NFC reservee au secretariat",
    )


def _member_or_404(db: Session, member_id: str) -> User:
    member = db.query(User).filter(User.id == member_id).first()
    if not member:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Membre introuvable",
        )
    if member.status != "active" or member.profile_type == "candidate":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Badge NFC reserve aux membres actifs",
        )
    return member


def _active_tag_for_member(db: Session, member_id) -> AttendanceNfcTag | None:
    return (
        db.query(AttendanceNfcTag)
        .filter(
            AttendanceNfcTag.member_id == member_id,
            AttendanceNfcTag.status == ACTIVE_NFC_TAG_STATUS,
        )
        .first()
    )


def _tag_or_404(db: Session, tag_id: str) -> AttendanceNfcTag:
    tag = db.query(AttendanceNfcTag).filter(AttendanceNfcTag.id == tag_id).first()
    if not tag:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Badge NFC introuvable",
        )
    return tag


def _revoke_tag(
    tag: AttendanceNfcTag,
    *,
    current_user: User,
    new_status: str,
) -> None:
    if new_status not in REVOKED_NFC_TAG_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de revocation NFC invalide",
        )
    now = datetime.utcnow()
    tag.status = new_status
    tag.revoked_by_id = current_user.id
    tag.revoked_at = now
    tag.updated_at = now


def _ensure_tag_can_be_assigned(
    db: Session,
    *,
    tag_uid_hash: str,
    member_id,
) -> None:
    active_tag = (
        db.query(AttendanceNfcTag)
        .filter(
            AttendanceNfcTag.tag_uid_hash == tag_uid_hash,
            AttendanceNfcTag.status == ACTIVE_NFC_TAG_STATUS,
        )
        .first()
    )
    if active_tag and active_tag.member_id != member_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce badge est deja associe a un autre membre",
        )
    historical_tag = (
        db.query(AttendanceNfcTag)
        .filter(
            AttendanceNfcTag.tag_uid_hash == tag_uid_hash,
            AttendanceNfcTag.status != ACTIVE_NFC_TAG_STATUS,
        )
        .first()
    )
    if historical_tag:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce badge a deja ete revoke ou remplace",
        )


def _create_tag(
    db: Session,
    *,
    payload: AttendanceNfcTagEnrollRequest | AttendanceNfcTagReplaceRequest,
    member_id,
    current_user: User,
) -> AttendanceNfcTag:
    tag_uid_hash = hash_nfc_tag_payload(payload.tag_payload)
    _ensure_tag_can_be_assigned(db, tag_uid_hash=tag_uid_hash, member_id=member_id)
    now = datetime.utcnow()
    tag = AttendanceNfcTag(
        member_id=member_id,
        tag_uid_hash=tag_uid_hash,
        tag_label=payload.label,
        tag_type=payload.tag_type,
        status=ACTIVE_NFC_TAG_STATUS,
        assigned_by_id=current_user.id,
        assigned_at=now,
        created_at=now,
        updated_at=now,
    )
    db.add(tag)
    db.flush()
    return tag


@router.post("/tags/enroll", response_model=AttendanceNfcTagRead)
def enroll_nfc_tag(
    payload: AttendanceNfcTagEnrollRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    _require_nfc_manager(db, current_user)
    member = _member_or_404(db, str(payload.member_id))
    existing_tag = _active_tag_for_member(db, member.id)
    if existing_tag and not payload.replace_existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ce membre a deja un badge actif",
        )
    if existing_tag:
        _revoke_tag(
            existing_tag,
            current_user=current_user,
            new_status="replaced",
        )
        db.flush()

    tag = _create_tag(
        db,
        payload=payload,
        member_id=member.id,
        current_user=current_user,
    )
    create_audit_log(
        db,
        action="attendance_nfc_tag_enrolled",
        user_id=current_user.id,
        entity_type="attendance_nfc_tag",
        entity_id=tag.id,
        new_value={
            "member_id": str(member.id),
            "masked_tag": mask_nfc_tag_hash(tag.tag_uid_hash),
            "status": tag.status,
            "replaced_tag_id": str(existing_tag.id) if existing_tag else None,
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(tag)
    return nfc_tag_read_payload(tag)


@router.get("/members/{member_id}/tag", response_model=AttendanceNfcTagRead | None)
def get_member_nfc_tag(
    member_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    _require_nfc_manager(db, current_user)
    member = _member_or_404(db, member_id)
    tag = _active_tag_for_member(db, member.id)
    return nfc_tag_read_payload(tag) if tag else None


@router.post("/tags/{tag_id}/revoke", response_model=AttendanceNfcTagRead)
def revoke_nfc_tag(
    tag_id: str,
    payload: AttendanceNfcTagRevokeRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    _require_nfc_manager(db, current_user)
    if payload.status not in NFC_TAG_STATUSES or payload.status == ACTIVE_NFC_TAG_STATUS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut NFC invalide",
        )
    tag = _tag_or_404(db, tag_id)
    _revoke_tag(tag, current_user=current_user, new_status=payload.status)
    create_audit_log(
        db,
        action="attendance_nfc_tag_revoked",
        user_id=current_user.id,
        entity_type="attendance_nfc_tag",
        entity_id=tag.id,
        new_value={
            "member_id": str(tag.member_id),
            "masked_tag": mask_nfc_tag_hash(tag.tag_uid_hash),
            "status": tag.status,
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(tag)
    return nfc_tag_read_payload(tag)


@router.post("/tags/{tag_id}/replace", response_model=AttendanceNfcTagRead)
def replace_nfc_tag(
    tag_id: str,
    payload: AttendanceNfcTagReplaceRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    _require_nfc_manager(db, current_user)
    old_tag = _tag_or_404(db, tag_id)
    _member_or_404(db, str(old_tag.member_id))
    _revoke_tag(old_tag, current_user=current_user, new_status="replaced")
    db.flush()
    new_tag = _create_tag(
        db,
        payload=payload,
        member_id=old_tag.member_id,
        current_user=current_user,
    )
    create_audit_log(
        db,
        action="attendance_nfc_tag_replaced",
        user_id=current_user.id,
        entity_type="attendance_nfc_tag",
        entity_id=new_tag.id,
        new_value={
            "member_id": str(new_tag.member_id),
            "masked_tag": mask_nfc_tag_hash(new_tag.tag_uid_hash),
            "old_tag_id": str(old_tag.id),
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(new_tag)
    return nfc_tag_read_payload(new_tag)


@router.get("/tags", response_model=list[AttendanceNfcTagRead])
def list_nfc_tags(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    status_filter: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
):
    _require_nfc_manager(db, current_user)
    query = db.query(AttendanceNfcTag)
    if status_filter:
        query = query.filter(AttendanceNfcTag.status == status_filter)
    tags = query.order_by(AttendanceNfcTag.created_at.desc()).limit(limit).all()
    return [nfc_tag_read_payload(tag) for tag in tags]
