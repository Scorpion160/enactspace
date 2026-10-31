"""Jury appointments and invited, resumable candidate questionnaires."""
from datetime import datetime
from uuid import UUID

from fastapi import Depends, HTTPException, Query
from pydantic import BaseModel, Field, StrictInt
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.core.time import utc_now
from app.db.database import get_db
from app.models.recruitment import Application, ApplicationPersonality, RecruitmentCampaign, RecruitmentJuryMember
from app.models.user import User
from app.schemas.recruitment import ApplicationTrackingRequest
from app.services.audit_service import create_audit_log
from app.services.email_delivery_service import enqueue_email_delivery
from app.services.email_templates import APP_URL
from app.services.operational_integrity import lock_row, to_naive_utc
from app.services.recruitment_access import (
    can_manage_jury, capabilities, eligible_juror, is_recruitment_staff, require_campaign_access, require_staff,
)
from app.services.recruitment_interviews import affected_future_interviews, interviews_needing_reassignment
from app.services.recruitment_personality import instrument, public_instrument, score, validate_answers


class JuryAppointment(BaseModel):
    user_id: UUID


class PersonalityInvitation(BaseModel):
    due_at: datetime | None = None


class PersonalitySave(ApplicationTrackingRequest):
    version: str = Field(min_length=1, max_length=64)
    revision: int = Field(ge=0, strict=True)
    answers: dict[str, StrictInt] = Field(default_factory=dict, max_length=20)
    scenario_answers: dict[str, str] = Field(default_factory=dict, max_length=5)
    consent: bool = Field(default=False, strict=True)


def campaign_lock(db, campaign_id):
    row = lock_row(db, RecruitmentCampaign, campaign_id)
    if not row:
        raise HTTPException(404, "Campagne introuvable")
    return row


def jury_manager(db, user, campaign_id):
    campaign_lock(db, campaign_id)
    if not can_manage_jury(db, user):
        raise HTTPException(403, "La gestion du jury est réservée à l’administration, au Team Leader, à la SG et aux responsables du pôle Veille.")


def member_payload(member, user):
    return {"id": str(member.id), "user_id": str(user.id), "campaign_id": str(member.campaign_id),
            "name": f"{user.first_name} {user.last_name}".strip(), "status": user.status,
            "active": member.is_active and eligible_juror(user), "appointed": member.is_active,
            "updated_at": member.updated_at, "revoked_at": member.revoked_at}


def assessment_status(row):
    return "submitted" if row.submitted_at else "declined" if row.declined_at else "invited"


def assessment_payload(row, *, candidate=False):
    state = assessment_status(row)
    result = {"status": state, "version": row.instrument_version, "revision": row.revision,
              "due_at": row.due_at, "submitted_at": row.submitted_at,
              "instrument": public_instrument(row.instrument_snapshot),
              "results": row.results if row.submitted_at else None}
    # A partially saved self-report remains private to the candidate.
    if candidate or row.submitted_at:
        result.update(answers=row.answers, scenario_answers=row.scenario_answers)
    if row.submitted_at and not candidate:
        result["discussion_guide"] = row.instrument_snapshot["scenarios"]
    return result


def public_attempt(db, payload, *, lock=False):
    from app.api.routes.recruitment import get_application_by_public_reference
    application = get_application_by_public_reference(db, payload.application_id, payload.email)
    if application is None:
        raise HTTPException(404, "Aucune candidature ne correspond à ces informations.")
    if lock:
        campaign_lock(db, application.campaign_id)
        application = lock_row(db, Application, application.id)
    query = db.query(ApplicationPersonality).filter_by(application_id=application.id)
    if lock:
        query = query.populate_existing().with_for_update()
    row = query.first()
    if row is None:
        raise HTTPException(404, "Aucun questionnaire n’est proposé pour cette candidature.")
    return application, row


def editable(application, row):
    if application.status in {"accepted", "rejected", "cancelled"}:
        raise HTTPException(409, "Cette candidature est clôturée. Contacte l’équipe pour toute question.")
    if row.due_at and utc_now() > row.due_at:
        raise HTTPException(409, "La date prévue est passée. Contacte l’équipe pour convenir d’une suite.")
    if row.submitted_at or row.declined_at:
        raise HTTPException(409, "Ce questionnaire est déjà terminé.")


