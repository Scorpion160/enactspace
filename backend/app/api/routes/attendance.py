import csv
from io import StringIO
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
)
from app.core.roles import (
    ALUMNI_ROLE,
    GLOBAL_MANAGEMENT_ROLES,
    SECRETARIAT_ROLES,
)
from app.db.database import get_db
from app.models.attendance import (
    AttendanceExpectedMember,
    AttendanceRecord,
    AttendanceSession,
    AttendanceSetting,
)
from app.models.finance import Fee, FinancialAccount
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.attendance import (
    AttendanceCheckIn,
    AttendanceExpectedMemberCreate,
    AttendanceExpectedMemberRead,
    AttendanceJustificationReview,
    AttendanceJustificationSubmit,
    AttendanceManualCreate,
    AttendanceRecordCreate,
    AttendanceRecordRead,
    AttendanceRecordUpdate,
    AttendanceSettingRead,
    AttendanceSettingsUpdate,
    AttendanceSessionCreate,
    AttendanceSessionRead,
    AttendanceSessionUpdate,
)
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.notification_service import notify_user, notify_users

router = APIRouter(prefix="/attendance", tags=["Presences"])

SESSION_STATUSES = {"draft", "open", "closed", "archived"}
SESSION_TYPES = {
    "general_meeting",
    "pole_meeting",
    "project_meeting",
    "field_activity",
    "training",
    "event",
    "exceptional",
}
SCOPE_TYPES = {"club", "pole", "project", "group"}

CANONICAL_STATUS_BY_ALIAS = {
    "present": "present",
    "late": "late",
    "retard": "late",
    "absent": "absent",
    "absence": "absent",
    "absent_non_justifie": "absent",
    "absence_non_justifiee": "absent",
    "justified_absence": "justified_absence",
    "absent_justifie": "justified_absence",
    "absence_justifiee": "justified_absence",
    "excused": "excused",
    "excuse": "excused",
    "not_recorded": "not_recorded",
    "mission_externe": "excused",
}
VALID_JUSTIFICATION_STATUSES = {
    "not_submitted",
    "pending",
    "approved",
    "rejected",
    "expired",
}
ABSENCE_STATUSES = {"absent", "justified_absence"}
POLE_MANAGER_POSITIONS = {"chef_pole", "adjoint_chef_pole"}
PROJECT_MANAGER_POSITIONS = {"chef_projet", "adjoint_chef_projet"}
DEFAULT_ATTENDANCE_SETTINGS = {
    "montant_absence_non_justifiee": (
        "500",
        "Montant applique pour une absence non justifiee.",
    ),
    "montant_retard": ("0", "Montant applique pour un retard sanctionnable."),
    "seuil_avertissement_absences": (
        "3",
        "Nombre d'absences non justifiees avant avertissement.",
    ),
    "seuil_retards": ("3", "Nombre de retards avant avertissement."),
    "delai_max_justification": (
        "72",
        "Delai maximum de justification en heures.",
    ),
    "debut_application_sanctions": (
        "",
        "Date ISO de debut d'application des sanctions.",
    ),
}


def _ensure_attendance_settings(db: Session) -> list[AttendanceSetting]:
    settings = []
    for key, (default_value, description) in DEFAULT_ATTENDANCE_SETTINGS.items():
        setting = db.query(AttendanceSetting).filter(AttendanceSetting.key == key).first()
        if not setting:
            setting = AttendanceSetting(
                key=key,
                value=default_value,
                description=description,
            )
            db.add(setting)
            db.flush()
        settings.append(setting)
    return settings


def _setting_value(db: Session, key: str) -> str:
    _ensure_attendance_settings(db)
    setting = db.query(AttendanceSetting).filter(AttendanceSetting.key == key).first()
    return setting.value if setting else DEFAULT_ATTENDANCE_SETTINGS[key][0]


def _setting_float(db: Session, key: str) -> float:
    try:
        return float(_setting_value(db, key) or 0)
    except ValueError:
        return 0


def _sanctions_started(db: Session) -> bool:
    raw = _setting_value(db, "debut_application_sanctions")
    if not raw:
        return True
    try:
        started_at = datetime.fromisoformat(raw)
    except ValueError:
        return True
    return datetime.utcnow() >= started_at


def _ensure_financial_account(db: Session, user_id) -> FinancialAccount:
    account = db.query(FinancialAccount).filter(FinancialAccount.user_id == user_id).first()
    if not account:
        account = FinancialAccount(user_id=user_id, balance_due=0, total_paid=0)
        db.add(account)
        db.flush()
    return account


def _remove_attendance_penalty(db: Session, record: AttendanceRecord) -> None:
    fee = db.query(Fee).filter(Fee.related_attendance_id == record.id).first()
    if fee and fee.status == "unpaid":
        account = _ensure_financial_account(db, record.user_id)
        account.balance_due = max(0, float(account.balance_due or 0) - float(fee.amount or 0))
        account.updated_at = datetime.utcnow()
        db.delete(fee)
    record.penalty_amount = 0
    record.penalty_fee_id = None


def _attendance_penalty_amount(db: Session, record: AttendanceRecord) -> float:
    if not _sanctions_started(db):
        return 0
    if record.status == "late":
        return _setting_float(db, "montant_retard")
    if record.status == "absent" and record.justification_status in {
        "not_submitted",
        "rejected",
        "expired",
    }:
        return _setting_float(db, "montant_absence_non_justifiee")
    return 0


