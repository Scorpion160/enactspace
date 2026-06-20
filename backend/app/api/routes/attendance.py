import secrets
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.attendance import (
    AttendanceSession,
    AttendanceExpectedMember,
    AttendanceRecord,
)
from app.models.finance import Fee, FinancialAccount
from app.models.user import User
from app.schemas.attendance import (
    AttendanceSessionCreate,
    AttendanceSessionRead,
    AttendanceExpectedMembersCreate,
    AttendanceExpectedMemberRead,
    AttendanceManualCreate,
    AttendanceCheckIn,
    AttendanceRead,
    AttendanceRecordRead,          
)
from app.api.deps import (
    get_current_active_validated_user,
    require_sg_or_admin,
    user_has_any_role,
)
from app.services.audit_service import create_audit_log, get_client_ip

router = APIRouter(prefix="/attendance", tags=["Présences"])
ATTENDANCE_MANAGER_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}


def can_manage_attendance(db: Session, current_user: User) -> bool:
    return user_has_any_role(
        db,
        current_user.id,
        ATTENDANCE_MANAGER_ROLES,
    )


def attendance_session_payload(
    db: Session,
    current_user: User,
    session: AttendanceSession,
) -> dict:
    can_manage = can_manage_attendance(db, current_user)
    data = AttendanceSessionRead.model_validate(session).model_dump()
    data["can_manage"] = can_manage
    if not can_manage:
        data["qr_token"] = None
    return data


RETARD_PENALTY = 300
ABSENCE_PENALTY = 500


VALID_ATTENDANCE_STATUSES = {
    "present",
    "retard",
    "absent_justifie",
    "absent_non_justifie",
    "excuse",
    "mission_externe",
}


def ensure_financial_account(db: Session, user_id):
    account = db.query(FinancialAccount).filter(
        FinancialAccount.user_id == user_id
    ).first()

    if not account:
        account = FinancialAccount(
            user_id=user_id,
            balance_due=0,
            total_paid=0,
        )
        db.add(account)
        db.flush()

    return account


def apply_attendance_penalty(
    db: Session,
    record: AttendanceRecord,
    current_user: User,
):
    amount = 0
    fee_type = None
    label = None

    if record.status == "retard":
        amount = RETARD_PENALTY
        fee_type = "penalite_retard"
        label = "Pénalité de retard"

    elif record.status == "absent_non_justifie":
        amount = ABSENCE_PENALTY
        fee_type = "penalite_absence"
        label = "Pénalité absence non justifiée"

    if amount <= 0:
        record.penalty_amount = 0
        return

    existing_fee = db.query(Fee).filter(
        Fee.related_attendance_id == record.id
    ).first()

    if existing_fee:
        return

    fee = Fee(
        user_id=record.user_id,
        type=fee_type,
        label=label,
        amount=amount,
        amount_paid=0,
        status="unpaid",
        related_attendance_id=record.id,
        created_by=current_user.id,
    )

    record.penalty_amount = amount

    account = ensure_financial_account(db, record.user_id)
    account.balance_due = float(account.balance_due or 0) + amount
    account.updated_at = datetime.utcnow()

    db.add(fee)


def compute_checkin_status(session: AttendanceSession, now: datetime) -> str:
    """
    Détermine automatiquement si le membre est présent ou en retard.

    Règle EnactSpace :
    - avant 15 min après le début de pointage : présent
    - après 15 min : retard
    """

    reference_time = session.checkin_start or session.created_at
    late_limit = reference_time + timedelta(minutes=session.late_after_minutes)

    if now > late_limit:
        return "retard"

    return "present"


