"""Reusable campaign teams; appointment snapshots are never silently rewritten."""
import re
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.core.time import utc_now
from app.db.database import get_db
from app.models.recruitment import (
    Application, ApplicationInterviewTeam, RecruitmentJuryMember,
    RecruitmentJuryTeam, RecruitmentJuryTeamMember,
)
from app.models.user import User
from app.services.audit_service import create_audit_log
from app.services.recruitment_access import eligible_juror, require_campaign_access


class JuryTeamSave(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    member_ids: list[UUID] = Field(min_length=1, max_length=200)
    active: bool = Field(default=True, strict=True)
    revision: int | None = Field(default=None, ge=1, strict=True)

    @field_validator("name")
    @classmethod
    def clean_name(cls, value):
        value = re.sub(r"\s+", " ", value).strip()
        if not value:
            raise ValueError("Donne un nom à cette équipe.")
        return value

    @model_validator(mode="after")
    def no_duplicates(self):
        if len(self.member_ids) != len(set(self.member_ids)):
            raise ValueError("Chaque membre ne peut figurer qu’une fois dans une équipe.")
        return self


def team_members(db, team):
    return db.query(RecruitmentJuryMember, User).join(
        RecruitmentJuryTeamMember, RecruitmentJuryTeamMember.jury_member_id == RecruitmentJuryMember.id,
    ).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        RecruitmentJuryTeamMember.team_id == team.id,
    ).order_by(User.last_name, User.first_name, User.id).all()


def future_team_interviews(db, team_id):
    return db.query(Application).join(
        ApplicationInterviewTeam, ApplicationInterviewTeam.application_id == Application.id,
    ).filter(
        ApplicationInterviewTeam.team_id == team_id,
        Application.status.in_({"interview_scheduled", "interview"}),
        or_(Application.interview_at >= utc_now(), Application.interview_end_at > utc_now()),
    ).order_by(Application.interview_at, Application.id).all()


def interview_team_details(db, application):
    snapshot = db.get(ApplicationInterviewTeam, application.id)
    if snapshot is None:
        return None
    team = db.get(RecruitmentJuryTeam, snapshot.team_id)
    return {"id": str(snapshot.team_id), "name": snapshot.name, "revision": snapshot.revision,
            "current_name": team.name if team else None,
            "current_revision": team.revision if team else None,
            "needs_update": not team or not team.is_active or team.revision != snapshot.revision}


def team_payload(db, team):
    rows = team_members(db, team)
    interviews = future_team_interviews(db, team.id)
    return {"id": str(team.id), "campaign_id": str(team.campaign_id), "name": team.name,
            "active": team.is_active, "revision": team.revision,
            "available": bool(team.is_active and rows and all(
                member.is_active and eligible_juror(user) for member, user in rows)),
            "members": [{"id": str(member.id), "name": f"{user.first_name} {user.last_name}".strip(),
                         "active": member.is_active and eligible_juror(user)} for member, user in rows],
            "interviews": [{"application_id": str(app.id),
                            "name": f"{app.first_name} {app.last_name}".strip(),
                            "interview_at": app.interview_at.isoformat() + "Z",
                            "interview_end_at": app.interview_end_at.isoformat() + "Z" if app.interview_end_at else None,
                            "interview_mode": app.interview_mode,
                            "needs_update": interview_team_details(db, app)["needs_update"]}
                           for app in interviews]}


def campaign_teams(db, campaign_id):
    return [team_payload(db, row) for row in db.query(RecruitmentJuryTeam).filter_by(
        campaign_id=campaign_id).order_by(RecruitmentJuryTeam.name_key, RecruitmentJuryTeam.id)]


def save_team(db, campaign_id, payload, actor, team_id=None):
    from app.api.routes.recruitment_extensions import jury_manager
    # The campaign lock is shared by team edits, appointments and revocations.
    jury_manager(db, actor, campaign_id)
    team = db.query(RecruitmentJuryTeam).filter_by(id=team_id, campaign_id=campaign_id).populate_existing().first() if team_id else None
    if team_id and team is None:
        raise HTTPException(404, "Équipe introuvable dans cette campagne.")
    if team is not None and payload.revision != team.revision:
        raise HTTPException(409, "Cette équipe a changé. Recharge la liste avant de la modifier.")
    key = payload.name.casefold()
    duplicate = db.query(RecruitmentJuryTeam).filter_by(campaign_id=campaign_id, name_key=key).first()
    if duplicate and (team is None or duplicate.id != team.id):
        raise HTTPException(409, "Une équipe porte déjà ce nom dans cette campagne.")
    members = db.query(RecruitmentJuryMember, User).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        RecruitmentJuryMember.id.in_(payload.member_ids), RecruitmentJuryMember.campaign_id == campaign_id,
    ).all()
    # Archiving an old team remains possible after a member becomes unavailable.
    if len(members) != len(payload.member_ids) or (payload.active and any(
        not member.is_active or not eligible_juror(user) for member, user in members
    )):
        raise HTTPException(409, "Choisis des membres sélectionnés et disponibles dans cette campagne.")
    if team is None:
        team = RecruitmentJuryTeam(campaign_id=campaign_id, name=payload.name, name_key=key,
                                   is_active=payload.active, created_by=actor.id, revision=1)
        db.add(team)
        db.flush()
    else:
        old_members = {member.id for member, _ in team_members(db, team)}
        if team.name == payload.name and team.is_active == payload.active and old_members == set(payload.member_ids):
            return team_payload(db, team)
        team.name, team.name_key, team.is_active = payload.name, key, payload.active
        team.revision += 1
        team.updated_at = utc_now()
    db.query(RecruitmentJuryTeamMember).filter_by(team_id=team.id).delete(synchronize_session=False)
    for member_id in payload.member_ids:
        db.add(RecruitmentJuryTeamMember(team_id=team.id, jury_member_id=member_id))
    db.flush()
    create_audit_log(db, "composition_equipe_jury", actor.id, "recruitment_campaign", campaign_id,
                     new_value={"team_id": str(team.id), "name": team.name, "revision": team.revision,
                                "active": team.is_active, "member_ids": [str(value) for value in payload.member_ids]})
    db.commit()
    return team_payload(db, team)


def register_jury_teams(router):
    @router.get("/campaigns/{campaign_id}/jury/teams")
    def teams(campaign_id: UUID, db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        require_campaign_access(db, user, campaign_id)
        return campaign_teams(db, campaign_id)

    @router.post("/campaigns/{campaign_id}/jury/teams")
    def create(campaign_id: UUID, payload: JuryTeamSave,
               db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        return save_team(db, campaign_id, payload, user)

    @router.patch("/campaigns/{campaign_id}/jury/teams/{team_id}")
    def update(campaign_id: UUID, team_id: UUID, payload: JuryTeamSave,
               db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        return save_team(db, campaign_id, payload, user, team_id)