def _sync_attendance_penalty(
    db: Session,
    record: AttendanceRecord,
    current_user: User,
) -> None:
    amount = _attendance_penalty_amount(db, record)
    existing_fee = db.query(Fee).filter(Fee.related_attendance_id == record.id).first()

    if amount <= 0:
        _remove_attendance_penalty(db, record)
        return

    label = (
        "Penalite de retard"
        if record.status == "late"
        else "Penalite absence non justifiee"
    )
    fee_type = "penalite_retard" if record.status == "late" else "penalite_absence"

    if existing_fee:
        previous_amount = float(existing_fee.amount or 0)
        existing_fee.amount = amount
        existing_fee.label = label
        existing_fee.type = fee_type
        existing_fee.updated_at = datetime.utcnow()
        record.penalty_amount = amount
        record.penalty_fee_id = existing_fee.id
        account = _ensure_financial_account(db, record.user_id)
        account.balance_due = max(
            0,
            float(account.balance_due or 0) - previous_amount + amount,
        )
        account.updated_at = datetime.utcnow()
        return

    fee = Fee(
        user_id=record.user_id,
        type=fee_type,
        label=label,
        amount=amount,
        amount_paid=0,
        status="unpaid",
        due_date=datetime.utcnow().date(),
        related_attendance_id=record.id,
        created_by=current_user.id,
    )
    db.add(fee)
    db.flush()

    account = _ensure_financial_account(db, record.user_id)
    account.balance_due = float(account.balance_due or 0) + amount
    account.updated_at = datetime.utcnow()

    record.penalty_amount = amount
    record.penalty_fee_id = fee.id
    notify_user(
        db,
        user_id=record.user_id,
        title="Absence non justifiee" if record.status == "absent" else "Retard",
        message=(
            f"Une sanction de {amount:.0f} FCFA peut etre appliquee "
            "selon le reglement."
        ),
        notification_type="finance_penalty",
        related_type="attendance_record",
        related_id=record.id,
        dedupe=True,
    )


def _roles(db: Session, user: User) -> set[str]:
    return get_user_role_names(db, user.id)


def _is_global_attendance_manager(db: Session, user: User) -> bool:
    return bool(_roles(db, user).intersection(SECRETARIAT_ROLES))


def _is_alumni(db: Session, user: User) -> bool:
    roles = _roles(db, user)
    return (
        ALUMNI_ROLE in roles
        or user.status == "alumni"
        or user.profile_type == "alumni"
    )


def _managed_pole_ids(db: Session, user: User) -> list:
    if _roles(db, user).intersection(GLOBAL_MANAGEMENT_ROLES | SECRETARIAT_ROLES):
        return [row[0] for row in db.query(PoleMember.pole_id).distinct().all()]
    return [
        row[0]
        for row in db.query(PoleMember.pole_id)
        .filter(
            PoleMember.user_id == user.id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
            PoleMember.position.in_(POLE_MANAGER_POSITIONS),
        )
        .all()
    ]


def _managed_project_ids(db: Session, user: User) -> list:
    if _roles(db, user).intersection(GLOBAL_MANAGEMENT_ROLES | SECRETARIAT_ROLES):
        return [row[0] for row in db.query(ProjectMember.project_id).distinct().all()]
    return [
        row[0]
        for row in db.query(ProjectMember.project_id)
        .filter(
            ProjectMember.user_id == user.id,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
            ProjectMember.position.in_(PROJECT_MANAGER_POSITIONS),
        )
        .all()
    ]


def _can_manage_session(db: Session, user: User, session: AttendanceSession) -> bool:
    if _is_global_attendance_manager(db, user):
        return True
    if session.created_by == user.id:
        return True
    if session.pole_id and session.pole_id in _managed_pole_ids(db, user):
        return True
    if session.project_id and session.project_id in _managed_project_ids(db, user):
        return True
    return False


def _require_can_manage_session(
    db: Session,
    user: User,
    session: AttendanceSession,
) -> None:
    if not _can_manage_session(db, user, session):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission insuffisante pour gerer cette seance",
        )


def _normalize_session_status(value: str | None, *, is_closed: bool = False) -> str:
    if is_closed:
        return "closed"
    if not value:
        return "draft"
    normalized = value.strip().lower()
    if normalized not in SESSION_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de seance invalide",
        )
    return normalized


def _normalize_session_type(value: str | None) -> str:
    normalized = (value or "general_meeting").strip().lower()
    if normalized not in SESSION_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de seance invalide",
        )
    return normalized


def _normalize_scope_type(value: str | None, payload=None) -> str:
    if value:
        normalized = value.strip().lower()
    elif getattr(payload, "project_id", None):
        normalized = "project"
    elif getattr(payload, "pole_id", None):
        normalized = "pole"
    else:
        normalized = "club"

    if normalized not in SCOPE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Perimetre de seance invalide",
        )
    return normalized


def _normalize_attendance_status(value: str) -> str:
    normalized = CANONICAL_STATUS_BY_ALIAS.get(value.strip().lower())
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de presence invalide",
        )
    return normalized


