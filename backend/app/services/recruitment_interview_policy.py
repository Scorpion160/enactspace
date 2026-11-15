"""Campaign-scoped reusable recruitment scheduling rules. Nothing is mailed."""
from datetime import datetime, date as CalendarDate, time
from uuid import UUID
from fastapi import Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy.orm import Session
from app.api.deps import require_recruitment_access
from app.db.database import get_db
from app.core.time import utc_now
from app.models.user import User
from app.models.recruitment import RecruitmentCampaign
from app.models.recruitment_interview_policy import RecruitmentInterviewPolicy, RecruitmentJuryAvailability
from app.services.recruitment_access import can_manage_jury, require_campaign_access
from app.services.audit_service import create_audit_log

DEFAULT_WINDOWS = [{"start":"12:30","end":"14:00"},{"start":"19:00","end":"21:00"}]

class DailyWindow(BaseModel):
    model_config = ConfigDict(extra="forbid")
    start: str = Field(pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    end: str = Field(pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    @model_validator(mode="after")
    def valid(self):
        if self.start >= self.end:
            raise ValueError("L'heure de fin doit suivre le début.")
        return self

class PolicySave(BaseModel):
    model_config = ConfigDict(extra="forbid")
    duration_minutes: int = Field(ge=5,le=180)
    daily_windows: list[DailyWindow] = Field(min_length=1,max_length=8)
    default_mode: str = Field(pattern="^(in_person|online|hybrid)$")
    default_location: str | None = Field(default=None,max_length=180)
    respect_candidate_availability: bool = False
    @model_validator(mode="after")
    def valid(self):
        windows=sorted(self.daily_windows,key=lambda w:w.start)
        for a,b in zip(windows,windows[1:]):
            if a.end>b.start:raise ValueError("Les plages horaires se chevauchent.")
        return self

class AvailabilityWindow(DailyWindow):
    weekday: int | None = Field(default=None,ge=0,le=6)
    date: CalendarDate | None = None
    @model_validator(mode="after")
    def require_day(self):
        if (self.weekday is None)==(self.date is None):
            raise ValueError("Choisis un jour de semaine ou une date spécifique.")
        return self

class AvailabilitySave(BaseModel):
    model_config = ConfigDict(extra="forbid")
    windows: list[AvailabilityWindow] = Field(max_length=30)
    @model_validator(mode="after")
    def valid(self):
        buckets={}
        for w in self.windows:
            key=("weekday",w.weekday) if w.weekday is not None else ("date",w.date)
            buckets.setdefault(key,[]).append((w.start,w.end))
        for spans in buckets.values():
            spans.sort()
            for a,b in zip(spans,spans[1:]):
                if a[1]>b[0]:raise ValueError("Les disponibilités se chevauchent.")
        return self

def fetch_policy(db,campaign_id):
    row=db.get(RecruitmentInterviewPolicy,campaign_id)
    if row is None:
        return {"duration_minutes":20,"daily_windows":DEFAULT_WINDOWS,
                "default_mode":"in_person","default_location":None,
                "respect_candidate_availability":False}
    return {"duration_minutes":row.duration_minutes,"daily_windows":row.daily_windows,
            "default_mode":row.default_mode,"default_location":row.default_location,
            "respect_candidate_availability":row.respect_candidate_availability}

def within_windows(policy,start,end):
    if start.date()!=end.date():return False
    if (end-start).total_seconds()!=policy["duration_minutes"]*60:return False
    left,right=start.strftime("%H:%M"),end.strftime("%H:%M")
    return any(w["start"]<=left and right<=w["end"] for w in policy["daily_windows"])

def can_manage(db,campaign_id,actor):
    campaign=db.get(RecruitmentCampaign,campaign_id)
    if not campaign:raise HTTPException(404,"Campagne introuvable.")
    require_campaign_access(db,actor,campaign.id)
    if not can_manage_jury(db,actor):
        raise HTTPException(403,"Action réservée aux responsables du jury.")
    return campaign

def register_interview_policy(router):
    @router.get("/campaigns/{campaign_id}/interviews/policy")
    def read_policy(campaign_id:UUID,db:Session=Depends(get_db),actor:User=Depends(require_recruitment_access)):
        can_manage(db,campaign_id,actor)
        return fetch_policy(db,campaign_id)

    @router.put("/campaigns/{campaign_id}/interviews/policy")
    def save_policy(campaign_id:UUID,payload:PolicySave,db:Session=Depends(get_db),
                    actor:User=Depends(require_recruitment_access)):
        can_manage(db,campaign_id,actor)
        row=db.get(RecruitmentInterviewPolicy,campaign_id)
        if row is None:
            row=RecruitmentInterviewPolicy(campaign_id=campaign_id)
            db.add(row)
        proposed = payload.model_dump(mode="json")
        from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
        existing = db.query(RecruitmentInterviewDraft).filter(
            RecruitmentInterviewDraft.campaign_id == campaign_id
        ).all()
        for draft in existing:
            if not within_windows(proposed, draft.starts_at, draft.ends_at):
                raise HTTPException(
                    409,
                    "Les règles proposées sont incompatibles avec des entretiens déjà préparés. "
                    "Modifie d'abord les créneaux concernés.",
                )
        row.duration_minutes=payload.duration_minutes
        row.daily_windows=[w.model_dump() for w in payload.daily_windows]
        row.default_mode=payload.default_mode
        row.default_location=payload.default_location
        row.respect_candidate_availability=payload.respect_candidate_availability
        row.updated_at=utc_now()
        create_audit_log(db,"parametres_entretiens_campagne",actor.id,"recruitment_campaign",campaign_id,
                         new_value=payload.model_dump(mode="json"))
        db.commit()
        return fetch_policy(db,campaign_id)

    @router.get("/campaigns/{campaign_id}/jury/availability")
    def all_availability(campaign_id:UUID,db:Session=Depends(get_db),actor:User=Depends(require_recruitment_access)):
        can_manage(db,campaign_id,actor)
        rows=db.query(RecruitmentJuryAvailability,User).join(
            User,User.id==RecruitmentJuryAvailability.user_id
        ).filter(RecruitmentJuryAvailability.campaign_id==campaign_id).all()
        return [{"user_id":str(user.id),"name":f"{user.first_name} {user.last_name}".strip(),
                 "department":user.department,"email_verified":user.email_verified,
                 "windows":row.windows} for row,user in rows]

    @router.put("/campaigns/{campaign_id}/jury/availability/{user_id}")
    def save_availability(campaign_id:UUID,user_id:UUID,payload:AvailabilitySave,
                          db:Session=Depends(get_db),actor:User=Depends(require_recruitment_access)):
        can_manage(db,campaign_id,actor)
        user=db.get(User,user_id)
        if not user or not user.is_active or user.status not in {"active","alumni"}:
            raise HTTPException(409,"Ce compte n'est pas actif.")
        row=db.get(RecruitmentJuryAvailability,(campaign_id,user_id))
        if row is None:
            row=RecruitmentJuryAvailability(campaign_id=campaign_id,user_id=user_id)
            db.add(row)
        row.windows=[w.model_dump(mode="json",exclude_none=True) for w in payload.windows]
        row.updated_at=utc_now()
        create_audit_log(db,"disponibilites_membre_jury",actor.id,"recruitment_campaign",campaign_id,
                         new_value={"user_id":str(user_id),"windows":row.windows})
        db.commit()
        return {"user_id":str(user_id),"windows":row.windows,"saved":True,
                "candidate_notifications":0}