@router.post("/sessions", response_model=AttendanceSessionRead)
def create_attendance_session(
    payload: AttendanceSessionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    session = AttendanceSession(
        title=payload.title,
        description=payload.description,
        session_type=payload.session_type,
        event_id=payload.event_id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        created_by=current_user.id,
        qr_token=payload.qr_token,
        scheduled_at=payload.scheduled_at,
        checkin_start=payload.checkin_start,
        checkin_end=payload.checkin_end,
        late_after_minutes=payload.late_after_minutes,
        is_closed=False,
    )

    db.add(session)
    db.commit()
    db.refresh(session)

    return attendance_session_payload(db, current_user, session)


@router.get("/sessions", response_model=list[AttendanceSessionRead])
def list_attendance_sessions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    sessions = db.query(AttendanceSession).order_by(
        AttendanceSession.created_at.desc()
    ).all()
    return [
        attendance_session_payload(db, current_user, session)
        for session in sessions
    ]


@router.post("/expected-members", response_model=AttendanceExpectedMemberRead)
def add_expected_member(
    payload: AttendanceExpectedMembersCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == payload.session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Séance de présence introuvable",
        )

    user = db.query(User).filter(User.id == payload.user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )

    existing = db.query(AttendanceExpectedMember).filter(
        AttendanceExpectedMember.session_id == payload.session_id,
        AttendanceExpectedMember.user_id == payload.user_id,
    ).first()

    if existing:
        return existing

    expected_member = AttendanceExpectedMember(
        session_id=payload.session_id,
        user_id=payload.user_id,
        is_required=payload.is_required,
    )

    db.add(expected_member)
    db.commit()
    db.refresh(expected_member)

    return expected_member


@router.get("/expected-members/{session_id}", response_model=list[AttendanceExpectedMemberRead])
def list_expected_members(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    return db.query(AttendanceExpectedMember).filter(
        AttendanceExpectedMember.session_id == session_id
    ).order_by(AttendanceExpectedMember.created_at.asc()).all()


@router.post("/check-in", response_model=AttendanceRecordRead)  
def qr_check_in(
    payload: AttendanceCheckIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    now = datetime.utcnow()

    session = db.query(AttendanceSession).filter(
        AttendanceSession.qr_token == payload.qr_token
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="QR code invalide ou séance introuvable",
        )

    if session.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette séance de pointage est déjà clôturée",
        )

    if session.checkin_start and now < session.checkin_start:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le pointage n'est pas encore ouvert",
        )

    if session.checkin_end and now > session.checkin_end:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le pointage est terminé",
        )

    expected = db.query(AttendanceExpectedMember).filter(
        AttendanceExpectedMember.session_id == session.id,
        AttendanceExpectedMember.user_id == current_user.id,
    ).first()

    if not expected:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous n'êtes pas dans la liste des membres attendus pour cette séance",
        )

    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session.id,
        AttendanceRecord.user_id == current_user.id,
    ).first()

    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vous avez déjà pointé pour cette séance",
        )

    computed_status = compute_checkin_status(session, now)

    record = AttendanceRecord(
        session_id=session.id,
        user_id=current_user.id,
        status=computed_status,
        checkin_time=now,
        justification_status="none",
    )

    db.add(record)
    db.flush()

    apply_attendance_penalty(db, record, current_user)

    db.commit()
    db.refresh(record)

    return record