def _normalize_justification_status(value: str | None, attendance_status: str) -> str:
    if value:
        normalized = value.strip().lower()
        if normalized not in VALID_JUSTIFICATION_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut de justification invalide",
            )
        return normalized
    if attendance_status == "justified_absence":
        return "approved"
    if attendance_status == "absent":
        return "not_submitted"
    return "not_submitted"


def _calculate_delay_minutes(
    session: AttendanceSession,
    attendance_status: str,
    arrival_time: datetime | None,
    explicit_delay: int | None,
) -> int | None:
    if explicit_delay is not None:
        return max(0, explicit_delay)
    if attendance_status != "late":
        return None
    if not arrival_time:
        return session.late_after_minutes
    reference_time = session.checkin_start or session.scheduled_at or session.created_at
    delay = int((arrival_time - reference_time).total_seconds() // 60)
    return max(0, delay)


def _session_query_for_user(db: Session, current_user: User):
    query = db.query(AttendanceSession)
    if _is_global_attendance_manager(db, current_user):
        return query
    if _is_alumni(db, current_user):
        return query.filter(False)

    expected_session_ids = (
        db.query(AttendanceExpectedMember.session_id)
        .filter(AttendanceExpectedMember.user_id == current_user.id)
        .subquery()
    )
    managed_poles = _managed_pole_ids(db, current_user)
    managed_projects = _managed_project_ids(db, current_user)

    filters = [
        AttendanceSession.created_by == current_user.id,
        AttendanceSession.id.in_(expected_session_ids),
    ]
    if managed_poles:
        filters.append(AttendanceSession.pole_id.in_(managed_poles))
    if managed_projects:
        filters.append(AttendanceSession.project_id.in_(managed_projects))

    return query.filter(or_(*filters))


def _attendance_session_payload(
    db: Session,
    current_user: User,
    session: AttendanceSession,
) -> dict:
    if session.is_closed and session.status != "closed":
        session.status = "closed"

    data = AttendanceSessionRead.model_validate(session).model_dump()
    data["can_manage"] = _can_manage_session(db, current_user, session)
    if not data["can_manage"]:
        data["qr_token"] = None
    data["expected_count"] = (
        db.query(AttendanceExpectedMember.id)
        .filter(AttendanceExpectedMember.session_id == session.id)
        .count()
    )
    data["recorded_count"] = (
        db.query(AttendanceRecord.id)
        .filter(AttendanceRecord.session_id == session.id)
        .count()
    )
    return data


def _get_session_or_404(db: Session, session_id: str) -> AttendanceSession:
    session = (
        db.query(AttendanceSession).filter(AttendanceSession.id == session_id).first()
    )
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Seance de presence introuvable",
        )
    return session


def _validate_session_payload_permissions(
    db: Session,
    current_user: User,
    scope_type: str,
    pole_id,
    project_id,
) -> None:
    if _is_global_attendance_manager(db, current_user):
        return
    if scope_type == "pole" and pole_id in _managed_pole_ids(db, current_user):
        return
    if scope_type == "project" and project_id in _managed_project_ids(db, current_user):
        return
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Permission insuffisante pour creer cette seance",
    )


def _expected_member_ids_for_scope(
    db: Session,
    scope_type: str,
    pole_id=None,
    project_id=None,
) -> list:
    if scope_type == "pole" and pole_id:
        return [
            row[0]
            for row in db.query(PoleMember.user_id)
            .filter(
                PoleMember.pole_id == pole_id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            )
            .all()
        ]
    if scope_type == "project" and project_id:
        return [
            row[0]
            for row in db.query(ProjectMember.user_id)
            .filter(
                ProjectMember.project_id == project_id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
            )
            .all()
        ]
    if scope_type == "club":
        return [
            row[0]
            for row in db.query(User.id)
            .filter(
                User.is_active.is_(True),
                User.status == "active",
                User.profile_type != "alumni",
            )
            .all()
        ]
    return []


def _ensure_expected_members(
    db: Session,
    session: AttendanceSession,
) -> int:
    user_ids = _expected_member_ids_for_scope(
        db,
        session.scope_type,
        session.pole_id,
        session.project_id,
    )
    created = 0
    for user_id in user_ids:
        existing = (
            db.query(AttendanceExpectedMember.id)
            .filter(
                AttendanceExpectedMember.session_id == session.id,
                AttendanceExpectedMember.user_id == user_id,
            )
            .first()
        )
        if existing:
            continue
        db.add(
            AttendanceExpectedMember(
                session_id=session.id,
                user_id=user_id,
                is_required=True,
            )
        )
        created += 1
    return created


