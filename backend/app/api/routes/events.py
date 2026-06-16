from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.event import Event
from app.models.user import User
from app.schemas.event import EventCreate, EventRead, EventUpdate
from app.api.deps import get_current_user, require_enacchef_or_admin


router = APIRouter(prefix="/events", tags=["Événements"])


def get_event_or_404(db: Session, event_id: str) -> Event:
    event = db.query(Event).filter(Event.id == event_id).first()
    if event is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Événement introuvable",
        )
    return event


@router.post("/", response_model=EventRead)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
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

    return event


@router.get("/", response_model=list[EventRead])
def list_events(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return db.query(Event).order_by(Event.start_time.desc()).all()


@router.patch("/{event_id}", response_model=EventRead)
def update_event(
    event_id: str,
    payload: EventUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    event = get_event_or_404(db, event_id)

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(event, field, value)

    event.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(event)

    return event
