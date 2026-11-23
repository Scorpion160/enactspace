"""Manager-only, no-contact change of one private interview proposal.

A published appointment remains unchanged until the separate, deliberate
candidate-notification workflow is approved by the recruitment manager.
"""
from datetime import datetime
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.db.database import get_db
from app.core.time import utc_now
from app.models.audit import AuditLog
from app.models.user import User
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, RecruitmentCampaign,
    RecruitmentJuryMember,
)
from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
from app.models.recruitment_interview_policy import RecruitmentJuryAvailability
from app.services.audit_service import create_audit_log
from app.services.operational_integrity import lock_row, to_naive_utc
from app.services.recruitment_access import (
    can_manage_jury, eligible_juror, require_campaign_access,
)
from app.services.recruitment_interview_policy import (
    fetch_policy, juror_available, within_windows,
)
from app.services.recruitment_interviews import (
    department_key, effective_interview_end,
)
from app.services.recruitment_jury_constraints import (
    jury_constraints, juror_respects_constraints,
)

MODES = {"in_person", "hybrid", "online"}


class PrivateProposalSave(BaseModel):
    model_config = ConfigDict(extra="forbid")
    starts_at: datetime
    ends_at: datetime
    mode: str = "in_person"
    location: str | None = Field(default=None, max_length=180)
    jury_member_ids: list[UUID] = Field(min_length=1, max_length=6)
    reason: str = Field(min_length=3, max_length=900)
    confirm_unrecorded_jury_availability: bool = False

    @model_validator(mode="after")
    def valid(self):
        if self.mode not in MODES:
            raise ValueError("Format d'entretien inconnu.")
        if len(set(self.jury_member_ids)) != len(self.jury_member_ids):
            raise ValueError("Un juré ne peut être affecté deux fois.")
        return self


def check_private_proposal(db, campaign, app, proposal):
    """Pure validation against live DB; no writes, no messages."""
    start, end = to_naive_utc(proposal.starts_at), to_naive_utc(proposal.ends_at)
    if not within_windows(fetch_policy(db, campaign.id), start, end):
        raise HTTPException(422, "Durée ou plage horaire incompatible avec la campagne.")
    members = db.query(RecruitmentJuryMember, User).join(
        User, RecruitmentJuryMember.user_id == User.id
    ).filter(
        RecruitmentJuryMember.campaign_id == campaign.id,
        RecruitmentJuryMember.id.in_(proposal.jury_member_ids),
    ).all()
    if len(members) != len(proposal.jury_member_ids) or any(
        not member.is_active or not eligible_juror(user)
        for member, user in members
    ):
        raise HTTPException(409, "Un juré n'est pas habilité ou n'appartient pas à cette campagne.")
    blackouts, remote_only = jury_constraints(db, campaign.id)
    availabilities = {
        row.user_id: row.windows
        for row in db.query(RecruitmentJuryAvailability).filter(
            RecruitmentJuryAvailability.campaign_id == campaign.id,
            RecruitmentJuryAvailability.user_id.in_([m.user_id for m, _ in members]),
        ).all()
    }
    for member, user in members:
        if not juror_respects_constraints(
            user.id, start, proposal.mode, blackouts, remote_only,
        ):
            raise HTTPException(409, f"{user.first_name} {user.last_name} est indisponible ou à distance uniquement.")
        if user.id not in availabilities:
            if not proposal.confirm_unrecorded_jury_availability:
                raise HTTPException(
                    409,
                    f"Disponibilités non renseignées pour {user.first_name} {user.last_name}. "
                    "Confirme leur disponibilité dans le formulaire avant de poursuivre.",
                )
        elif not juror_available(availabilities[user.id], start, end):
            raise HTTPException(
                409, f"{user.first_name} {user.last_name} est indisponible sur ce créneau."
            )
        if app.email and user.email and user.email.strip().casefold() == app.email.strip().casefold():
            raise HTTPException(409, "Un juré ne peut pas évaluer sa propre candidature.")
    deps = [department_key(user.department) for _, user in members]
    requires_exception = (
        len(members) != 3 or len(set(deps)) != 3
        or department_key(app.department) not in deps
    )
    # A manager may justify an operational exception: never waive a collision,
    # a blackout, an inactive juror, or the candidate's own membership.
    if requires_exception and not proposal.reason.strip():
        raise HTTPException(409, "Une exception de composition du jury doit être motivée.")
    member_users = {member.user_id for member, _ in members}
    drafts = db.query(RecruitmentInterviewDraft).filter(
        RecruitmentInterviewDraft.campaign_id == campaign.id,
        RecruitmentInterviewDraft.application_id != app.id,
    ).all()
    existing_members = {
        mid: row.user_id for row in db.query(RecruitmentJuryMember).filter(
            RecruitmentJuryMember.campaign_id == campaign.id,
        ).all()
        for mid in [str(row.id)]
    }
    for draft in drafts:
        if draft.starts_at < end and draft.ends_at > start:
            if any(existing_members.get(str(mid)) in member_users for mid in draft.jury_member_ids):
                raise HTTPException(409, "Un juré est déjà affecté à un autre entretien préparé.")
    # Prevent collision with published interviews, including appointments that
    # have not yet been reflected in private planning.
    confirmed = db.query(
        RecruitmentJuryMember.user_id, Application.id,
        Application.interview_at, Application.interview_end_at,
    ).join(
        ApplicationInterviewJuror,
        RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id,
    ).join(
        Application, Application.id == ApplicationInterviewJuror.application_id,
    ).filter(
        RecruitmentJuryMember.user_id.in_(member_users),
        Application.status.in_(("interview_scheduled", "interview")),
        Application.id != app.id,
    ).all()
    for uid, other_id, at, until in confirmed:
        if at and at < end and effective_interview_end(at, until) > start:
            raise HTTPException(409, "Un juré a déjà un entretien officiellement confirmé.")
    return start, end, requires_exception