def save_answers(row, payload, *, complete):
    if payload.version != row.instrument_version or payload.revision != row.revision:
        raise HTTPException(409, "Une autre version de tes réponses existe. Recharge le questionnaire avant de continuer.")
    if not payload.consent:
        raise HTTPException(422, "Prends connaissance de l’utilisation des réponses avant de continuer.")
    try:
        validate_answers(row.instrument_snapshot, payload.answers, payload.scenario_answers, complete=complete)
    except ValueError as error:
        raise HTTPException(422, str(error)) from error
    row.answers = dict(payload.answers)
    row.scenario_answers = {key: value.strip() for key, value in payload.scenario_answers.items()}
    row.consent_at = row.consent_at or utc_now()
    row.revision += 1
    row.updated_at = utc_now()
    if complete:
        row.results = score(row.instrument_snapshot, row.answers)
        row.submitted_at = utc_now()


def register_recruitment_extensions(router):
    @router.get("/access")
    def access(db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        return capabilities(db, user)

    @router.get("/campaigns/{campaign_id}/jury")
    def list_jury(campaign_id: UUID, db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        require_campaign_access(db, user, campaign_id)
        rows = db.query(RecruitmentJuryMember, User).join(User, User.id == RecruitmentJuryMember.user_id).filter(
            RecruitmentJuryMember.campaign_id == campaign_id).order_by(User.last_name, User.first_name).all()
        return {"can_manage": can_manage_jury(db, user), "members": [member_payload(m, u) for m, u in rows],
                "interviews_needing_reassignment": interviews_needing_reassignment(db, campaign_id)}

    @router.get("/campaigns/{campaign_id}/jury/eligible")
    def eligible_members(campaign_id: UUID, search: str = Query(default="", max_length=100),
                         db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        jury_manager(db, user, campaign_id)
        query = db.query(User).filter(User.is_active.is_(True), User.email_verified.is_(True), User.status.in_({"active", "alumni"}))
        if search.strip():
            pattern = "%" + search.strip() + "%"
            query = query.filter(or_(User.first_name.ilike(pattern), User.last_name.ilike(pattern)))
        return [{"id": str(row.id), "name": f"{row.first_name} {row.last_name}".strip(), "status": row.status}
                for row in query.order_by(User.last_name, User.first_name, User.id).limit(100)]

    @router.post("/campaigns/{campaign_id}/jury")
    def appoint(campaign_id: UUID, payload: JuryAppointment,
                db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        jury_manager(db, user, campaign_id)
        selected = lock_row(db, User, payload.user_id)
        if not eligible_juror(selected):
            raise HTTPException(422, "Choisis un enacteur ou un alumni dont le compte est actif et l’e-mail vérifié.")
        row = db.query(RecruitmentJuryMember).filter_by(campaign_id=campaign_id, user_id=selected.id).first()
        if row is not None and row.is_active:
            return member_payload(row, selected)
        if row is None:
            row = RecruitmentJuryMember(campaign_id=campaign_id, user_id=selected.id)
            db.add(row)
        row.is_active, row.appointed_by, row.revoked_by, row.revoked_at = True, user.id, None, None
        row.updated_at = utc_now()
        create_audit_log(db, "nomination_jury_recrutement", user.id, "recruitment_campaign", campaign_id,
                         new_value={"juror_id": str(selected.id)})
        db.commit()
        return member_payload(row, selected)

    @router.delete("/campaigns/{campaign_id}/jury/{member_id}")
    def revoke(campaign_id: UUID, member_id: UUID,
               db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        jury_manager(db, user, campaign_id)
        row = db.query(RecruitmentJuryMember).filter_by(id=member_id, campaign_id=campaign_id).first()
        if row is None:
            raise HTTPException(404, "Membre du jury introuvable")
        affected = affected_future_interviews(db, row)
        if row.is_active:
            row.is_active, row.revoked_by, row.revoked_at, row.updated_at = False, user.id, utc_now(), utc_now()
            create_audit_log(db, "retrait_jury_recrutement", user.id, "recruitment_campaign", campaign_id,
                             new_value={"juror_id": str(row.user_id), "interviews_to_reassign": len(affected)})
        db.commit()
        return {"ok": True, "interviews_to_reassign": [str(app.id) for app in affected], "history_preserved": True,
                "retains_staff_access": is_recruitment_staff(db, db.get(User, row.user_id))}

    @router.post("/applications/{application_id}/personality/invite")
    def invite(application_id: UUID, payload: PersonalityInvitation,
               db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        from app.api.routes.recruitment import lock_review_application, normalize_application_status
        require_staff(db, user)
        app = lock_review_application(db, application_id)
        if normalize_application_status(app.status) not in {"under_review", "interview_scheduled", "waiting_list"}:
            raise HTTPException(409, "Passe d’abord le dossier à l’étape d’étude ou d’entretien.")
        due = to_naive_utc(payload.due_at) if payload.due_at else None
        if due and due <= utc_now():
            raise HTTPException(422, "La date limite doit être à venir.")
        row = db.get(ApplicationPersonality, app.id)
        if row is None:
            snapshot = instrument()
            row = ApplicationPersonality(application_id=app.id, instrument_version=snapshot["version"],
                instrument_snapshot=snapshot, invited_by=user.id, due_at=due)
            db.add(row)
            db.flush()
        elif row.submitted_at or row.declined_at:
            return assessment_payload(row)
        elif row.due_at == due:
            return assessment_payload(row)
        else:
            row.due_at, row.updated_at = due, utc_now()
        # Code/email remain in the tracking form body, never in the URL.
        deadline = due.strftime("%d/%m/%Y à %H:%M (heure de Dakar)") if due else "La date sera convenue avec l’équipe."
        enqueue_email_delivery(db, recipient_email=app.email,
            subject="Préparer notre échange avec Enactus ESP",
            text_body=(f"Bonjour {app.first_name},\n\nNous te proposons un questionnaire pour préparer ton entretien. "
                "Il n’existe pas de profil idéal et il ne décide pas de l’admission. Tu peux aussi préférer en parler en entretien.\n\n"
                f"Échéance : {deadline}\nCode de suivi : {app.tracking_code or app.id}\n"
                f"Retrouver le questionnaire : {APP_URL}/application-tracking\n\nL’équipe Enactus ESP"),
            dedupe_key=f"personality-invite:{app.id}:{due.isoformat() if due else 'open'}")
        create_audit_log(db, "invitation_questionnaire_candidature", user.id, "application", app.id,
                         new_value={"version": row.instrument_version, "due_at": due.isoformat() if due else None})
        db.commit()
        return assessment_payload(row)

    @router.get("/applications/{application_id}/personality")
    def read_internal(application_id: UUID, db: Session = Depends(get_db), user: User = Depends(require_recruitment_access)):
        app = db.get(Application, application_id)
        if app is None:
            raise HTTPException(404, "Candidature introuvable")
        require_campaign_access(db, user, app.campaign_id)
        row = db.get(ApplicationPersonality, app.id)
        return assessment_payload(row) if row else {"status": "not_invited"}

    @router.post("/personality/load")
    def load_public(payload: ApplicationTrackingRequest, db: Session = Depends(get_db)):
        _, row = public_attempt(db, payload)
        return assessment_payload(row, candidate=True)

    @router.post("/personality/save")
    def save_public(payload: PersonalitySave, db: Session = Depends(get_db)):
        app, row = public_attempt(db, payload, lock=True)
        editable(app, row)
        save_answers(row, payload, complete=False)
        db.commit()
        return assessment_payload(row, candidate=True)

    @router.post("/personality/submit")
    def submit_public(payload: PersonalitySave, db: Session = Depends(get_db)):
        app, row = public_attempt(db, payload, lock=True)
        if row.submitted_at:
            # Successful retries return the stored answer, never overwrite it.
            return assessment_payload(row, candidate=True)
        editable(app, row)
        save_answers(row, payload, complete=True)
        db.commit()
        return assessment_payload(row, candidate=True)

    @router.post("/personality/decline")
    def decline_public(payload: ApplicationTrackingRequest, db: Session = Depends(get_db)):
        app, row = public_attempt(db, payload, lock=True)
        if row.declined_at or row.submitted_at:
            return assessment_payload(row, candidate=True)
        editable(app, row)
        row.answers, row.scenario_answers, row.results = {}, {}, None
        row.declined_at, row.updated_at, row.revision = utc_now(), utc_now(), row.revision + 1
        db.commit()
        return assessment_payload(row, candidate=True)
