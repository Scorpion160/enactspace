"""Individual requests have their own access rules and lifecycle."""
from datetime import datetime
from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, StringConstraints
from sqlalchemy import or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, joinedload

from app.api.deps import get_current_active_validated_user
from app.db.database import get_db
from app.models.alumni import IndividualMentorship
from app.models.user import User
from app.services.alumni_integrity import (
    assert_available_mentor,
    assert_valid_reader,
    can_manage_profiles,
    can_view_profile,
    is_operational,
    lock_alumni_accounts,
)
from app.services.operational_integrity import lock_row


router = APIRouter(prefix="/individual-mentorships")
RequestStatus = Literal["pending", "active", "completed", "cancelled"]
OPEN_STATUSES = ("pending", "active")
TRANSITIONS = {"pending": {"active", "cancelled"}, "active": {"completed", "cancelled"}}


class IndividualRequestCreate(BaseModel):
    mentor_id: UUID
    mentee_id: UUID | None = None
    objective: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=2000)]


class IndividualRequestUpdate(BaseModel):
    status: RequestStatus


class IndividualRequestRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    mentor_id: UUID
    mentor_name: str
    mentee_id: UUID
    mentee_name: str
    objective: str
    status: RequestStatus
    created_at: datetime
    updated_at: datetime


def assert_eligible_pair(db, mentor, mentee):
    if mentee is None or not is_operational(mentee):
        raise HTTPException(409, "Choisissez un membre actif et vérifié.")
    if mentor is None or mentor.id == mentee.id:
        raise HTTPException(409, "Choisissez un mentor Alumni distinct du membre.")
    profile = assert_available_mentor(db, mentor)
    if profile.visibility == "private" or not can_view_profile(db, mentee, profile):
        raise HTTPException(409, "Ce profil ne propose pas de mentorat à ce membre.")
    return profile


def open_request(db, mentor_id, mentee_id):
    return db.query(IndividualMentorship).filter_by(mentor_id=mentor_id, mentee_id=mentee_id).filter(
        IndividualMentorship.status.in_(OPEN_STATUSES),
    ).one_or_none()


@router.get("", response_model=list[IndividualRequestRead])
def list_individual_requests(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_active_validated_user),
):
    assert_valid_reader(user)
    query = db.query(IndividualMentorship).options(
        joinedload(IndividualMentorship.mentor), joinedload(IndividualMentorship.mentee),
    )
    if not can_manage_profiles(db, user):
        query = query.filter(or_(
            IndividualMentorship.mentor_id == user.id,
            IndividualMentorship.mentee_id == user.id,
        ))
    return query.order_by(IndividualMentorship.created_at.desc(), IndividualMentorship.id).all()


@router.post("", response_model=IndividualRequestRead)
def create_individual_request(
    payload: IndividualRequestCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_active_validated_user),
):
    mentee_id = payload.mentee_id or user.id
    accounts = lock_alumni_accounts(db, user.id, payload.mentor_id, mentee_id)
    actor = accounts.get(user.id)
    if actor is None or not is_operational(actor):
        raise HTTPException(403, "Cette demande exige un membre actif et vérifié.")
    if mentee_id != actor.id and not can_manage_profiles(db, actor):
        raise HTTPException(403, "Vous pouvez uniquement créer votre propre demande.")

    existing = open_request(db, payload.mentor_id, mentee_id)
    if existing is not None:
        if existing.objective == payload.objective:
            return existing
        raise HTTPException(409, "Une demande est déjà en cours pour ce binôme.")

    mentor, mentee = accounts.get(payload.mentor_id), accounts.get(mentee_id)
    profile = assert_eligible_pair(db, mentor, mentee)
    if not can_view_profile(db, actor, profile):
        raise HTTPException(409, "Ce profil ne vous est pas accessible.")
    request = IndividualMentorship(mentor=mentor, mentee=mentee, objective=payload.objective)
    db.add(request)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        actor = lock_alumni_accounts(db, user.id).get(user.id)
        if actor is None or not is_operational(actor) or (
            mentee_id != actor.id and not can_manage_profiles(db, actor)
        ):
            raise HTTPException(403, "Cette demande n’est pas autorisée.")
        existing = open_request(db, payload.mentor_id, mentee_id)
        if existing is None:
            raise
        if existing.objective == payload.objective:
            return existing
        raise HTTPException(409, "Une demande est déjà en cours pour ce binôme.")
    return request


@router.patch("/{request_id}", response_model=IndividualRequestRead)
def update_individual_request(
    request_id: UUID,
    payload: IndividualRequestUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_active_validated_user),
):
    if not can_manage_profiles(db, user):
        raise HTTPException(403, "Cette action est réservée aux responsables habilités.")
    reference = db.query(IndividualMentorship.mentor_id, IndividualMentorship.mentee_id).filter_by(
        id=request_id,
    ).first()
    if reference is None:
        raise HTTPException(404, "Demande introuvable.")
    accounts = lock_alumni_accounts(db, user.id, reference.mentor_id, reference.mentee_id)
    actor = accounts.get(user.id)
    if actor is None or not can_manage_profiles(db, actor):
        raise HTTPException(403, "Cette action est réservée aux responsables habilités.")
    request = lock_row(db, IndividualMentorship, request_id)
    if request is None:
        raise HTTPException(404, "Demande introuvable.")
    if request.status == payload.status:
        return request
    if payload.status not in TRANSITIONS.get(request.status, set()):
        raise HTTPException(409, "Cette modification de statut est indisponible.")
    if payload.status == "active":
        assert_eligible_pair(db, accounts.get(reference.mentor_id), accounts.get(reference.mentee_id))
    request.status = payload.status
    db.commit()
    return request