def register_private_interview_proposals(router):
    @router.put("/applications/{application_id}/interview/private-proposal")
    def save_private_proposal(
        application_id: UUID, payload: PrivateProposalSave,
        db: Session = Depends(get_db),
        actor: User = Depends(require_recruitment_access),
    ):
        app = db.get(Application, application_id)
        if app is None:
            raise HTTPException(404, "Candidature introuvable.")
        require_campaign_access(db, actor, app.campaign_id)
        if not can_manage_jury(db, actor):
            raise HTTPException(403, "Seuls les responsables peuvent reprogrammer les entretiens.")
        campaign = lock_row(db, RecruitmentCampaign, app.campaign_id)
        if app.screening_decision != "shortlisted":
            raise HTTPException(409, "Le dossier n'est pas retenu pour entretien.")
        recorded = db.query(AuditLog).filter(
            AuditLog.entity_type == "application",
            AuditLog.entity_id == app.id,
            AuditLog.action.in_((
                "entretien_reel_confirme_par_organisateur",
                "entretien_presence_enregistree",
            )),
        ).all()
        if any(
            (event.new_value or {}).get("status") in ("completed", "completed_pending_score")
            for event in recorded
        ):
            raise HTTPException(409, "Cet entretien est déjà réalisé et ne peut pas être reprogrammé.")
        draft = db.get(RecruitmentInterviewDraft, app.id)
        if draft is None or draft.campaign_id != campaign.id:
            raise HTTPException(409, "Préparation interne introuvable.")
        start, end, exceptional = check_private_proposal(db, campaign, app, payload)
        previous = {
            "starts_at": draft.starts_at.isoformat(),
            "ends_at": draft.ends_at.isoformat(),
            "mode": draft.mode,
            "jury_member_ids": list(draft.jury_member_ids),
        }
        draft.starts_at = start
        draft.ends_at = end
        draft.mode = payload.mode
        draft.location = payload.location
        draft.jury_member_ids = [str(mid) for mid in payload.jury_member_ids]
        draft.updated_by = actor.id
        draft.updated_at = utc_now()
        draft.revision = (draft.revision or 0) + 1
        create_audit_log(
            db, "entretien_report_replanifie_interne", actor.id,
            "application", app.id,
            old_value=previous,
            new_value={
                "status": "postponed",
                "proposed_date": start.date().isoformat(),
                "proposed_time": start.strftime("%H:%M"),
                "proposed_end": end.strftime("%H:%M"),
                "mode": payload.mode,
                "jury_member_ids": draft.jury_member_ids,
                "reason": payload.reason,
                "exceptional_jury": exceptional,
                "candidate_confirmation_pending": True,
                "unrecorded_jury_availability_confirmed_by_manager":
                    payload.confirm_unrecorded_jury_availability,
                "official_appointment_unchanged": True,
                "notifications_sent": 0,
            },
        )
        db.commit()
        return {
            "saved": True, "draft_only": True,
            "revision": draft.revision,
            "candidate_notifications": 0,
            "official_appointment_unchanged": True,
        }
