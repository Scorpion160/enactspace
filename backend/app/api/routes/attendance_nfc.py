from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
)
from app.core.roles import SECRETARIAT_ROLES
from app.core.config import settings
from app.db.database import get_db
from app.models.attendance import (
    AttendanceExpectedMember,
    AttendanceNfcTag,
    AttendanceRecord,
    AttendanceSession,
)
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.attendance import (
    AttendanceNfcCheckInRequest,
    AttendanceNfcCheckInResult,
    AttendanceNfcTagEnrollRequest,
    AttendanceNfcTagRead,
    AttendanceNfcTagReplaceRequest,
    AttendanceNfcTagRevokeRequest,
)
from app.api.routes.attendance import (
    _compute_checkin_status,
    _ensure_expected_members,
    _notify_record_change,
    _upsert_record,
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
POLE_MANAGER_POSITIONS = {"chef_pole", "adjoint_chef_pole"}
PROJECT_MANAGER_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


def _display_user(user: User | None) -> str | None:
    if not user:
        return None
    return f"{user.first_name} {user.last_name}".strip() or user.email


def _nfc_scan_message(result: str, attendance_status: str | None = None) -> str:
    if result == "present" or attendance_status == "present":
        return "Presence enregistree par NFC."
    if result == "late" or attendance_status == "late":
        return "Retard enregistre par NFC."
    messages = {
        "already_recorded": "Ce membre a deja ete pointe.",
        "unknown_tag": "Badge NFC inconnu.",
        "revoked_tag": "Badge NFC revoque ou inactif.",
        "session_closed": "Cette seance est fermee.",
        "not_eligible": "Ce membre n'est pas attendu pour cette seance.",
        "nfc_disabled": "Le pointage NFC est desactive.",
    }
    return messages.get(result, "Pointage NFC indisponible.")


def _nfc_scan_result(
    result: str,
    *,
    success: bool = False,
    member: User | None = None,
    attendance_status: str | None = None,
    recorded_at: datetime | None = None,
) -> AttendanceNfcCheckInResult:
    return AttendanceNfcCheckInResult(
        success=success,
        result=result,
        member_display_name=_display_user(member),
        attendance_status=attendance_status,
        message=_nfc_scan_message(result, attendance_status),
        recorded_at=recorded_at,
    )


def _can_manage_session(db: Session, current_user: User, session: AttendanceSession):
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(SECRETARIAT_ROLES):
        return True
    if session.created_by == current_user.id:
        return True
    if session.pole_id:
        pole_manager = (
            db.query(PoleMember.id)
            .filter(
                PoleMember.user_id == current_user.id,
                PoleMember.pole_id == session.pole_id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(POLE_MANAGER_POSITIONS),
            )
            .first()
        )
        if pole_manager:
            return True
    if session.project_id:
        project_manager = (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.user_id == current_user.id,
                ProjectMember.project_id == session.project_id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(PROJECT_MANAGER_POSITIONS),
            )
            .first()
        )
        if project_manager:
            return True
    return False


def _audit_nfc_check_in(
    db: Session,
    *,
    request: Request,
    current_user: User,
    result: str,
    session: AttendanceSession | None = None,
    tag: AttendanceNfcTag | None = None,
    record: AttendanceRecord | None = None,
) -> None:
    create_audit_log(
        db,
        action="attendance_nfc_check_in",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id if session else None,
        new_value={
            "result": result,
            "source": "nfc",
            "member_id": str(tag.member_id) if tag else None,
            "tag_id": str(tag.id) if tag else None,
            "masked_tag": mask_nfc_tag_hash(tag.tag_uid_hash) if tag else None,
            "record_id": str(record.id) if record else None,
        },
        ip_address=get_client_ip(request),
    )


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


@router.post("/check-in", response_model=AttendanceNfcCheckInResult)
def nfc_check_in(
    payload: AttendanceNfcCheckInRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = (
        db.query(AttendanceSession)
        .filter(AttendanceSession.id == payload.session_id)
        .first()
    )
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seance de presence introuvable",
        )
    if not _can_manage_session(db, current_user, session):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission insuffisante pour pointer cette seance",
        )

    if not settings.ATTENDANCE_NFC_ENABLED:
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="nfc_disabled",
            session=session,
        )
        db.commit()
        return _nfc_scan_result("nfc_disabled")

    try:
        tag_uid_hash = hash_nfc_tag_payload(payload.tag_payload)
    except ValueError:
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="unknown_tag",
            session=session,
        )
        db.commit()
        return _nfc_scan_result("unknown_tag")

    tag = (
        db.query(AttendanceNfcTag)
        .filter(AttendanceNfcTag.tag_uid_hash == tag_uid_hash)
        .order_by(AttendanceNfcTag.created_at.desc())
        .first()
    )
    if not tag:
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="unknown_tag",
            session=session,
        )
        db.commit()
        return _nfc_scan_result("unknown_tag")

    member = db.query(User).filter(User.id == tag.member_id).first()
    if tag.status != ACTIVE_NFC_TAG_STATUS:
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="revoked_tag",
            session=session,
            tag=tag,
        )
        db.commit()
        return _nfc_scan_result("revoked_tag", member=member)

    now = datetime.utcnow()
    if (
        session.is_closed
        or session.status != "open"
        or (session.checkin_start and now < session.checkin_start)
        or (session.checkin_end and now > session.checkin_end)
    ):
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="session_closed",
            session=session,
            tag=tag,
        )
        db.commit()
        return _nfc_scan_result("session_closed", member=member)

    _ensure_expected_members(db, session)
    expected = (
        db.query(AttendanceExpectedMember.id)
        .filter(
            AttendanceExpectedMember.session_id == session.id,
            AttendanceExpectedMember.user_id == tag.member_id,
        )
        .first()
    )
    if not expected:
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="not_eligible",
            session=session,
            tag=tag,
        )
        db.commit()
        return _nfc_scan_result("not_eligible", member=member)

    existing = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.user_id == tag.member_id,
        )
        .first()
    )
    if existing and existing.status != "not_recorded":
        _audit_nfc_check_in(
            db,
            request=request,
            current_user=current_user,
            result="already_recorded",
            session=session,
            tag=tag,
            record=existing,
        )
        db.commit()
        return _nfc_scan_result(
            "already_recorded",
            member=member,
            attendance_status=existing.status,
            recorded_at=existing.recorded_at,
        )

    attendance_status = _compute_checkin_status(session, now)
    record = _upsert_record(
        db,
        session,
        current_user,
        user_id=tag.member_id,
        attendance_status=attendance_status,
        arrival_time=now,
        source="nfc",
    )
    tag.last_used_at = now
    tag.updated_at = now
    _notify_record_change(db, record, session)
    _audit_nfc_check_in(
        db,
        request=request,
        current_user=current_user,
        result=attendance_status,
        session=session,
        tag=tag,
        record=record,
    )
    db.commit()
    db.refresh(record)
    return _nfc_scan_result(
        attendance_status,
        success=True,
        member=member,
        attendance_status=attendance_status,
        recorded_at=record.recorded_at,
    )


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
