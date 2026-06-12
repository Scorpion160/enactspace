from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.event import Event
from app.models.user import User
from app.schemas.event import EventCreate, EventRead
from app.api.deps import get_current_user


router = APIRouter(prefix="/events", tags=["Événements"])


@router.post("/", response_model=EventRead)
def create_event(
    payload: EventCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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