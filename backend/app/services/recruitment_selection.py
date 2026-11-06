"""Blind screening, balanced assignments and atomic publication of results."""
import hashlib
import json
import re
import secrets
import unicodedata
from typing import Literal
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import and_, func, or_, select

from app.api.deps import require_recruitment_access
from app.core.time import utc_now
from app.db.database import get_db
from app.models.recruitment import (
    Application, ApplicationInterviewJuror, ApplicationReview,
    ApplicationScreeningAssignment, RecruitmentCampaign, RecruitmentJuryMember,
)
from app.models.user import User
from app.models.email_delivery import EmailDelivery
from app.services.audit_service import create_audit_log
from app.services.operational_integrity import lock_row
from app.services.recruitment_access import can_manage_jury, eligible_juror, require_campaign_access
from app.services.recruitment_rubric import VERSION, structured_summary
from app.schemas.recruitment_schedule import RecruitmentSchedule, NOVEMBER_2026_SCHEDULE

POLICY_VERSION = "blind-selection-v1"


def uses_blind_selection(campaign, application=None):
    return campaign.selection_policy_version == POLICY_VERSION and not (
        application is not None and application.legacy_result_published
    )


def campaign_for_application(db, application):
    return db.get(RecruitmentCampaign, application.campaign_id)


def identity_is_visible(db, user, campaign):
    if uses_blind_selection(campaign) and not (campaign.screening_published_at and campaign.identities_revealed_at):
        return False
    if can_manage_jury(db, user):
        return True
    return eligible_juror(user) and db.query(RecruitmentJuryMember.id).filter(
        RecruitmentJuryMember.campaign_id == campaign.id,
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None


def review_stage(campaign, application=None):
    interview_started = application is not None and application.screening_decision == "shortlisted" and application.status in {"interview_scheduled", "interview"}
    return "interview" if uses_blind_selection(campaign, application) and (campaign.screening_published_at or interview_started) else "screening"


def active_jurors(db, campaign_id):
    rows = db.query(User).join(RecruitmentJuryMember, RecruitmentJuryMember.user_id == User.id).filter(
        RecruitmentJuryMember.campaign_id == campaign_id,
        RecruitmentJuryMember.is_active.is_(True),
    ).all()
    return [user for user in rows if eligible_juror(user)]


def assignment_ids(db, user):
    return select(ApplicationScreeningAssignment.application_id).where(
        ApplicationScreeningAssignment.reviewer_id == user.id,
        ApplicationScreeningAssignment.declined_at.is_(None),
    )


def is_assigned(db, user, application):
    return db.query(ApplicationScreeningAssignment.application_id).join(
        RecruitmentJuryMember, RecruitmentJuryMember.user_id == ApplicationScreeningAssignment.reviewer_id
    ).filter(
        ApplicationScreeningAssignment.application_id == application.id,
        ApplicationScreeningAssignment.reviewer_id == user.id,
        ApplicationScreeningAssignment.declined_at.is_(None),
        RecruitmentJuryMember.campaign_id == application.campaign_id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None


def require_application_access(db, user, application):
    require_campaign_access(db, user, application.campaign_id)
    campaign = campaign_for_application(db, application)
    if not uses_blind_selection(campaign, application) or can_manage_jury(db, user) or identity_is_visible(db, user, campaign):
        return
    if review_stage(campaign, application) == "screening" and is_assigned(db, user, application):
        return
    interview = db.query(ApplicationInterviewJuror.application_id).join(
        RecruitmentJuryMember, RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id
    ).filter(
        ApplicationInterviewJuror.application_id == application.id,
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first()
    if review_stage(campaign, application) == "interview" and interview:
        return
    raise HTTPException(403, "Ce dossier ne fait pas partie de tes évaluations attribuées.")


def can_review_application(db, user, application, campaign):
    if not uses_blind_selection(campaign, application):
        return True
    if campaign.final_published_at or application.status in {"accepted", "rejected", "cancelled"}:
        return False
    if review_stage(campaign, application) == "screening":
        return is_assigned(db, user, application)
    if application.screening_decision != "shortlisted":
        return False
    return db.query(ApplicationInterviewJuror.application_id).join(
        RecruitmentJuryMember, RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id
    ).filter(
        ApplicationInterviewJuror.application_id == application.id,
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None


def require_review_assignment(db, user, application):
    require_application_access(db, user, application)
    campaign = campaign_for_application(db, application)
    if not uses_blind_selection(campaign, application):
        return
    if not can_review_application(db, user, application, campaign):
        raise HTTPException(403, "Une attribution ouverte à ce dossier est nécessaire pour l’évaluer.")


def _fold_identity_with_positions(value):
    folded, positions = [], []
    for index, character in enumerate(value):
        plain = "".join(letter for letter in unicodedata.normalize("NFKD", character).casefold()
                        if not unicodedata.combining(letter))
        plain = plain.replace("œ", "oe").replace("æ", "ae")
        folded.append(plain)
        positions.extend([index] * len(plain))
    return "".join(folded), positions


def redact_candidate_text(value, application):
    if not value:
        return value
    result = str(value)
    identifiers = [application.first_name, application.last_name, application.email, application.phone]
    for name in (application.first_name, application.last_name):
        identifiers.extend(re.split(r"[\s-]+", name or ""))
    for identifier in sorted(set(filter(None, identifiers)), key=len, reverse=True):
        if len(identifier.strip()) >= 2:
            folded, positions = _fold_identity_with_positions(result)
            needle, _ = _fold_identity_with_positions(identifier.strip())
            if not needle:
                continue
            matches = list(re.finditer(r"(?<!\w)" + re.escape(needle) + r"(?!\w)", folded))
            for match in reversed(matches):
                start, end = positions[match.start()], positions[match.end() - 1] + 1
                while end < len(result) and unicodedata.combining(result[end]):
                    end += 1
                result = result[:start] + "[identité masquée]" + result[end:]
    result = re.sub(r"[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}", "[e-mail masqué]", result)
    result = re.sub(r"https?://\S+|www\.\S+", "[lien masqué]", result, flags=re.IGNORECASE)
    result = re.sub(r"(?<!\w)\+?\d[\d ()-]{6,}\d(?!\w)", "[numéro masqué]", result)
    return result


def reviewed_summary(reviews, campaign, stage):
    rows = [row for row in reviews if row.stage == stage]
    return structured_summary(rows, campaign.screening_rubric_version or VERSION)


def valid_reviews_query(db):
    return db.query(ApplicationReview).outerjoin(
        ApplicationScreeningAssignment,
        and_(
            ApplicationScreeningAssignment.application_id == ApplicationReview.application_id,
            ApplicationScreeningAssignment.reviewer_id == ApplicationReview.reviewer_id,
        ),
    ).filter(or_(
        ApplicationReview.stage != "screening",
        ApplicationScreeningAssignment.declined_at.is_(None),
    ))


def required_reviews(campaign, summary):
    minimum = campaign.screening_min_reviews or 2
    spread = summary["screening_spread"]
    return minimum + (1 if spread is not None and spread >= (campaign.screening_disagreement_threshold or 20) else 0)


def distribute_assignments(db, campaign, actor=None):
    """Top up missing assignments, keeping reviews and existing appointments."""
    if campaign.screening_published_at:
        raise HTTPException(409, "La présélection est déjà publiée.")
    jurors = active_jurors(db, campaign.id)
    applications = db.query(Application).filter(
        Application.campaign_id == campaign.id,
        Application.status.in_({"submitted", "under_review", "received", "preselected"}),
    ).order_by(Application.id).all()
    reviews = valid_reviews_query(db).join(Application, Application.id == ApplicationReview.application_id).filter(
        Application.campaign_id == campaign.id, ApplicationReview.stage == "screening",
    ).all()
    by_application = {}
    for row in reviews:
        by_application.setdefault(row.application_id, []).append(row)
    active_ids = {user.id for user in jurors}
    emails = {user.id: user.email.casefold() for user in jurors}
    assignments = db.query(ApplicationScreeningAssignment).join(
        Application, Application.id == ApplicationScreeningAssignment.application_id
    ).filter(Application.campaign_id == campaign.id).all()
    loads = {user_id: 0 for user_id in active_ids}
    assigned = {}
    excluded = {}
    for row in assignments:
        excluded.setdefault(row.application_id, set()).add(row.reviewer_id)
        if row.declined_at is None and row.reviewer_id in active_ids:
            assigned.setdefault(row.application_id, set()).add(row.reviewer_id)
            loads[row.reviewer_id] += 1
    # Existing assessments are preserved and count towards their author's load.
    for row in reviews:
        if row.reviewer_id in active_ids and row.reviewer_id not in excluded.get(row.application_id, set()):
            new = ApplicationScreeningAssignment(
                application_id=row.application_id, reviewer_id=row.reviewer_id, assigned_by=actor.id if actor else None,
            )
            db.add(new)
            excluded.setdefault(row.application_id, set()).add(row.reviewer_id)
            assigned.setdefault(row.application_id, set()).add(row.reviewer_id)
            loads[row.reviewer_id] += 1
    rng = secrets.SystemRandom()
    rng.shuffle(applications)
    created = 0
    shortages = 0
    for application in applications:
        summary = reviewed_summary(by_application.get(application.id, []), campaign, "screening")
        needed = max(0, required_reviews(campaign, summary) - len(assigned.get(application.id, set())))
        candidates = [user_id for user_id in active_ids
                      if user_id not in excluded.get(application.id, set())
                      and emails[user_id] != application.email.casefold()]
        rng.shuffle(candidates)
        candidates.sort(key=lambda user_id: loads[user_id])
        for user_id in candidates[:needed]:
            db.add(ApplicationScreeningAssignment(
                application_id=application.id, reviewer_id=user_id, assigned_by=actor.id if actor else None,
            ))
            loads[user_id] += 1
            created += 1
        shortages += max(0, needed - len(candidates))
    db.flush()
    return {"created": created, "unfilled": shortages, "loads": [
        {"reviewer_id": str(user_id), "assigned_count": load} for user_id, load in loads.items()
    ]}


def public_selection_state(campaign, application):
    if not uses_blind_selection(campaign, application):
        return application.status, None, None
    if not campaign.screening_published_at and review_stage(campaign, application) == "interview":
        return application.status, "shortlisted", None
    if campaign.final_published_at and application.screening_decision == "shortlisted":
        return application.status, "shortlisted", campaign.final_published_at
    if campaign.screening_published_at:
        return application.status, application.screening_decision, campaign.screening_published_at
    return ("under_review" if application.status != "submitted" else "submitted"), None, None


class AssignmentSettings(BaseModel):
    minimum_reviews: int = Field(default=2, ge=2, le=5, strict=True)
    disagreement_threshold: int = Field(default=20, ge=1, le=100, strict=True)


class SelectionDecision(BaseModel):
    stage: str
    decision: str


class SelectionPublication(BaseModel):
    stage: str
    revision: str = Field(min_length=64, max_length=64)


class AssignmentDecline(BaseModel):
    reason: Literal["recognition", "conflict_of_interest", "unavailable"]


def _manager_campaign(db, user, campaign_id):
    campaign = lock_row(db, RecruitmentCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(404, "Campagne introuvable")
    if not can_manage_jury(db, user):
        raise HTTPException(403, "Cette action est réservée à l’administration, au Team Leader, au secrétariat et aux responsables du pôle Veille.")
    if not uses_blind_selection(campaign):
        raise HTTPException(409, "Cette campagne historique utilise un processus déjà terminé.")
    return campaign


def selection_overview(db, campaign):
    applications = db.query(Application).filter(
        Application.campaign_id == campaign.id, Application.status != "cancelled",
    ).order_by(Application.id).all()
    reviews = valid_reviews_query(db).join(Application, Application.id == ApplicationReview.application_id).filter(
        Application.campaign_id == campaign.id,
    ).all()
    grouped = {}
    for row in reviews:
        grouped.setdefault(row.application_id, []).append(row)
    stage = review_stage(campaign)
    rows = []
    for application in applications:
        if application.legacy_result_published:
            continue
        if stage == "screening" and review_stage(campaign, application) == "interview":
            continue
        if stage == "interview" and application.screening_decision != "shortlisted":
            continue
        summary = reviewed_summary(grouped.get(application.id, []), campaign, stage)
        target = required_reviews(campaign, summary)
        rows.append({
            "application_id": str(application.id),
            "anonymous_code": "Candidat #" + str(application.id).replace("-", "")[:12].upper(),
            "decision": application.screening_decision if stage == "screening" else application.pending_final_decision,
            "review_count": summary["screening_review_count"],
            "required_reviews": target,
            "score": summary["screening_score"],
            "spread": summary["screening_spread"],
            "ready": summary["screening_review_count"] >= target,
        })
    revision_data = {
        "stage": stage, "rows": rows,
        "minimum": campaign.screening_min_reviews,
        "threshold": campaign.screening_disagreement_threshold,
        "schedule": campaign.selection_schedule,
    }
    revision = hashlib.sha256(json.dumps(revision_data, sort_keys=True).encode()).hexdigest()
    published_stage = "interview" if campaign.final_published_at else "screening"
    email_counts = dict(db.query(EmailDelivery.status, func.count(EmailDelivery.id)).filter(
        EmailDelivery.dedupe_key.like(f"recruitment-results:{campaign.id}:{published_stage}:%")
    ).group_by(EmailDelivery.status).all())
    calendar = RecruitmentSchedule.model_validate(campaign.selection_schedule) if campaign.selection_schedule else None
    result_date = (calendar.screening_results if stage == "screening" else calendar.final_results) if calendar else None
    return {
        "stage": stage, "rows": rows, "revision": revision,
        "selection_schedule": campaign.selection_schedule,
        "schedule_template": NOVEMBER_2026_SCHEDULE,
        "result_available_from": result_date,
        "can_publish_on_date": result_date is None or utc_now().date() >= result_date,
        "screening_published_at": campaign.screening_published_at,
        "final_published_at": campaign.final_published_at,
        "identities_revealed_at": campaign.identities_revealed_at,
        "minimum_reviews": campaign.screening_min_reviews,
        "disagreement_threshold": campaign.screening_disagreement_threshold,
        "eligible_jurors": len(active_jurors(db, campaign.id)),
        "result_emails": {"total": sum(email_counts.values()), **email_counts},
    }


def _enqueue_result(db, application, campaign, stage, published_at):
    from app.api.routes.recruitment import ensure_tracking_code
    from app.services.email_delivery_service import enqueue_email_delivery
    from app.services.recruitment_mail_copy import application_mail
    ensure_tracking_code(db, application)
    kind = ("screening_shortlisted" if application.screening_decision == "shortlisted" else "screening_not_shortlisted") if stage == "screening" else application.pending_final_decision
    title, body = application_mail(kind, application)
    delivery = enqueue_email_delivery(
        db, recipient_email=application.email, subject=title,
        text_body=body,
        dedupe_key=f"recruitment-results:{campaign.id}:{stage}:{application.id}",
    )
    if delivery is None:
        raise HTTPException(409, "L’envoi des résultats par e-mail doit être configuré avant la publication.")
    delivery.next_attempt_at = published_at
    delivery.created_at = published_at


def register_recruitment_selection(router):
    @router.post("/campaigns/{campaign_id}/selection/planning")
    def save_planning(campaign_id: UUID, payload: RecruitmentSchedule, db=Depends(get_db), user=Depends(require_recruitment_access)):
        campaign = _manager_campaign(db, user, campaign_id)
        previous = campaign.selection_schedule or {
            "applications_open": campaign.start_date.isoformat() if campaign.start_date else None,
            "applications_close": campaign.end_date.isoformat() if campaign.end_date else None,
        }
        campaign.start_date = payload.applications_open
        campaign.end_date = payload.applications_close
        campaign.selection_schedule = payload.model_dump(mode="json")
        campaign.updated_at = utc_now()
        create_audit_log(db, "planning_recrutement", user.id, "recruitment_campaign", campaign.id,
                         old_value=previous, new_value=campaign.selection_schedule)
        db.commit()
        return selection_overview(db, campaign)

    @router.get("/campaigns/{campaign_id}/selection")
    def overview(campaign_id: UUID, db=Depends(get_db), user=Depends(require_recruitment_access)):
        campaign = _manager_campaign(db, user, campaign_id)
        return selection_overview(db, campaign)

    @router.post("/campaigns/{campaign_id}/selection/assign")
    def assign(campaign_id: UUID, payload: AssignmentSettings, db=Depends(get_db), user=Depends(require_recruitment_access)):
        campaign = _manager_campaign(db, user, campaign_id)
        if campaign.screening_published_at:
            raise HTTPException(409, "La présélection est déjà publiée.")
        campaign.screening_min_reviews = payload.minimum_reviews
        campaign.screening_disagreement_threshold = payload.disagreement_threshold
        result = distribute_assignments(db, campaign, user)
        create_audit_log(db, "attribution_dossiers_recrutement", user.id, "recruitment_campaign", campaign.id, new_value={
            "created": result["created"], "unfilled": result["unfilled"],
            "minimum_reviews": campaign.screening_min_reviews,
        })
        db.commit()
        return result

    @router.post("/applications/{application_id}/selection-decision")
    def decide(application_id: UUID, payload: SelectionDecision, db=Depends(get_db), user=Depends(require_recruitment_access)):
        from app.api.routes.recruitment import application_payload, lock_review_application
        application = lock_review_application(db, str(application_id))
        campaign = _manager_campaign(db, user, application.campaign_id)
        stage = review_stage(campaign)
        allowed = {"shortlisted", "not_shortlisted"} if stage == "screening" else {"accepted", "rejected", "waiting_list"}
        if payload.stage != stage or payload.decision not in allowed or campaign.final_published_at:
            raise HTTPException(409, "La décision ne correspond pas à l’étape ouverte.")
        if application.status == "cancelled" or (stage == "interview" and application.screening_decision != "shortlisted"):
            raise HTTPException(409, "Ce dossier ne participe pas à cette sélection.")
        if stage == "screening":
            application.screening_decision = payload.decision
        else:
            if application.status != "interview_scheduled" or application.interview_at is None or application.interview_at > utc_now():
                raise HTTPException(409, "Programme et réalise l’entretien avant de préparer la décision finale.")
            if payload.decision in {"accepted", "waiting_list"}:
                from app.api.routes.recruitment_extensions import require_completed_questionnaire
                require_completed_questionnaire(db, application)
            application.pending_final_decision = payload.decision
        application.updated_at = utc_now()
        create_audit_log(db, "preparation_selection_recrutement", user.id, "application", application.id,
                         new_value={"stage": stage, "decision": payload.decision})
        db.commit()
        return application_payload(db, user, application)

    @router.post("/campaigns/{campaign_id}/selection/publish")
    def publish(campaign_id: UUID, payload: SelectionPublication, db=Depends(get_db), user=Depends(require_recruitment_access)):
        campaign = _manager_campaign(db, user, campaign_id)
        if payload.stage not in {"screening", "interview"}:
            raise HTTPException(422, "Étape de sélection inconnue.")
        previous = campaign.screening_published_at if payload.stage == "screening" else campaign.final_published_at
        if previous:
            return {"published_at": previous, "already_published": True}
        if campaign.is_active and (campaign.end_date is None or campaign.end_date >= utc_now().date()):
            raise HTTPException(409, "Clôture les dépôts de la campagne avant de publier les résultats.")
        if campaign.selection_schedule:
            calendar = RecruitmentSchedule.model_validate(campaign.selection_schedule)
            result_date = calendar.screening_results if payload.stage == "screening" else calendar.final_results
            if utc_now().date() < result_date:
                raise HTTPException(409, "La publication de ce lot est prévue à partir du " + result_date.strftime("%d/%m/%Y") + ".")
        report = selection_overview(db, campaign)
        if report["stage"] != payload.stage or report["revision"] != payload.revision:
            raise HTTPException(409, "La sélection a changé. Relis le bilan avant de publier.")
        if not report["rows"] or any(not row["ready"] or not row["decision"] for row in report["rows"]):
            raise HTTPException(409, "Chaque dossier doit avoir ses évaluations et une décision avant la publication.")
        from app.core.config import settings
        if settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT:
            raise HTTPException(409, "Les mails sont redirigés vers une adresse de test. Désactive cette redirection avant de publier pour informer les candidats.")
        applications = db.query(Application).filter(
            Application.id.in_([UUID(row["application_id"]) for row in report["rows"]])
        ).order_by(Application.id).with_for_update().all()
        published_at = utc_now()
        if payload.stage == "interview" and any(
            application.status != "interview_scheduled" or application.interview_at is None
            or application.interview_at > published_at for application in applications
        ):
            raise HTTPException(409, "Chaque entretien doit être réalisé avant de publier les décisions finales.")
        for application in applications:
            if payload.stage == "screening":
                application.status = "under_review" if application.screening_decision == "shortlisted" else "rejected"
                if application.screening_decision == "shortlisted":
                    from app.api.routes.recruitment_extensions import invite_required_questionnaire
                    invite_required_questionnaire(db, application, user)
            else:
                if application.pending_final_decision in {"accepted", "waiting_list"}:
                    from app.api.routes.recruitment_extensions import require_completed_questionnaire
                    require_completed_questionnaire(db, application)
                application.status = application.pending_final_decision
            application.updated_at = published_at
            _enqueue_result(db, application, campaign, payload.stage, published_at)
        if payload.stage == "screening":
            campaign.screening_published_at = published_at
        else:
            campaign.final_published_at = published_at
        create_audit_log(db, "publication_selection_recrutement", user.id, "recruitment_campaign", campaign.id,
                         new_value={"stage": payload.stage, "count": len(applications), "published_at": published_at.isoformat()})
        db.commit()
        return {"published_at": published_at, "count": len(applications), "already_published": False}

    @router.post("/campaigns/{campaign_id}/selection/reveal")
    def reveal(campaign_id: UUID, db=Depends(get_db), user=Depends(require_recruitment_access)):
        campaign = _manager_campaign(db, user, campaign_id)
        if not campaign.screening_published_at:
            raise HTTPException(409, "Publie d’abord les résultats de la présélection.")
        if not campaign.identities_revealed_at:
            campaign.identities_revealed_at = utc_now()
            campaign.identities_revealed_by = user.id
            create_audit_log(db, "levee_anonymat_recrutement", user.id, "recruitment_campaign", campaign.id,
                             new_value={"published_after_screening": True})
            db.commit()
        return {"revealed_at": campaign.identities_revealed_at}

    @router.post("/applications/{application_id}/selection/decline")
    def decline(application_id: UUID, payload: AssignmentDecline, db=Depends(get_db), user=Depends(require_recruitment_access)):
        from app.api.routes.recruitment import lock_review_application
        application = lock_review_application(db, str(application_id))
        require_review_assignment(db, user, application)
        campaign = campaign_for_application(db, application)
        if campaign.screening_published_at:
            raise HTTPException(409, "La présélection est close.")
        row = db.get(ApplicationScreeningAssignment, (application.id, user.id))
        if row is None:
            raise HTTPException(403, "Ce dossier ne t’est pas attribué.")
        row.declined_at = utc_now()
        row.decline_reason = payload.reason
        db.flush()
        result = distribute_assignments(db, campaign, user)
        create_audit_log(db, "deport_jure_recrutement", user.id, "application", application.id,
                         new_value={"reason": row.decline_reason, "unfilled": result["unfilled"]})
        db.commit()
        return {"ok": True, "unfilled": result["unfilled"]}