def _upsert_record(
    db: Session,
    session: AttendanceSession,
    current_user: User,
    *,
    user_id,
    attendance_status: str,
    arrival_time: datetime | None = None,
    delay_minutes: int | None = None,
    justification: str | None = None,
    justification_status: str | None = None,
    justification_reason: str | None = None,
    justification_file_id=None,
    justification_file_url: str | None = None,
    note: str | None = None,
) -> AttendanceRecord:
    normalized_status = _normalize_attendance_status(attendance_status)
    normalized_justification = _normalize_justification_status(
        justification_status,
        normalized_status,
    )
    now = datetime.utcnow()
    arrival = arrival_time if arrival_time is not None else now
    if normalized_status in {"absent", "justified_absence", "excused", "not_recorded"}:
        arrival = None

    record = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.user_id == user_id,
        )
        .first()
    )
    if not record:
        record = AttendanceRecord(session_id=session.id, user_id=user_id)
        db.add(record)

    record.status = normalized_status
    record.checkin_time = arrival
    record.delay_minutes = _calculate_delay_minutes(
        session,
        normalized_status,
        arrival,
        delay_minutes,
    )
    record.recorded_by = current_user.id
    record.recorded_at = now
    record.justification = justification
    record.justification_status = normalized_justification
    record.justification_reason = justification_reason or justification
    record.justification_file_id = justification_file_id
    record.justification_file_url = justification_file_url
    record.is_justified = normalized_status in {"justified_absence", "excused"} or (
        normalized_justification == "approved"
    )
    record.note = note
    record.updated_at = now
    db.flush()
    _sync_attendance_penalty(db, record, current_user)
    return record


def _notify_record_change(
    db: Session,
    record: AttendanceRecord,
    session: AttendanceSession,
) -> None:
    if record.status == "late":
        notify_user(
            db,
            user_id=record.user_id,
            title="Retard enregistre",
            message=f"Vous avez ete marque en retard pour {session.title}.",
            notification_type="attendance_late",
            related_type="attendance_record",
            related_id=record.id,
            dedupe=True,
        )


def _get_record_or_404(db: Session, record_id: str) -> AttendanceRecord:
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ligne de presence introuvable",
        )
    return record


def _notify_justification_reviewers(
    db: Session,
    record: AttendanceRecord,
    session: AttendanceSession,
) -> None:
    reviewer_ids = {value for value in [session.created_by, record.recorded_by] if value}
    if reviewer_ids:
        notify_users(
            db,
            user_ids=list(reviewer_ids),
            title="Justification d'absence",
            message=f"Une justification a ete soumise pour {session.title}.",
            notification_type="attendance_justification_pending",
            related_type="attendance_record",
            related_id=record.id,
            dedupe=True,
        )
    elif record.status in ABSENCE_STATUSES:
        notify_user(
            db,
            user_id=record.user_id,
            title="Absence enregistree",
            message=f"Vous avez ete marque absent pour {session.title}.",
            notification_type="attendance_absent",
            related_type="attendance_record",
            related_id=record.id,
            dedupe=True,
        )


def _compute_checkin_status(session: AttendanceSession, now: datetime) -> str:
    reference_time = session.checkin_start or session.scheduled_at or session.created_at
    late_limit = reference_time + timedelta(minutes=session.late_after_minutes)
    return "late" if now > late_limit else "present"


def _records_query_for_user(db: Session, current_user: User):
    query = db.query(AttendanceRecord).join(
        AttendanceSession,
        AttendanceSession.id == AttendanceRecord.session_id,
    )
    if _is_global_attendance_manager(db, current_user):
        return query
    if _is_alumni(db, current_user):
        return query.filter(False)

    visible_session_ids = _session_query_for_user(db, current_user).with_entities(
        AttendanceSession.id
    )
    return query.filter(
        or_(
            AttendanceRecord.user_id == current_user.id,
            AttendanceRecord.session_id.in_(visible_session_ids),
        )
    )


def _apply_report_filters(
    query,
    *,
    month: str | None,
    pole_id: str | None,
    project_id: str | None,
    member_id: str | None,
    session_type: str | None,
):
    if month:
        try:
            start = datetime.strptime(month, "%Y-%m")
            end = datetime(start.year + (1 if start.month == 12 else 0), 1, 1)
            if start.month < 12:
                end = datetime(start.year, start.month + 1, 1)
            query = query.filter(
                AttendanceSession.scheduled_at >= start,
                AttendanceSession.scheduled_at < end,
            )
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Le mois doit etre au format YYYY-MM",
            )
    if pole_id:
        query = query.filter(AttendanceSession.pole_id == pole_id)
    if project_id:
        query = query.filter(AttendanceSession.project_id == project_id)
    if member_id:
        query = query.filter(AttendanceRecord.user_id == member_id)
    if session_type:
        query = query.filter(AttendanceSession.session_type == session_type)
    return query


def _attendance_stats_from_records(db: Session, records: list[AttendanceRecord]) -> dict:
    session_ids = {record.session_id for record in records}
    present = sum(1 for record in records if record.status == "present")
    late = sum(1 for record in records if record.status == "late")
    absent = sum(1 for record in records if record.status == "absent")
    justified = sum(
        1
        for record in records
        if record.status in {"justified_absence", "excused"}
        or record.justification_status == "approved"
    )
    attended = present + late
    total = len(records)
    threshold = int(_setting_float(db, "seuil_avertissement_absences") or 3)
    sanctions_potential = sum(float(record.penalty_amount or 0) for record in records)
    members_to_watch = []
    absent_by_user = {}
    for record in records:
        if record.status == "absent" and record.justification_status != "approved":
            absent_by_user[record.user_id] = absent_by_user.get(record.user_id, 0) + 1
    for user_id, count in absent_by_user.items():
        if count > threshold:
            user = db.query(User).filter(User.id == user_id).first()
            members_to_watch.append(
                {
                    "user_id": str(user_id),
                    "display_name": _display_user(user) if user else str(user_id),
                    "unjustified_absences": count,
                }
            )

    return {
        "sessions_count": len(session_ids),
        "records_count": total,
        "present": present,
        "late": late,
        "absent": absent,
        "justified_absences": justified,
        "unjustified_absences": absent,
        "attendance_rate": round((attended / total) * 100, 2) if total else 0,
        "members_to_watch": members_to_watch,
        "sanctions_potential": sanctions_potential,
        "sanctions_validated": sanctions_potential,
    }


