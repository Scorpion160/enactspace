from datetime import date, datetime

from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models.attendance import (
    AttendanceExpectedMember,
    AttendanceRecord,
    AttendanceSession,
)
from app.models.institutional_memory import CanonicalProject, InstitutionalEvent
from app.models.project import Project
from app.services.audit_service import create_audit_log


def _existing_capture(db: Session, capture_key: str) -> InstitutionalEvent | None:
    return (
        db.query(InstitutionalEvent)
        .filter(InstitutionalEvent.capture_key == capture_key)
        .first()
    )


def _persist_capture(
    db: Session,
    event: InstitutionalEvent,
    *,
    actor_id,
) -> InstitutionalEvent:
    existing = _existing_capture(db, event.capture_key)
    if existing is not None:
        return existing

    try:
        with db.begin_nested():
            db.add(event)
            db.flush()
            create_audit_log(
                db,
                "institutional_memory_operational_capture",
                actor_id,
                "institutional_event",
                event.id,
                new_value={
                    "capture_key": event.capture_key,
                    "source_entity_type": event.source_entity_type,
                    "source_entity_id": str(event.source_entity_id),
                },
            )
            db.flush()
        return event
    except IntegrityError:
        existing = _existing_capture(db, event.capture_key)
        if existing is None:
            raise
        return existing


def capture_project_completion(
    db: Session,
    project: Project,
    *,
    actor_id,
) -> InstitutionalEvent:
    completed_on = project.ended_at or date.today()
    canonical_project_id = (
        db.query(CanonicalProject.id)
        .filter(CanonicalProject.current_project_id == project.id)
        .order_by(CanonicalProject.id)
        .limit(1)
        .scalar()
    )
    return _persist_capture(
        db,
        InstitutionalEvent(
            title=f"Projet termine : {project.name}",
            event_type="project_completed",
            event_date=completed_on,
            year=completed_on.year,
            description=(project.description or "").strip() or None,
            visibility="internal",
            status="completed",
            validation_status="VERIFIED",
            validated_by_id=actor_id,
            validated_at=datetime.utcnow(),
            origin="operational",
            capture_key=f"project:{project.id}:termine",
            source_entity_type="project",
            source_entity_id=project.id,
            source_entity_version="termine",
            captured_at=datetime.utcnow(),
            operational_project_id=project.id,
            canonical_project_id=canonical_project_id,
        ),
        actor_id=actor_id,
    )


def capture_attendance_archive(
    db: Session,
    session: AttendanceSession,
    *,
    actor_id,
) -> InstitutionalEvent:
    counts = dict(
        db.query(AttendanceRecord.status, func.count(AttendanceRecord.id))
        .filter(AttendanceRecord.session_id == session.id)
        .group_by(AttendanceRecord.status)
        .all()
    )
    expected = (
        db.query(func.count(AttendanceExpectedMember.id))
        .filter(AttendanceExpectedMember.session_id == session.id)
        .scalar()
        or 0
    )
    scheduled = session.scheduled_at or session.created_at or datetime.utcnow()
    summary = (
        f"Type: {session.session_type}; perimetre: {session.scope_type}; "
        f"attendus: {expected}; presents: {int(counts.get('present', 0))}; "
        f"retards: {int(counts.get('late', 0))}; absents/excuses: "
        f"{int(counts.get('absent', 0)) + int(counts.get('justified_absence', 0))}."
    )
    return _persist_capture(
        db,
        InstitutionalEvent(
            title=f"Seance archivee : {session.title}",
            event_type="attendance_session_archived",
            event_date=scheduled.date(),
            year=scheduled.year,
            description=summary,
            visibility="private",
            status="archived",
            validation_status="VERIFIED",
            validated_by_id=actor_id,
            validated_at=datetime.utcnow(),
            origin="operational",
            capture_key=f"attendance_session:{session.id}:archived",
            source_entity_type="attendance_session",
            source_entity_id=session.id,
            source_entity_version="archived",
            captured_at=datetime.utcnow(),
            operational_project_id=session.project_id,
            pole_id=session.pole_id,
            operational_event_id=session.event_id,
        ),
        actor_id=actor_id,
    )
