"""Explicit withdrawal and confirmed-absence outcomes for reusable recruitment campaigns.

Three *distinct, explicitly recorded* missed interview dates qualify for final
review. Passing a scheduled time never counts as an absence by itself.
Exclusion requires a separate, manager-confirmed action. No emails are sent.
"""
from datetime import date, datetime, timedelta
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.core.time import utc_now
from app.db.database import get_db
from app.models.audit import AuditLog
from app.models.meeting import Meeting
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, ApplicationReview, RecruitmentCampaign,
)
from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
from app.models.user import User
from app.services.audit_service import create_audit_log
from app.services.operational_integrity import lock_row
from app.services.recruitment_access import can_manage_jury, require_campaign_access

DEFAULT_ABSENCE_LIMIT = 3


class ConfirmOutcome(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: str = Field(min_length=12, max_length=1000)
    confirmed: bool

    @field_validator("reason")
    @classmethod
    def require_real_explanation(cls, value: str) -> str:
        result = value.strip()
        if len(result) < 12:
            raise ValueError("Pr?cise la justification du retrait ou de l'exclusion.")
        return result


def absence_limit(campaign) -> int:
    """Campaign-customisable without requiring a new migration."""
    policy = campaign.selection_schedule if isinstance(campaign.selection_schedule, dict) else {}
    limit = policy.get("max_no_shows", DEFAULT_ABSENCE_LIMIT)
    return limit if type(limit) is int and 2 <= limit <= 10 else DEFAULT_ABSENCE_LIMIT


def _absence_days_from_events(events) -> list[str]:
    """Deduplicate repeated audit writes; later explicit corrections override a day."""
    outcomes = {}
    for event in sorted(events, key=lambda e: (e.created_at, str(e.id))):
        data = event.new_value or {}
        status = data.get("status")
        if status not in {"no_show", "completed"}:
            continue
        day = data.get("actual_day")
        if not day and isinstance(data.get("session_start"), str):
            day = data["session_start"][:10]
        if not isinstance(day, str):
            continue
        try:
            parsed = date.fromisoformat(day)
        except ValueError:
            continue
        if parsed > utc_now().date():
            continue
        outcomes[parsed.isoformat()] = status
    return sorted(day for day, state in outcomes.items() if state == "no_show")


def confirmed_absence_days(db: Session, application_id: UUID) -> list[str]:
    events = db.query(AuditLog).filter(
        AuditLog.entity_type == "application",
        AuditLog.entity_id == application_id,
    ).order_by(AuditLog.created_at, AuditLog.id).all()
    return _absence_days_from_events(events)


def _latest_no_show(db, application_id):
    rows = db.query(AuditLog).filter(
        AuditLog.entity_type == "application",
        AuditLog.entity_id == application_id,
        AuditLog.action == "entretien_presence_enregistree",
    ).order_by(AuditLog.created_at.desc(), AuditLog.id.desc()).limit(10).all()
    if not rows:
        return False
    return (rows[0].new_value or {}).get("status") == "no_show"


def _has_score(db, application_id):
    return bool(db.query(ApplicationReview.id).filter(
        ApplicationReview.application_id == application_id,
        ApplicationReview.stage == "interview",
        ApplicationReview.score.isnot(None),
    ).first())


def _manager_application(db, application_id, actor):
    preliminary = db.get(Application, application_id)
    if not preliminary:
        raise HTTPException(404, "Candidature introuvable.")
    campaign = lock_row(db, RecruitmentCampaign, preliminary.campaign_id)
    app = lock_row(db, Application, application_id)
    require_campaign_access(db, actor, campaign.id)
    if not can_manage_jury(db, actor):
        raise HTTPException(403, "Action réservée aux responsables du recrutement.")
    return app, campaign


def register_interview_outcomes(router):
    @router.get("/applications/{application_id}/interview/absence-summary")
    def absence_summary(
        application_id: UUID,
        db: Session = Depends(get_db),
        actor: User = Depends(require_recruitment_access),
    ):
        # Assigned jurors may see absence counters, but cannot exclude candidates.
        from app.services.recruitment_collective_interview import _private_access
        app, attendance, _, manager = _private_access(db, application_id, actor)
        campaign = db.get(RecruitmentCampaign, app.campaign_id)
        dates = confirmed_absence_days(db, app.id)
        limit = absence_limit(campaign)
        return {
            "application_id": str(app.id),
            "count": len(dates),
            "dates": dates,
            "limit": limit,
            "remaining": max(0, limit - len(dates)),
            "last_chance": len(dates) == limit - 1,
            "requires_decision": len(dates) >= limit and app.status == "interview_scheduled",
            "can_exclude": manager and len(dates) >= limit
            and app.status == "interview_scheduled" and not _has_score(db, app.id)
            and _latest_no_show(db, app.id),
            "can_manage": manager,
            "application_status": app.status,
        }

    @router.post("/applications/{application_id}/interview/exclude-no-show")
    def exclude_no_show(
        application_id: UUID,
        payload: ConfirmOutcome,
        db: Session = Depends(get_db),
        actor: User = Depends(require_recruitment_access),
    ):
        if not payload.confirmed:
            raise HTTPException(422, "Une confirmation explicite est obligatoire.")
        app, campaign = _manager_application(db, application_id, actor)
        if app.status == "rejected":
            return {"already_excluded": True, "status": app.status}
        if app.status != "interview_scheduled" or app.converted_user_id:
            raise HTTPException(409, "Le dossier n'est pas éligible à cette décision.")
        if _has_score(db, app.id):
            raise HTTPException(409, "Cet entretien est déjà noté ; vérifie le dossier.")
        days = confirmed_absence_days(db, app.id)
        limit = absence_limit(campaign)
        if len(days) < limit or not _latest_no_show(db, app.id):
            raise HTTPException(409, "Les absences requises ne sont pas confirmées.")
        if not app.interview_end_at or app.interview_end_at > utc_now():
            raise HTTPException(409, "L'entretien prévu n'est pas encore terminé.")
        if days[-1] != app.interview_at.date().isoformat():
            raise HTTPException(409, "La dernière absence ne correspond pas au rendez-vous officiel.")
        before = {"status": app.status, "absence_dates": days}
        app.status = "rejected"
        app.updated_at = utc_now()
        create_audit_log(
            db, "decision_exclusion_absences_confirmees", actor.id,
            "application", app.id, old_value=before,
            new_value={
                "status": "rejected",
                "reason": payload.reason.strip(),
                "absence_count": len(days),
                "absence_dates": days,
                "max_no_shows": limit,
                "manager_confirmed": True,
                "candidate_notifications": 0,
                "shared_interview_room_left_untouched": True,
            },
        )
        db.commit()
        return {"excluded": True, "status": app.status,
                "confirmed_absences": len(days), "candidate_notifications": 0}

    @router.post("/applications/{application_id}/interview/withdraw")
    def withdraw(
        application_id: UUID,
        payload: ConfirmOutcome,
        db: Session = Depends(get_db),
        actor: User = Depends(require_recruitment_access),
    ):
        if not payload.confirmed:
            raise HTTPException(422, "Une confirmation explicite est obligatoire.")
        app, campaign = _manager_application(db, application_id, actor)
        if app.status == "cancelled":
            return {"already_withdrawn": True, "status": app.status}
        if app.status not in {"under_review", "interview_scheduled"} or app.converted_user_id:
            raise HTTPException(409, "Ce dossier ne peut plus être retiré.")
        if _has_score(db, app.id):
            raise HTTPException(409, "Un entretien noté doit être vérifié avant retrait.")
        previous_meeting = db.get(Meeting, app.interview_meeting_id) if app.interview_meeting_id else None
        previous = {
            "status": app.status,
            "interview_at": app.interview_at.isoformat() if app.interview_at else None,
            "interview_end_at": app.interview_end_at.isoformat() if app.interview_end_at else None,
            "interview_mode": app.interview_mode,
            "interview_jury": app.interview_jury,
            "meeting_id": str(app.interview_meeting_id) if app.interview_meeting_id else None,
        }
        other_users_of_meeting = (
            db.query(Application.id).filter(
                Application.interview_meeting_id == app.interview_meeting_id,
                Application.id != app.id,
                Application.status == "interview_scheduled",
            ).first()
            if app.interview_meeting_id else None
        )
        if previous_meeting and not other_users_of_meeting:
            previous_meeting.status = "cancelled"
            previous_meeting.updated_at = utc_now()
        db.query(ApplicationInterviewJuror).filter(
            ApplicationInterviewJuror.application_id == app.id,
        ).delete(synchronize_session=False)
        draft = db.get(RecruitmentInterviewDraft, app.id)
        if draft:
            db.delete(draft)
        app.status = "cancelled"
        app.interview_at = None
        app.interview_end_at = None
        app.interview_location = None
        app.interview_link = None
        app.interview_mode = None
        app.interview_jury = None
        app.interview_meeting_id = None
        app.updated_at = utc_now()
        create_audit_log(
            db, "desistement_candidat_confirme_par_coordination", actor.id,
            "application", app.id,
            old_value=previous,
            new_value={
                "status": "cancelled",
                "reason": payload.reason.strip(),
                "candidate_notifications": 0,
                "jury_notifications": 0,
                "previous_jury_to_notify": bool(previous["interview_jury"]),
                "shared_meeting_preserved": bool(other_users_of_meeting),
            },
        )
        db.commit()
        return {"withdrawn": True, "status": app.status,
                "candidate_notifications": 0, "jury_notifications": 0}
