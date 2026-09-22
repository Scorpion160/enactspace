from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
)
from app.db.database import get_db
from app.models.event import Event, EventParticipant
from app.models.notification import Notification
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.models.attendance import AttendanceSession
from app.schemas.event import (
    EventCreate,
    EventParticipantRead,
    EventRead,
    EventUpdate,
)
from app.services.notification_service import notify_user
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.operational_integrity import lock_row, to_naive_utc


router = APIRouter(prefix="/events", tags=["Evenements"])
GLOBAL_EVENT_MANAGERS = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}


def get_event_or_404(db: Session, event_id: str) -> Event:
    event = db.query(Event).filter(Event.id == event_id).first()
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Evenement introuvable",
        )
    return event


def can_manage_event(db: Session, current_user: User, event: Event) -> bool:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_EVENT_MANAGERS):
        return True
    if event.created_by == current_user.id:
        return True
    if event.pole_id is not None:
        pole_lead = (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == event.pole_id,
                PoleMember.user_id == current_user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(("chef_pole", "adjoint_chef_pole")),
            )
            .first()
        )
        if pole_lead:
            return True
    if event.project_id is not None:
        project_lead = (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == event.project_id,
                ProjectMember.user_id == current_user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(
                    ("chef_projet", "adjoint_chef_projet")
                ),
            )
            .first()
        )
        if project_lead:
            return True
    return False


def require_event_manager(
    db: Session,
    current_user: User,
    event: Event,
) -> None:
    if not can_manage_event(db, current_user, event):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Gestion reservee aux responsables de cet evenement",
        )


def event_payload(db: Session, event: Event, current_user: User) -> dict:
    data = EventRead.model_validate(event).model_dump()
    data["registered_count"] = (
        db.query(func.count(EventParticipant.id))
        .filter(EventParticipant.event_id == event.id)
        .scalar()
        or 0
    )
    data["current_user_registered"] = (
        db.query(EventParticipant.id)
        .filter(
            EventParticipant.event_id == event.id,
            EventParticipant.user_id == current_user.id,
        )
        .first()
        is not None
    )
    data["can_manage"] = can_manage_event(db, current_user, event)
    return data


def ensure_creation_scope(
    db: Session,
    current_user: User,
    pole_id,
    project_id,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_EVENT_MANAGERS):
        return

    if pole_id is None and project_id is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Selectionnez un pole ou projet que vous dirigez",
        )

    if pole_id is not None:
        membership = (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == pole_id,
                PoleMember.user_id == current_user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(("chef_pole", "adjoint_chef_pole")),
            )
            .first()
        )
        if not membership:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous ne dirigez pas le pôle demandé",
            )

    if project_id is not None:
        membership = (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == project_id,
                ProjectMember.user_id == current_user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(
                    ("chef_projet", "adjoint_chef_projet")
                ),
            )
            .first()
        )
        if not membership:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous ne dirigez pas le projet demandé",
            )


def validate_event_values(start_time, end_time, budget, max_participants) -> None:
    start = to_naive_utc(start_time)
    end = to_naive_utc(end_time)
    if end is not None and start is not None and end <= start:
        raise HTTPException(status_code=400, detail="La fin doit suivre le début")
    if budget is not None and budget < 0:
        raise HTTPException(status_code=400, detail="Le budget ne peut pas être négatif")
    if max_participants is not None and max_participants <= 0:
        raise HTTPException(status_code=400, detail="La capacité doit être supérieure à zéro")


