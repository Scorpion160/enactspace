"""Private interview pre-planning. No public status or notification side effects.

The publication/convocation path remains the existing schedule_application_interview
endpoint and is deliberately NOT called by anything in this module.
"""
from collections import Counter
from datetime import datetime, time
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.core.time import utc_now
from app.db.database import get_db
from app.models.recruitment import (
    Application, ApplicationPersonality, RecruitmentCampaign, RecruitmentJuryMember,
    ApplicationInterviewJuror,
)
from app.models.recruitment_interview_drafts import (
    RecruitmentInterviewDraft, RecruitmentInterviewPrepNote,
)
from app.models.user import User
from app.models.audit import AuditLog
from app.services.audit_service import create_audit_log
from app.services.operational_integrity import lock_row, to_naive_utc
from app.services.recruitment_access import (
    active_jury_member, can_manage_jury, eligible_juror, require_campaign_access,
)
from app.services.recruitment_interviews import department_key, effective_interview_end
from app.services.recruitment_interview_policy import fetch_policy, within_windows, juror_available
from app.models.recruitment_interview_policy import RecruitmentJuryAvailability
from app.services.recruitment_jury_constraints import jury_constraints, juror_respects_constraints


class DraftAppointment(BaseModel):
    model_config = ConfigDict(extra="forbid")
    application_id: UUID
    starts_at: datetime
    ends_at: datetime
    jury_member_ids: list[UUID] = Field(min_length=3, max_length=3)
    mode: str = Field(default="in_person", pattern="^(in_person|online|hybrid)$")
    location: str | None = Field(default=None,max_length=180)

    @model_validator(mode="after")
    def unique_members(self):
        if len(set(self.jury_member_ids)) != 3:
            raise ValueError("Trois jurés différents sont nécessaires.")
        return self


class DraftBatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    appointments: list[DraftAppointment] = Field(min_length=1, max_length=250)
    dry_run: bool = True


class PersonalPrepNote(BaseModel):
    model_config = ConfigDict(extra="forbid")
    body: str = Field(max_length=6000)