@router.post("/manual", response_model=AttendanceRecordRead)
def create_manual_attendance(
    payload: AttendanceManualCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == payload.session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Séance de présence introuvable",
        )

    if session.is_closed:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette séance est déjà clôturée",
        )

    user = db.query(User).filter(User.id == payload.user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utilisateur introuvable",
        )

    existing = db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == payload.session_id,
        AttendanceRecord.user_id == payload.user_id,
    ).first()

    penalty_amount = 0
    is_justified = True

    if payload.status == "retard":
        penalty_amount = 300
        is_justified = False
    elif payload.status in ["absent", "absence", "absent_non_justifie", "absence_non_justifiee"]:
        penalty_amount = 500
        is_justified = False

    penalty_fee = None

    if penalty_amount > 0:
        fee_title = "Pénalité de retard" if payload.status == "retard" else "Pénalité absence non justifiée"

        penalty_fee = Fee(
            user_id=payload.user_id,
            type="penalty",
            label=fee_title,
            amount=penalty_amount,
            amount_paid=0,
            status="unpaid",
        )

        # Champs optionnels selon le modèle finance.py
        if hasattr(Fee, "title"):
            penalty_fee.title = fee_title

        if hasattr(Fee, "description"):
            penalty_fee.description = f"{fee_title} - {session.title}"

        if hasattr(Fee, "created_by"):
            penalty_fee.created_by = current_user.id

        if hasattr(Fee, "due_date"):
            penalty_fee.due_date = datetime.utcnow()

        db.add(penalty_fee)
        db.flush()

        account = db.query(FinancialAccount).filter(
            FinancialAccount.user_id == payload.user_id
        ).first()

        if not account:
            account = FinancialAccount(
                user_id=payload.user_id,
            )
            db.add(account)
            db.flush()

        if hasattr(account, "total_penalties"):
            account.total_penalties = float(account.total_penalties or 0) + penalty_amount

        if hasattr(account, "balance_due"):
            account.balance_due = float(account.balance_due or 0) + penalty_amount

        if hasattr(account, "total_due"):
            account.total_due = float(account.total_due or 0) + penalty_amount

        if hasattr(account, "updated_at"):
            account.updated_at = datetime.utcnow()

    if existing:
        existing.status = payload.status
        existing.justification = payload.justification
        existing.justification_file_url = payload.justification_file_url
        existing.note = payload.note
        existing.recorded_by = current_user.id
        existing.checkin_time = datetime.utcnow()
        existing.is_justified = is_justified
        existing.penalty_amount = penalty_amount

        if penalty_fee:
            existing.penalty_fee_id = penalty_fee.id

        db.commit()
        db.refresh(existing)

        return existing

    record = AttendanceRecord(
        session_id=payload.session_id,
        user_id=payload.user_id,
        status=payload.status,
        checkin_time=datetime.utcnow(),
        recorded_by=current_user.id,
        justification=payload.justification,
        justification_file_url=payload.justification_file_url,
        is_justified=is_justified,
        penalty_amount=penalty_amount,
        penalty_fee_id=penalty_fee.id if penalty_fee else None,
        note=payload.note,
    )

    db.add(record)
    db.commit()
    db.refresh(record)

    return record


@router.get("/records", response_model=list[AttendanceRecordRead])
def list_attendance_records(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
    user_id: Optional[str] = Query(default=None),
    session_id: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None),
):
    query = db.query(AttendanceRecord)


    if user_id:
        query = query.filter(AttendanceRecord.user_id == user_id)
    if session_id:
        query = query.filter(AttendanceRecord.session_id == session_id)
    if status_filter:
        query = query.filter(AttendanceRecord.status == status_filter)

    return query.order_by(AttendanceRecord.created_at.desc()).all()


@router.get("/records/{session_id}", response_model=list[AttendanceRead])
def list_attendance_records_by_session(
    session_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    return db.query(AttendanceRecord).filter(
        AttendanceRecord.session_id == session_id
    ).order_by(AttendanceRecord.created_at.desc()).all()


@router.post("/sessions/{session_id}/close", response_model=dict)
def close_attendance_session(
    session_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Séance de pointage introuvable",
        )

    if session.is_closed:
        return {
            "ok": True,
            "message": "La séance était déjà clôturée",
        }

    expected_members = db.query(AttendanceExpectedMember).filter(
        AttendanceExpectedMember.session_id == session.id
    ).all()

    created_absences = 0

    for expected in expected_members:
        existing_record = db.query(AttendanceRecord).filter(
            AttendanceRecord.session_id == session.id,
            AttendanceRecord.user_id == expected.user_id,
        ).first()

        if existing_record:
            continue

        record = AttendanceRecord(
            session_id=session.id,
            user_id=expected.user_id,
            status="absent_non_justifie",
            checkin_time=None,
            justification_status="none",
        )

        db.add(record)
        db.flush()

        apply_attendance_penalty(db, record, current_user)

        created_absences += 1

    session.is_closed = True

    create_audit_log(
        db=db,
        action="cloture_seance_pointage",
        user_id=current_user.id,
        entity_type="attendance_session",
        entity_id=session.id,
        old_value={"is_closed": False},
        new_value={
            "is_closed": True,
            "absences_generated": created_absences,
        },
        ip_address=get_client_ip(request),
    )
    db.commit()

    return {
        "ok": True,
        "message": "Séance de pointage clôturée",
        "absences_generated": created_absences,
    }


@router.get("/my-records", response_model=list[AttendanceRecordRead])
def list_my_attendance_records(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    status_filter: Optional[str] = Query(default=None),
):
    query = db.query(AttendanceRecord).filter(
        AttendanceRecord.user_id == current_user.id
    )

    if status_filter:
        query = query.filter(AttendanceRecord.status == status_filter)

    return query.order_by(AttendanceRecord.created_at.desc()).all()
