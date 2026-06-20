from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func
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
from app.schemas.event import (
    EventCreate,
    EventParticipantRead,
    EventRead,
    EventUpdate,
)
from app.services.notification_service import notify_user


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
    payload: EventCreate,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_EVENT_MANAGERS):
        return

    if payload.pole_id is not None:
        membership = (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == payload.pole_id,
                PoleMember.user_id == current_user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(("chef_pole", "adjoint_chef_pole")),
            )
            .first()
        )
        if membership:
            return

    if payload.project_id is not None:
        membership = (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == payload.project_id,
                ProjectMember.user_id == current_user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(
                    ("chef_projet", "adjoint_chef_projet")
                ),
            )
            .first()
        )
        if membership:
            return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Selectionnez un pole ou projet que vous dirigez",
    )


@router.post("/", response_model=EventRead)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    ensure_creation_scope(db, current_user, payload)
    event = Event(
        season_id=payload.season_id,
        title=payload.title,
        description=payload.description,
        event_type=payload.event_type,
        location=payload.location,
        start_time=payload.start_time,
        end_time=payload.end_time,
        created_by=current_user.id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        budget=payload.budget,
        max_participants=payload.max_participants,
        requires_registration=payload.requires_registration,
        attendance_enabled=payload.attendance_enabled,
    )
    db.add(event)
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


@router.patch("/{event_id}", response_model=EventRead)
def update_event(
    event_id: str,
    payload: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = get_event_or_404(db, event_id)
    require_event_manager(db, current_user, event)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(event, field, value)
    event.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(event)
    return event_payload(db, event, current_user)


@router.delete("/{event_id}")
def delete_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = get_event_or_404(db, event_id)
    require_event_manager(db, current_user, event)
    db.query(EventParticipant).filter(
        EventParticipant.event_id == event.id
    ).delete(synchronize_session=False)
    db.query(Notification).filter(
        Notification.related_type == "event",
        Notification.related_id == event.id,
    ).delete(synchronize_session=False)
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
    event = get_event_or_404(db, event_id)
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
    event = get_event_or_404(db, event_id)
    if not event.requires_registration:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cet evenement ne necessite pas d'inscription",
        )
    if event.start_time <= datetime.utcnow():
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
        return event_payload(db, event, current_user)

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
    db.commit()
    return event_payload(db, event, current_user)


@router.delete("/{event_id}/register", response_model=EventRead)
def unregister_from_event(
    event_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    event = get_event_or_404(db, event_id)
    if event.start_time <= datetime.utcnow():
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