def _display_user(user: User) -> str:
    if not user:
        return ""
    value = f"{user.first_name or ''} {user.last_name or ''}".strip()
    return value or user.email


@router.get("/sessions", response_model=list[AttendanceSessionRead])
def list_attendance_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    sessions = (
        _session_query_for_user(db, current_user)
        .order_by(AttendanceSession.created_at.desc())
        .all()
    )
    return [
        _attendance_session_payload(db, current_user, session)
        for session in sessions
    ]


@router.get("/settings", response_model=list[AttendanceSettingRead])
def list_attendance_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if not _is_global_attendance_manager(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Parametres reserves au secretariat",
        )
    settings = _ensure_attendance_settings(db)
    db.commit()
    return settings


@router.patch("/settings", response_model=list[AttendanceSettingRead])
def update_attendance_settings(
    payload: AttendanceSettingsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if not _is_global_attendance_manager(db, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Parametres reserves au secretariat",
        )
    _ensure_attendance_settings(db)
    updates = payload.model_dump(exclude_unset=True)
    for key, value in updates.items():
        setting = db.query(AttendanceSetting).filter(AttendanceSetting.key == key).first()
        if setting:
            setting.value = value.isoformat() if hasattr(value, "isoformat") else str(value)
            setting.updated_at = datetime.utcnow()
    db.commit()
    return _ensure_attendance_settings(db)


@router.get("/stats", response_model=dict)
def get_attendance_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    month: Optional[str] = Query(default=None),
    pole_id: Optional[str] = Query(default=None),
    project_id: Optional[str] = Query(default=None),
    member_id: Optional[str] = Query(default=None),
    session_type: Optional[str] = Query(default=None),
):
    query = _records_query_for_user(db, current_user)
    query = _apply_report_filters(
        query,
        month=month,
        pole_id=pole_id,
        project_id=project_id,
        member_id=member_id,
        session_type=session_type,
    )
    records = query.all()
    return _attendance_stats_from_records(db, records)


@router.get("/monthly-report", response_model=list[dict])
def get_attendance_monthly_report(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    month: Optional[str] = Query(default=None),
    pole_id: Optional[str] = Query(default=None),
    project_id: Optional[str] = Query(default=None),
    session_type: Optional[str] = Query(default=None),
):
    query = _records_query_for_user(db, current_user)
    query = _apply_report_filters(
        query,
        month=month,
        pole_id=pole_id,
        project_id=project_id,
        member_id=None,
        session_type=session_type,
    )
    records = query.all()
    by_user: dict = {}
    for record in records:
        item = by_user.setdefault(
            record.user_id,
            {
                "user_id": str(record.user_id),
                "present": 0,
                "late": 0,
                "absent": 0,
                "justified_absences": 0,
                "unjustified_absences": 0,
                "amount_due": 0,
                "dates": [],
            },
        )
        if record.status == "present":
            item["present"] += 1
        elif record.status == "late":
            item["late"] += 1
        elif record.status in {"justified_absence", "excused"}:
            item["justified_absences"] += 1
        elif record.status == "absent":
            item["absent"] += 1
            item["unjustified_absences"] += 1
        item["amount_due"] += float(record.penalty_amount or 0)
        session_date = (
            record.checkin_time
            or db.query(AttendanceSession.scheduled_at)
            .filter(AttendanceSession.id == record.session_id)
            .scalar()
        )
        if session_date:
            item["dates"].append(session_date.date().isoformat())

    rows = []
    for user_id, item in by_user.items():
        user = db.query(User).filter(User.id == user_id).first()
        item["display_name"] = _display_user(user) if user else item["user_id"]
        item["warning"] = item["unjustified_absences"] > int(
            _setting_float(db, "seuil_avertissement_absences") or 3
        )
        rows.append(item)
    return sorted(rows, key=lambda row: row["display_name"])