@router.post("/", response_model=EventRead)
def create_event(
    payload: EventCreate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    ensure_creation_scope(db, current_user, payload.pole_id, payload.project_id)
    validate_event_values(
        payload.start_time,
        payload.end_time,
        payload.budget,
        payload.max_participants,
    )
    event = Event(
        season_id=payload.season_id,
        title=payload.title,
        description=payload.description,
        event_type=payload.event_type,
        location=payload.location,
        start_time=to_naive_utc(payload.start_time),
        end_time=to_naive_utc(payload.end_time),
        created_by=current_user.id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        budget=payload.budget,
        max_participants=payload.max_participants,
        requires_registration=payload.requires_registration,
        attendance_enabled=payload.attendance_enabled,
    )
    db.add(event)
    db.flush()
    create_audit_log(
        db=db,
        action="creation_evenement",
        user_id=current_user.id,
        entity_type="event",
        entity_id=event.id,
        new_value={"title": event.title, "pole_id": str(event.pole_id) if event.pole_id else None, "project_id": str(event.project_id) if event.project_id else None},
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(event)
    return event_payload(db, event, current_user)


@router.get("/", response_model=list[EventRead])
def list_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    events = db.query(Event).order_by(Event.start_time.desc()).all()
    return [event_payload(db, event, current_user) for event in events]


@router.get("/{event_id}", response_model=EventRead)
def get_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = get_event_or_404(db, event_id)
    return event_payload(db, event, current_user)


@router.patch("/{event_id}", response_model=EventRead)
def update_event(
    event_id: str,
    payload: EventUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = lock_row(db, Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Evenement introuvable")
    require_event_manager(db, current_user, event)
    updates = payload.model_dump(exclude_unset=True)
    new_pole_id = updates.get("pole_id", event.pole_id)
    new_project_id = updates.get("project_id", event.project_id)
    if {"pole_id", "project_id"}.intersection(updates):
        ensure_creation_scope(db, current_user, new_pole_id, new_project_id)
    new_start = updates.get("start_time", event.start_time)
    new_end = updates.get("end_time", event.end_time)
    validate_event_values(
        new_start,
        new_end,
        updates.get("budget", event.budget),
        updates.get("max_participants", event.max_participants),
    )
    old_value = {key: getattr(event, key) for key in updates}
    for field, value in updates.items():
        if field in {"start_time", "end_time"}:
            value = to_naive_utc(value)
        setattr(event, field, value)
    event.updated_at = datetime.utcnow()
    create_audit_log(
        db=db,
        action="modification_evenement",
        user_id=current_user.id,
        entity_type="event",
        entity_id=event.id,
        old_value={key: str(value) if value is not None else None for key, value in old_value.items()},
        new_value={key: str(getattr(event, key)) if getattr(event, key) is not None else None for key in updates},
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(event)
    return event_payload(db, event, current_user)


@router.delete("/{event_id}")
def delete_event(
    event_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = lock_row(db, Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Evenement introuvable")
    require_event_manager(db, current_user, event)
    if db.query(AttendanceSession.id).filter(AttendanceSession.event_id == event.id).first():
        raise HTTPException(
            status_code=409,
            detail="Cet événement est référencé par une séance de présence",
        )
    db.query(EventParticipant).filter(
        EventParticipant.event_id == event.id
    ).delete(synchronize_session=False)
    create_audit_log(
        db=db,
        action="suppression_evenement",
        user_id=current_user.id,
        entity_type="event",
        entity_id=event.id,
        old_value={"title": event.title},
        ip_address=get_client_ip(request),
    )
    db.delete(event)
    db.commit()
    return {"ok": True}


@router.get(
    "/{event_id}/participants",
    response_model=list[EventParticipantRead],
)
def list_event_participants(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = lock_row(db, Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Evenement introuvable")
    require_event_manager(db, current_user, event)
    rows = (
        db.query(EventParticipant, User)
        .join(User, User.id == EventParticipant.user_id)
        .filter(EventParticipant.event_id == event.id)
        .order_by(EventParticipant.registered_at.asc())
        .all()
    )
    return [
        EventParticipantRead(
            id=participant.id,
            user_id=user.id,
            display_name=(
                f"{user.first_name} {user.last_name}".strip() or user.email
            ),
            email=user.email,
            photo_url=user.photo_url,
            registered_at=participant.registered_at,
        )
        for participant, user in rows
    ]


@router.post("/{event_id}/register", response_model=EventRead)
def register_for_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = lock_row(db, Event, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Evenement introuvable")
    is_alumni = (
        current_user.status == "alumni"
        or current_user.profile_type == "alumni"
    )
    is_active_member = (
        current_user.status == "active"
        and current_user.is_active
        and current_user.profile_type != "candidate"
    )
    if not (is_active_member or is_alumni):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Inscription réservée aux membres actifs et Alumni",
        )
    if not event.requires_registration:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cet evenement ne necessite pas d'inscription",
        )
    if to_naive_utc(event.start_time) <= datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Les inscriptions sont closes",
        )

    existing = (
        db.query(EventParticipant)
        .filter(
            EventParticipant.event_id == event.id,
            EventParticipant.user_id == current_user.id,
        )
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Vous êtes déjà inscrit à cet événement")

    registered_count = (
        db.query(func.count(EventParticipant.id))
        .filter(EventParticipant.event_id == event.id)
        .scalar()
        or 0
    )
    if (
        event.max_participants is not None
        and registered_count >= event.max_participants
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="L'evenement est complet",
        )

    db.add(EventParticipant(event_id=event.id, user_id=current_user.id))
    if event.created_by and event.created_by != current_user.id:
        notify_user(
            db,
            user_id=event.created_by,
            title=f"Nouvelle inscription a {event.title}",
            message=(
                f"{current_user.first_name} {current_user.last_name}".strip()
                or current_user.email
            ),
            notification_type="event_scheduled",
            related_type="event",
            related_id=event.id,
        )
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Inscription concurrente en conflit") from exc
    return event_payload(db, event, current_user)


@router.delete("/{event_id}/register", response_model=EventRead)
def unregister_from_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = get_event_or_404(db, event_id)
    if to_naive_utc(event.start_time) <= datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Impossible de quitter un evenement deja commence",
        )
    participant = (
        db.query(EventParticipant)
        .filter(
            EventParticipant.event_id == event.id,
            EventParticipant.user_id == current_user.id,
        )
        .first()
    )
    if participant:
        db.delete(participant)
        db.commit()
    return event_payload(db, event, current_user)