def private_campaign(db, campaign_id, actor, *, manager=False):
    campaign = db.get(RecruitmentCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(404, "Campagne introuvable.")
    require_campaign_access(db, actor, campaign.id)
    if not campaign.screening_published_at or not campaign.identities_revealed_at:
        raise HTTPException(409, "La préparation nominative exige une présélection publiée et l'anonymat levé.")
    if manager and not can_manage_jury(db, actor):
        raise HTTPException(403, "Seuls les responsables du jury peuvent modifier la préparation.")
    return campaign


def _slot_ok(start, end):
    # Current recruitment uses Dakar-local time (UTC+00), with afternoon and evening blocks.
    if start.date() != end.date() or (end - start).total_seconds() != 20 * 60:
        return False
    return (
        (time(12, 30) <= start.time() and end.time() <= time(14, 0))
        or (time(19, 0) <= start.time() and end.time() <= time(21, 0))
    )


def validate_drafts(db, campaign, inputs):
    """Whole-plan validation with no database writes or candidate notifications."""
    if len({row.application_id for row in inputs}) != len(inputs):
        raise HTTPException(409, "Un candidat figure plusieurs fois dans la préparation.")
    apps = {
        app.id: app for app in db.query(Application).filter(
            Application.campaign_id == campaign.id,
            Application.screening_decision == "shortlisted",
            Application.status != "cancelled",
        )
    }
    listed = set(apps)
    if set(row.application_id for row in inputs) != listed:
        raise HTTPException(409, "Le projet doit couvrir exactement tous les candidats retenus, une fois chacun.")
    members = {
        member.id: (member, user)
        for member, user in db.query(RecruitmentJuryMember, User).join(
            User, User.id == RecruitmentJuryMember.user_id
        ).filter(RecruitmentJuryMember.campaign_id == campaign.id)
    }
    available_by_user = {
        row.user_id: row.windows
        for row in db.query(RecruitmentJuryAvailability).filter(
            RecruitmentJuryAvailability.campaign_id == campaign.id,
            RecruitmentJuryAvailability.user_id.in_(
                [member.user_id for member, _ in members.values()]
            ),
        ).all()
    }
    policy=fetch_policy(db,campaign.id)
    blackouts, remote_only = jury_constraints(db, campaign.id)
    if policy["respect_candidate_availability"]:
        raise HTTPException(409,"La validation automatique des souhaits libres des candidats n'est pas disponible.")
    starts_by_member = {}
    conflicts = []
    for row in inputs:
        app = apps[row.application_id]
        if app.status in {"interview_scheduled", "interview", "accepted", "rejected"}:
            raise HTTPException(409, "Un dossier est déjà dans une étape incompatible avec le brouillon.")
        start = to_naive_utc(row.starts_at)
        end = to_naive_utc(row.ends_at)
        if not within_windows(policy,start,end):
            raise HTTPException(422,"Ce créneau ne respecte pas la durée ou les plages horaires de la campagne.")
        selected = [members.get(member_id) for member_id in row.jury_member_ids]
        if any(pair is None or not pair[0].is_active or not eligible_juror(pair[1]) for pair in selected):
            raise HTTPException(409, "Un juré proposé n'est pas habilité ou n'appartient pas à la campagne.")
        users = [pair[1] for pair in selected]
        for user in users:
            if not juror_respects_constraints(
                user.id, start, row.mode, blackouts, remote_only
            ):
                raise HTTPException(
                    409,
                    "Un juré est indisponible ce jour ou participe uniquement à distance.",
                )
            if user.id in available_by_user and not juror_available(
                available_by_user[user.id], start, end
            ):
                raise HTTPException(
                    409,
                    "Un juré n'est pas disponible sur le créneau proposé.",
                )
        depts = [department_key(user.department) for user in users]
        if not all(depts) or len(set(depts)) != 3:
            raise HTTPException(409, "Chaque jury doit représenter trois départements différents.")
        if department_key(app.department) not in depts:
            raise HTTPException(409, "Il manque un juré du département du candidat.")
        if any(user.email.strip().casefold() == app.email.strip().casefold() for user in users):
            raise HTTPException(409, "Un juré ne peut pas auditionner sa propre candidature.")
        for pair in selected:
            member = pair[0]
            starts_by_member.setdefault(member.user_id, []).append((start, end, app.id))
    for user_id, sessions in starts_by_member.items():
        sessions.sort()
        for a, b in zip(sessions, sessions[1:]):
            if a[1] > b[0]:
                conflicts.append(user_id)
    if conflicts:
        raise HTTPException(409, "Un ou plusieurs jurés sont affectés simultanément à deux candidats.")
    # Existing published appointments must also not overlap with the private proposal.
    confirmed = db.query(
        RecruitmentJuryMember.user_id, Application.id, Application.interview_at,
        Application.interview_end_at
    ).join(
        ApplicationInterviewJuror,
        RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id
    ).join(Application, Application.id == ApplicationInterviewJuror.application_id).filter(
        RecruitmentJuryMember.user_id.in_(list(starts_by_member)),
        Application.status.in_({"interview_scheduled", "interview"}),
    ).all()
    for user_id, app_id, scheduled_start, scheduled_end in confirmed:
        if scheduled_start is None:
            continue
        actual_end = effective_interview_end(scheduled_start, scheduled_end)
        for start, end, draft_id in starts_by_member.get(user_id, []):
            if app_id != draft_id and scheduled_start < end and actual_end > start:
                raise HTTPException(409, "Conflit avec un rendez-vous déjà confirmé pour l'un des jurés.")
    return {"valid": True, "count": len(inputs), "notifications_to_candidates": 0}


def _readable_rows(db, campaign, actor):
    manager = can_manage_jury(db, actor)
    if not manager and not active_jury_member(db, actor, campaign.id):
        raise HTTPException(403, "Accès réservé aux jurés de la campagne.")
    roster = db.query(RecruitmentJuryMember, User).join(
        User, RecruitmentJuryMember.user_id == User.id
    ).filter(RecruitmentJuryMember.campaign_id == campaign.id).all()
    by_id = {
        str(m.id): {"id": str(m.id), "name": f"{u.first_name} {u.last_name}".strip(),
                    "department": u.department, "user_id": str(u.id)}
        for m, u in roster
    }
    current = {str(m.id) for m, u in roster if m.user_id == actor.id and m.is_active}
    drafts = db.query(RecruitmentInterviewDraft).filter(
        RecruitmentInterviewDraft.campaign_id == campaign.id
    ).order_by(RecruitmentInterviewDraft.starts_at, RecruitmentInterviewDraft.application_id).all()
    # Determine the effective jury from real attendance when known. Replacement
    # jurors gain access to the dossier; absent jurors lose access. A postponed
    # interview instead uses the revised private draft, not the former roster.
    events = db.query(AuditLog).filter(
        AuditLog.entity_type == "application",
        AuditLog.entity_id.in_([row.application_id for row in drafts]),
        AuditLog.action.in_([
            "entretien_reel_confirme_par_organisateur",
            "entretien_presence_enregistree",
            "entretien_report_replanifie_interne",
            "entretien_presence_jury_modifiee",
            "reorganisation_jury_indisponibilite_17nov",
        ]),
    ).order_by(AuditLog.created_at, AuditLog.id).all()
    event_by_application = {}
    completed_by_application = {}
    for event in events:
        event_by_application[event.entity_id] = event
        if (event.new_value or {}).get("status") in ("completed", "completed_pending_score"):
            completed_by_application[event.entity_id] = event

    def effective_ids(row):
        completed = completed_by_application.get(row.application_id)
        if completed:
            return (completed.new_value or {}).get("actual_jury_member_ids", row.jury_member_ids)
        latest = event_by_application.get(row.application_id)
        if latest and latest.action in ("entretien_presence_enregistree", "entretien_presence_jury_modifiee"):
            data = latest.new_value or {}
            if data.get("status") != "postponed":
                return data.get("actual_jury_member_ids") or row.jury_member_ids
        return row.jury_member_ids

    visible = [row for row in drafts if manager or bool(current.intersection(effective_ids(row)))]
    apps = {app.id:app for app in db.query(Application).filter(
        Application.id.in_([row.application_id for row in visible])
    ).all()}
    personality = {
        row.application_id:row for row in db.query(ApplicationPersonality).filter(
            ApplicationPersonality.application_id.in_([row.application_id for row in visible])
        ).all()
    }
    result = []
    for row in visible:
        app = apps[row.application_id]
        test = personality.get(row.application_id)
        last_event = event_by_application.get(row.application_id)
        latest = (last_event.new_value or {}) if last_event else {}
        realized_event = completed_by_application.get(row.application_id)
        realized = (realized_event.new_value or {}) if realized_event else {}
        status = "completed" if realized_event else latest.get("status", "scheduled")
        if last_event and last_event.action == "entretien_report_replanifie_interne":
            status = "postponed"
        published = app.interview_at.isoformat() + "Z" if app.interview_at else None
        communicated = bool(
            app.interview_at is not None and
            app.interview_at == row.starts_at and
            (app.interview_mode or "in_person") == (row.mode or "in_person")
        )
        result.append({
            "application_id": str(row.application_id),
            "candidate_name": f"{app.first_name} {app.last_name}".strip(),
            "candidate_department": app.department,
            "starts_at": row.starts_at.isoformat() + "Z",
            "ends_at": row.ends_at.isoformat() + "Z",
            "jury": [dict(by_id.get(mid, {"name":"Juré retiré","department":None}),
                         is_me=by_id.get(mid,{}).get("user_id")==str(actor.id))
                     for mid in row.jury_member_ids],
            "personality_status": (
                "not_invited" if test is None else
                "submitted" if test.submitted_at else
                "declined" if test.declined_at else "in_progress"
            ),
            "revision": row.revision,
            "mode": row.mode or "in_person",
            "candidate_presence": candidate_presence_from_mode(row.mode),
            "remote_juror_enabled": row.mode == "hybrid",
            "video_link_to_verify": remote_link_to_verify(row.mode, row.location),
            "location": row.location,
            "draft_only": not communicated,
            "operational_status": status,
            "official_starts_at": published,
            "awaiting_candidate_notification": not communicated and status == "postponed",
            "actual_jury": [
                dict(by_id.get(mid, {"name": "Juré non trouvé", "department": None}))
                for mid in realized.get("actual_jury_member_ids", [])
            ],
            "actual_day": realized.get("actual_date") or realized.get("actual_day"),
            "actual_session": realized.get("session"),
            "effective_jury": [
                dict(by_id.get(mid, {"name": "Juré non trouvé", "department": None}),
                     is_me=by_id.get(mid, {}).get("user_id") == str(actor.id))
                for mid in effective_ids(row)
            ],
            "internal_changes_only": True,
            "candidate_notifications": 0,
        })
    return result


def candidate_presence_from_mode(mode):
    """The candidate remains on site when only the jury joins remotely.

    Keep this separate from juror participation so mixed interviews never
    accidentally become remote invitations for the candidate.
    """
    return "remote_exception" if mode == "online" else "on_site"


def remote_link_to_verify(mode, location):
    """Advisory indicator only; no participant is notified from this check."""
    import re
    if mode not in ("hybrid", "online"):
        return False
    return re.search(r"https?://[^\s,;]+", location or "") is None


def juror_availability_readiness(db, campaign_id):
    """Read-only readiness summary for jury managers (never a convocation)."""
    drafts = db.query(RecruitmentInterviewDraft).filter(
        RecruitmentInterviewDraft.campaign_id == campaign_id
    ).all()
    slots = {}
    for draft in drafts:
        for member_id in draft.jury_member_ids:
            slots.setdefault(str(member_id), []).append(
                (draft.starts_at, draft.ends_at)
            )
    total = len(slots)
    if not total:
        return {"assigned": 0, "confirmed": 0, "to_confirm": 0, "ready": False}
    members = {
        str(member.id): (member, user)
        for member, user in db.query(RecruitmentJuryMember, User).join(
            User, User.id == RecruitmentJuryMember.user_id
        ).filter(RecruitmentJuryMember.campaign_id == campaign_id).all()
    }
    user_ids = {
        members[mid][0].user_id for mid in slots if mid in members
    }
    availabilities = {
        row.user_id: row.windows for row in db.query(
            RecruitmentJuryAvailability
        ).filter(
            RecruitmentJuryAvailability.campaign_id == campaign_id,
            RecruitmentJuryAvailability.user_id.in_(user_ids),
        ).all()
    }
    blackouts, remote_only = jury_constraints(db, campaign_id)
    draft_modes = {
        str(member_id): [
            (draft.starts_at, draft.ends_at, draft.mode)
            for draft in drafts if str(member_id) in draft.jury_member_ids
        ] for member_id in slots
    }
    confirmed = sum(
        1 for member_id, appointments in slots.items()
        if member_id in members
        and members[member_id][0].is_active
        and eligible_juror(members[member_id][1])
        and members[member_id][0].user_id in availabilities
        and all(
            juror_available(
                availabilities[members[member_id][0].user_id], start, end
            ) and juror_respects_constraints(
                members[member_id][0].user_id, start, mode,
                blackouts, remote_only,
            )
            for start, end, mode in draft_modes[member_id]
        )
    )
    return {
        "assigned": total,
        "confirmed": confirmed,
        "to_confirm": total - confirmed,
        "ready": confirmed == total,
    }


def register_interview_drafts(router):
    @router.get("/campaigns/{campaign_id}/interviews/drafts")
    def list_drafts(campaign_id: UUID, db: Session = Depends(get_db),
                    actor: User = Depends(require_recruitment_access)):
        campaign = private_campaign(db, campaign_id, actor)
        result = _readable_rows(db, campaign, actor)
        can_manage = can_manage_jury(db, actor)
        response = {"rows": result, "draft_only": True, "candidate_notifications": 0,
                    "can_manage": can_manage}
        if can_manage:
            response["juror_availability_readiness"] = juror_availability_readiness(
                db, campaign.id
            )
        return response

    @router.post("/campaigns/{campaign_id}/interviews/drafts")
    def replace_drafts(campaign_id: UUID, payload: DraftBatch,
                       db: Session = Depends(get_db),
                       actor: User = Depends(require_recruitment_access)):
        campaign = private_campaign(db, campaign_id, actor, manager=True)
        # Lock campaign before validation and replacement to serialize batch edits.
        campaign = lock_row(db, RecruitmentCampaign, campaign.id)
        result = validate_drafts(db, campaign, payload.appointments)
        if payload.dry_run:
            db.rollback()
            return dict(result, saved=False, draft_only=True)
        existing = {row.application_id:row for row in db.query(
            RecruitmentInterviewDraft
        ).filter(RecruitmentInterviewDraft.campaign_id==campaign.id).all()}
        for item in payload.appointments:
            old = existing.get(item.application_id)
            if old is None:
                old = RecruitmentInterviewDraft(application_id=item.application_id,
                                                campaign_id=campaign.id)
                db.add(old)
            old.starts_at = to_naive_utc(item.starts_at)
            old.ends_at = to_naive_utc(item.ends_at)
            old.jury_member_ids = [str(i) for i in item.jury_member_ids]
            old.mode = item.mode
            old.location = item.location
            old.updated_by = actor.id
            old.updated_at = utc_now()
            old.revision = (old.revision or 0) + 1
        create_audit_log(db, "preparation_interne_entretiens", actor.id,
                         "recruitment_campaign", campaign.id,
                         new_value={"count":len(payload.appointments),
                                    "candidate_notifications":0})
        db.commit()
        return dict(result, saved=True, draft_only=True)

    def own_draft(db, application_id, actor):
        draft = db.get(RecruitmentInterviewDraft, application_id)
        if draft is None:
            raise HTTPException(404, "Affectation en préparation introuvable.")
        private_campaign(db, draft.campaign_id, actor)
        member = db.query(RecruitmentJuryMember).filter(
            RecruitmentJuryMember.campaign_id == draft.campaign_id,
            RecruitmentJuryMember.user_id == actor.id,
            RecruitmentJuryMember.is_active.is_(True),
        ).first()
        if member is None or str(member.id) not in draft.jury_member_ids or not eligible_juror(actor):
            raise HTTPException(403, "Ces notes sont réservées aux jurés affectés au candidat.")
        return draft

    @router.get("/applications/{application_id}/interview/preparation-note")
    def get_note(application_id: UUID, db: Session = Depends(get_db),
                 actor: User = Depends(require_recruitment_access)):
        own_draft(db, application_id, actor)
        note = db.get(RecruitmentInterviewPrepNote, (application_id, actor.id))
        return {"body": note.body if note else "", "private": True}

    @router.put("/applications/{application_id}/interview/preparation-note")
    def save_note(application_id: UUID, payload: PersonalPrepNote,
                  db: Session = Depends(get_db),
                  actor: User = Depends(require_recruitment_access)):
        own_draft(db, application_id, actor)
        note = db.get(RecruitmentInterviewPrepNote, (application_id, actor.id))
        if note is None:
            note = RecruitmentInterviewPrepNote(application_id=application_id, user_id=actor.id)
            db.add(note)
        note.body = payload.body
        note.updated_at = utc_now()
        db.commit()
        return {"saved": True, "private": True, "candidate_notifications": 0}