@router.get("/monthly-export")
def export_attendance_monthly_report(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    month: Optional[str] = Query(default=None),
    pole_id: Optional[str] = Query(default=None),
    project_id: Optional[str] = Query(default=None),
    session_type: Optional[str] = Query(default=None),
):
    rows = get_attendance_monthly_report(
        db=db,
        current_user=current_user,
        month=month,
        pole_id=pole_id,
        project_id=project_id,
        session_type=session_type,
    )
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "Nom",
            "Prenom",
            "Genre",
            "Telephone",
            "Pole coeur",
            "Nombre presences",
            "Nombre retards",
            "Nombre absences",
            "Nombre absences justifiees",
            "Nombre absences non justifiees",
            "Montant a payer",
            "Avertissement",
            "Detail des dates",
        ]
    )
    for row in rows:
        user = db.query(User).filter(User.id == row["user_id"]).first()
        writer.writerow(
            [
                user.last_name if user else "",
                user.first_name if user else "",
                user.gender if user else "",
                user.phone if user else "",
                user.department if user else "",
                row["present"],
                row["late"],
                row["absent"],
                row["justified_absences"],
                row["unjustified_absences"],
                row["amount_due"],
                "Oui" if row["warning"] else "Non",
                ", ".join(row["dates"]),
            ]
        )
    filename = f"attendance-{month or 'report'}.csv"
    return Response(
        content=output.getvalue(),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/member/{member_id}/summary", response_model=dict)
def get_member_attendance_summary(
    member_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    month: Optional[str] = Query(default=None),
):
    if str(current_user.id) != member_id and not _is_global_attendance_manager(
        db,
        current_user,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Synthese membre non accessible",
        )
    query = _records_query_for_user(db, current_user)
    query = _apply_report_filters(
        query,
        month=month,
        pole_id=None,
        project_id=None,
        member_id=member_id,
        session_type=None,
    )
    records = query.all()
    return _attendance_stats_from_records(db, records)


@router.post("/sessions", response_model=AttendanceSessionRead)
def create_attendance_session(
    payload: AttendanceSessionCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    scope_type = _normalize_scope_type(payload.scope_type, payload)
    _validate_session_payload_permissions(
        db,
        current_user,
        scope_type,
        payload.pole_id,
        payload.project_id,
    )

    session = AttendanceSession(
        title=payload.title.strip(),
        description=payload.description,
        session_type=_normalize_session_type(payload.session_type),
        scope_type=scope_type,
        group_name=payload.group_name,
        event_id=payload.event_id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        created_by=current_user.id,
        qr_token=payload.qr_token,
        scheduled_at=payload.scheduled_at,
        checkin_start=payload.checkin_start,
        checkin_end=payload.checkin_end,
        late_after_minutes=payload.late_after_minutes,
        status=_normalize_session_status(payload.status),
        is_closed=payload.status == "closed",
        notes=payload.notes,
    )
    db.add(session)
    db.flush()
    generated = _ensure_expected_members(db, session)

    create_audit_log(
        db=db,
        action="creation_seance_presence",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id,
        new_value={
            "title": session.title,
            "scope_type": session.scope_type,
            "expected_generated": generated,
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(session)
    return _attendance_session_payload(db, current_user, session)


@router.get("/sessions/{session_id}", response_model=AttendanceSessionRead)
def get_attendance_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    visible = _session_query_for_user(db, current_user).filter(
        AttendanceSession.id == session.id
    ).first()
    if not visible:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seance non accessible",
        )
    return _attendance_session_payload(db, current_user, session)


@router.patch("/sessions/{session_id}", response_model=AttendanceSessionRead)
def update_attendance_session(
    session_id: str,
    payload: AttendanceSessionUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)

    old_value = _attendance_session_payload(db, current_user, session)
    updates = payload.model_dump(exclude_unset=True)
    if "session_type" in updates:
        updates["session_type"] = _normalize_session_type(updates["session_type"])
    if "scope_type" in updates:
        updates["scope_type"] = _normalize_scope_type(updates["scope_type"], payload)
    if "status" in updates:
        updates["status"] = _normalize_session_status(
            updates["status"],
            is_closed=updates["status"] == "closed",
        )
        updates["is_closed"] = updates["status"] == "closed"

    for field, value in updates.items():
        setattr(session, field, value)
    session.updated_at = datetime.utcnow()
    generated = _ensure_expected_members(db, session)

    create_audit_log(
        db=db,
        action="modification_seance_presence",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id,
        old_value=old_value,
        new_value={**updates, "expected_generated": generated},
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(session)
    return _attendance_session_payload(db, current_user, session)


@router.post("/sessions/{session_id}/open", response_model=AttendanceSessionRead)
def open_attendance_session(
    session_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)
    if session.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette seance est deja cloturee",
        )

    session.status = "open"
    if session.checkin_start is None:
        session.checkin_start = datetime.utcnow()
    session.updated_at = datetime.utcnow()
    generated = _ensure_expected_members(db, session)

    notify_users(
        db,
        user_ids=[
            row[0]
            for row in db.query(AttendanceExpectedMember.user_id)
            .filter(AttendanceExpectedMember.session_id == session.id)
            .all()
        ],
        title="Appel ouvert",
        message=f"L'appel est ouvert pour {session.title}.",
        notification_type="attendance_session_open",
        related_type="attendance_session",
        related_id=session.id,
        dedupe=True,
    )
    create_audit_log(
        db=db,
        action="ouverture_seance_presence",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id,
        new_value={"status": "open", "expected_generated": generated},
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(session)
    return _attendance_session_payload(db, current_user, session)


@router.post("/sessions/{session_id}/close", response_model=dict)
def close_attendance_session(
    session_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)

    if session.is_closed:
        return {"ok": True, "message": "La seance etait deja cloturee"}

    _ensure_expected_members(db, session)
    expected_members = (
        db.query(AttendanceExpectedMember)
        .filter(AttendanceExpectedMember.session_id == session.id)
        .all()
    )
    created_absences = 0
    for expected in expected_members:
        existing = (
            db.query(AttendanceRecord.id)
            .filter(
                AttendanceRecord.session_id == session.id,
                AttendanceRecord.user_id == expected.user_id,
            )
            .first()
        )
        if existing:
            continue
        record = _upsert_record(
            db,
            session,
            current_user,
            user_id=expected.user_id,
            attendance_status="absent",
            justification_status="not_submitted",
        )
        _notify_record_change(db, record, session)
        created_absences += 1

    session.status = "closed"
    session.is_closed = True
    session.updated_at = datetime.utcnow()

    create_audit_log(
        db=db,
        action="cloture_seance_presence",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id,
        old_value={"status": "open", "is_closed": False},
        new_value={"status": "closed", "absences_generated": created_absences},
        ip_address=get_client_ip(request),
    )
    db.commit()
    return {
        "ok": True,
        "message": "Seance de presence cloturee",
        "absences_generated": created_absences,
    }


@router.get(
    "/sessions/{session_id}/records",
    response_model=list[AttendanceRecordRead],
)
def list_session_attendance_records(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)
    return (
        db.query(AttendanceRecord)
        .filter(AttendanceRecord.session_id == session.id)
        .order_by(AttendanceRecord.created_at.desc())
        .all()
    )


@router.post(
    "/sessions/{session_id}/records",
    response_model=AttendanceRecordRead,
)
def create_session_attendance_record(
    session_id: str,
    payload: AttendanceRecordCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)
    if session.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette seance est deja cloturee",
        )

    record = _upsert_record(
        db,
        session,
        current_user,
        user_id=payload.user_id,
        attendance_status=payload.status,
        arrival_time=payload.arrival_time,
        delay_minutes=payload.delay_minutes,
        justification=payload.justification,
        justification_status=payload.justification_status,
        justification_reason=payload.justification_reason,
        justification_file_id=payload.justification_file_id,
        justification_file_url=payload.justification_file_url,
        note=payload.note,
    )
    _notify_record_change(db, record, session)
    db.commit()
    db.refresh(record)
    return record


@router.patch("/records/{record_id}", response_model=AttendanceRecordRead)
def update_attendance_record(
    record_id: str,
    payload: AttendanceRecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    record = db.query(AttendanceRecord).filter(AttendanceRecord.id == record_id).first()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Ligne de presence introuvable",
        )
    session = _get_session_or_404(db, str(record.session_id))
    _require_can_manage_session(db, current_user, session)

    record = _upsert_record(
        db,
        session,
        current_user,
        user_id=record.user_id,
        attendance_status=payload.status or record.status,
        arrival_time=payload.arrival_time if payload.arrival_time else record.checkin_time,
        delay_minutes=payload.delay_minutes
        if payload.delay_minutes is not None
        else record.delay_minutes,
        justification=payload.justification
        if payload.justification is not None
        else record.justification,
        justification_status=payload.justification_status
        if payload.justification_status is not None
        else record.justification_status,
        justification_reason=payload.justification_reason
        if payload.justification_reason is not None
        else record.justification_reason,
        justification_file_id=payload.justification_file_id
        if payload.justification_file_id is not None
        else record.justification_file_id,
        justification_file_url=payload.justification_file_url
        if payload.justification_file_url is not None
        else record.justification_file_url,
        note=payload.note if payload.note is not None else record.note,
    )
    _notify_record_change(db, record, session)
    db.commit()
    db.refresh(record)
    return record


@router.post("/records/{record_id}/justify", response_model=AttendanceRecordRead)
def submit_absence_justification(
    record_id: str,
    payload: AttendanceJustificationSubmit,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    record = _get_record_or_404(db, record_id)
    if record.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez justifier que vos propres absences",
        )
    if record.status not in {"absent", "justified_absence"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seule une absence peut etre justifiee",
        )
    reason = payload.reason.strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de justification est obligatoire",
        )

    session = _get_session_or_404(db, str(record.session_id))
    record.justification = reason
    record.justification_reason = reason
    record.justification_status = "pending"
    record.justification_file_id = payload.file_id
    record.justification_file_url = payload.file_url
    record.is_justified = False
    record.updated_at = datetime.utcnow()
    _sync_attendance_penalty(db, record, current_user)
    _notify_justification_reviewers(db, record, session)
    db.commit()
    db.refresh(record)
    return record


@router.post(
    "/records/{record_id}/justification/approve",
    response_model=AttendanceRecordRead,
)
def approve_absence_justification(
    record_id: str,
    payload: AttendanceJustificationReview,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    record = _get_record_or_404(db, record_id)
    session = _get_session_or_404(db, str(record.session_id))
    _require_can_manage_session(db, current_user, session)

    record.status = "justified_absence"
    record.justification_status = "approved"
    record.is_justified = True
    if payload.reason and payload.reason.strip():
        record.note = payload.reason.strip()
    record.updated_at = datetime.utcnow()
    _sync_attendance_penalty(db, record, current_user)
    notify_user(
        db,
        user_id=record.user_id,
        title="Justification approuvee",
        message=f"Votre justification pour {session.title} a ete approuvee.",
        notification_type="attendance_justification_approved",
        related_type="attendance_record",
        related_id=record.id,
        dedupe=True,
    )
    db.commit()
    db.refresh(record)
    return record


@router.post(
    "/records/{record_id}/justification/reject",
    response_model=AttendanceRecordRead,
)
def reject_absence_justification(
    record_id: str,
    payload: AttendanceJustificationReview,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    record = _get_record_or_404(db, record_id)
    session = _get_session_or_404(db, str(record.session_id))
    _require_can_manage_session(db, current_user, session)

    reason = (payload.reason or "").strip()
    if not reason:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le motif de refus est obligatoire",
        )

    record.status = "absent"
    record.justification_status = "rejected"
    record.is_justified = False
    record.note = reason
    record.updated_at = datetime.utcnow()
    _sync_attendance_penalty(db, record, current_user)
    notify_user(
        db,
        user_id=record.user_id,
        title="Justification refusee",
        message=f"Votre justification pour {session.title} a ete refusee: {reason}",
        notification_type="attendance_justification_rejected",
        related_type="attendance_record",
        related_id=record.id,
        dedupe=True,
    )
    db.commit()
    db.refresh(record)
    return record


@router.post("/expected-members", response_model=AttendanceExpectedMemberRead)
def add_expected_member(
    payload: AttendanceExpectedMemberCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, str(payload.session_id))
    _require_can_manage_session(db, current_user, session)

    user = db.query(User).filter(User.id == payload.user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )

    expected_member = (
        db.query(AttendanceExpectedMember)
        .filter(
            AttendanceExpectedMember.session_id == payload.session_id,
            AttendanceExpectedMember.user_id == payload.user_id,
        )
        .first()
    )
    if expected_member:
        return expected_member

    expected_member = AttendanceExpectedMember(
        session_id=payload.session_id,
        user_id=payload.user_id,
        is_required=payload.is_required,
    )
    db.add(expected_member)
    db.commit()
    db.refresh(expected_member)
    return expected_member


@router.get(
    "/expected-members/{session_id}",
    response_model=list[AttendanceExpectedMemberRead],
)
def list_expected_members(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, session_id)
    _require_can_manage_session(db, current_user, session)
    return (
        db.query(AttendanceExpectedMember)
        .filter(AttendanceExpectedMember.session_id == session.id)
        .order_by(AttendanceExpectedMember.created_at.asc())
        .all()
    )


@router.post("/check-in", response_model=AttendanceRecordRead)
def qr_check_in(
    payload: AttendanceCheckIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    now = datetime.utcnow()
    session = (
        db.query(AttendanceSession)
        .filter(
            AttendanceSession.id == payload.session_id,
            AttendanceSession.qr_token == payload.qr_token,
        )
        .first()
    )
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code invalide ou seance introuvable",
        )
    if session.is_closed or session.status == "closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette seance est deja cloturee",
        )
    if session.checkin_start and now < session.checkin_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le pointage n'est pas encore ouvert",
        )
    if session.checkin_end and now > session.checkin_end:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le pointage est termine",
        )

    expected = (
        db.query(AttendanceExpectedMember.id)
        .filter(
            AttendanceExpectedMember.session_id == session.id,
            AttendanceExpectedMember.user_id == current_user.id,
        )
        .first()
    )
    if not expected:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous n'etes pas attendu pour cette seance",
        )

    record = _upsert_record(
        db,
        session,
        current_user,
        user_id=current_user.id,
        attendance_status=_compute_checkin_status(session, now),
        arrival_time=now,
    )
    _notify_record_change(db, record, session)
    db.commit()
    db.refresh(record)
    return record


@router.post("/manual", response_model=AttendanceRecordRead)
def create_manual_attendance(
    payload: AttendanceManualCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    session = _get_session_or_404(db, str(payload.session_id))
    _require_can_manage_session(db, current_user, session)
    if session.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette seance est deja cloturee",
        )

    record = _upsert_record(
        db,
        session,
        current_user,
        user_id=payload.user_id,
        attendance_status=payload.status,
        arrival_time=payload.arrival_time,
        delay_minutes=payload.delay_minutes,
        justification=payload.justification,
        justification_status=payload.justification_status,
        justification_reason=payload.justification_reason,
        justification_file_id=payload.justification_file_id,
        justification_file_url=payload.justification_file_url,
        note=payload.note,
    )
    _notify_record_change(db, record, session)
    db.commit()
    db.refresh(record)
    return record


@router.get("/records", response_model=list[AttendanceRecordRead])
def list_attendance_records(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    user_id: Optional[str] = Query(default=None),
    session_id: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None),
):
    query = db.query(AttendanceRecord)
    if not _is_global_attendance_manager(db, current_user):
        query = query.filter(AttendanceRecord.user_id == current_user.id)
    elif user_id:
        query = query.filter(AttendanceRecord.user_id == user_id)
    if session_id:
        query = query.filter(AttendanceRecord.session_id == session_id)
    if status_filter:
        query = query.filter(
            AttendanceRecord.status == _normalize_attendance_status(status_filter)
        )
    return query.order_by(AttendanceRecord.created_at.desc()).all()


@router.get("/records/{session_id}", response_model=list[AttendanceRecordRead])
def list_attendance_records_by_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return list_session_attendance_records(session_id, db, current_user)


@router.get("/my-records", response_model=list[AttendanceRecordRead])
def list_my_attendance_records(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    status_filter: Optional[str] = Query(default=None),
):
    query = db.query(AttendanceRecord).filter(AttendanceRecord.user_id == current_user.id)
    if status_filter:
        query = query.filter(
            AttendanceRecord.status == _normalize_attendance_status(status_filter)
        )
    return query.order_by(AttendanceRecord.created_at.desc()).all()


# Backward compatible alias kept for older imports/tests.
can_manage_attendance = _is_global_attendance_manager
