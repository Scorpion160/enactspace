"""One collective jury evaluation per candidate. No candidate notifications.

The source of truth for each score is the seven-criterion interview workbook.
English is a separate training indicator, never added to the general ranking.
"""
from uuid import UUID
from datetime import date as CalendarDate
from fastapi import Depends, HTTPException
from pydantic import BaseModel, Field, ConfigDict, StrictInt, model_validator
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.db.database import get_db
from app.core.time import utc_now
from app.models.audit import AuditLog
from app.models.user import User
from app.models.recruitment import (
    Application, ApplicationReview, RecruitmentCampaign,
    RecruitmentJuryMember, ApplicationInterviewJuror,
)
from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
from app.services.recruitment_access import can_manage_jury, eligible_juror, active_jury_member
from app.services.operational_integrity import lock_row
from app.services.audit_service import create_audit_log

WEIGHTS = {
    "motivation": 20,
    "mission_enactus": 15,
    "initiative_leadership": 15,
    "travail_equipe": 15,
    "esprit_entrepreneurial": 15,
    "communication": 10,
    "disponibilite": 10,
}
ENGLISH = (
    "comprehension_orale", "fluidite", "vocabulaire",
    "grammaire", "prononciation",
)
RUBRIC_VERSION = "jury-collectif-v1"
RECOMMENDATIONS = {"reserve", "tres_favorable", "favorable", "a_discuter", "defavorable"}


class CollectiveEvaluationSave(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ratings: dict[str, StrictInt | None]
    english: dict[str, StrictInt | None] | None = None
    strengths: str = Field(default="", max_length=3000)
    vigilance: str = Field(default="", max_length=3000)
    potential: str = Field(default="", max_length=3000)
    recommended_pole: str = Field(default="", max_length=150)
    justification: str = Field(default="", max_length=3000)
    recommendation: str = "reserve"
    actual_jury_member_ids: list[UUID] | None = Field(default=None, min_length=1, max_length=6)
    exception_reason: str | None = Field(default=None, max_length=600)

    @model_validator(mode="after")
    def valid(self):
        if set(self.ratings) != set(WEIGHTS):
            raise ValueError("Les sept critères du jury sont obligatoires.")
        if any(v is not None and (type(v) is not int or v < 1 or v > 5) for v in self.ratings.values()):
            raise ValueError("Chaque critère doit être noté de 1 à 5.")
        if self.english is not None:
            if set(self.english) != set(ENGLISH) or any(
                v is not None and (type(v) is not int or v < 1 or v > 5) for v in self.english.values()
            ):
                raise ValueError("Les cinq indicateurs d'anglais doivent être notés de 1 à 5.")
        if self.recommendation not in RECOMMENDATIONS:
            raise ValueError("Appréciation du jury inconnue.")
        if self.actual_jury_member_ids is not None and len(set(self.actual_jury_member_ids)) != len(self.actual_jury_member_ids):
            raise ValueError("Un juré ne peut être compté deux fois.")
        return self


def collective_score(ratings):
    if set(ratings) != set(WEIGHTS) or any(value is None for value in ratings.values()):
        return None
    return sum(value * WEIGHTS[key] / 5 for key, value in ratings.items())


def _latest_attendance(db, application_id):
    return db.query(AuditLog).filter(
        AuditLog.entity_type == "application",
        AuditLog.entity_id == application_id,
        AuditLog.action.in_({
            "entretien_reel_confirme_par_organisateur",
            "entretien_presence_jury_modifiee",
            "entretien_presence_enregistree",
            "entretien_report_replanifie_interne",
            "reorganisation_jury_indisponibilite_17nov",
        }),
    ).order_by(AuditLog.created_at.desc(), AuditLog.id.desc()).first()


def _current_jury(db, app, attendance):
    if attendance and attendance.action not in (
        "entretien_report_replanifie_interne",
        "reorganisation_jury_indisponibilite_17nov",
    ) and (attendance.new_value or {}).get("status") != "postponed" and (
        attendance.new_value or {}
    ).get("actual_jury_member_ids"):
        return [UUID(x) for x in attendance.new_value["actual_jury_member_ids"]]
    draft = db.get(RecruitmentInterviewDraft, app.id)
    if draft:
        return [UUID(x) for x in draft.jury_member_ids]
    return [
        row.jury_member_id for row in db.query(ApplicationInterviewJuror).filter(
            ApplicationInterviewJuror.application_id == app.id
        ).all()
    ]


def _private_access(db, application_id, actor, *, management=False):
    app = db.get(Application, application_id)
    if app is None:
        raise HTTPException(404, "Candidature introuvable.")
    campaign = db.get(RecruitmentCampaign, app.campaign_id)
    if campaign is None or not campaign.screening_published_at or not campaign.identities_revealed_at:
        raise HTTPException(403, "Les entretiens de cette campagne ne sont pas accessibles.")
    manager = can_manage_jury(db, actor)
    if management and not manager:
        raise HTTPException(403, "Action réservée aux responsables du recrutement.")
    attendance = _latest_attendance(db, app.id)
    current = _current_jury(db, app, attendance)
    juror = db.query(RecruitmentJuryMember).filter(
        RecruitmentJuryMember.campaign_id == app.campaign_id,
        RecruitmentJuryMember.user_id == actor.id,
        RecruitmentJuryMember.id.in_(current),
        RecruitmentJuryMember.is_active.is_(True),
    ).first()
    if not manager and not (juror and eligible_juror(actor)):
        raise HTTPException(403, "Accès réservé au jury affecté et aux responsables.")
    return app, attendance, current, manager


def _review(db, application_id):
    rows = db.query(ApplicationReview).filter(
        ApplicationReview.application_id == application_id,
        ApplicationReview.stage == "interview",
    ).with_for_update().all()
    if len(rows) > 1:
        raise HTTPException(409, "Plusieurs évaluations collectives existent ; une revue est nécessaire.")
    return rows[0] if rows else None


class AttendanceSave(BaseModel):
    """Private presence log. This does not alter or notify a public appointment."""
    model_config = ConfigDict(extra="forbid")
    status: str
    actual_day: CalendarDate | None = None
    actual_jury_member_ids: list[UUID] | None = Field(default=None, min_length=1, max_length=6)
    reason: str = Field(default="", max_length=1000)

    @model_validator(mode="after")
    def valid(self):
        if self.status not in {"completed", "postponed", "no_show", "scheduled"}:
            raise ValueError("Statut d'entretien inconnu.")
        if self.actual_jury_member_ids and len(self.actual_jury_member_ids) != len(set(self.actual_jury_member_ids)):
            raise ValueError("Le même juré ne peut être présent deux fois.")
        if self.status in {"postponed", "no_show"} and not self.reason.strip():
            raise ValueError("Une justification est requise pour le report ou l'absence.")
        return self


def register_collective_interview(router):
    @router.get("/applications/{application_id}/interview/collective")
    def read_collective(application_id: UUID, db: Session = Depends(get_db),
                        actor: User = Depends(require_recruitment_access)):
        app, attendance, member_ids, manager = _private_access(db, application_id, actor)
        rows = db.query(ApplicationReview).filter(
            ApplicationReview.application_id == app.id,
            ApplicationReview.stage == "interview",
        ).all()
        if len(rows) > 1:
            raise HTTPException(409, "Évaluations en conflit ; contacter l'organisation.")
        review = rows[0] if rows else None
        details = (review.criteria_assessment or {}) if review else {}
        return {
            "application_id": str(app.id),
            "status": (
                "postponed"
                if attendance and attendance.action == "entretien_report_replanifie_interne"
                else (attendance.new_value or {}).get("status", "scheduled")
                if attendance else "scheduled"
            ),
            "score": float(review.score) if review and review.score is not None else None,
            "rating_version": details.get("rubric_version"),
            "ratings": details.get("ratings", {}),
            "english": details.get("english"),
            "english_score": details.get("english_score"),
            "strengths": details.get("strengths", ""),
            "vigilance": details.get("vigilance", ""),
            "potential": details.get("potential", ""),
            "recommended_pole": details.get("recommended_pole", ""),
            "justification": details.get("justification", ""),
            "recommendation": review.recommendation if review else None,
            "actual_jury_member_ids": [str(value) for value in member_ids],
            "entered_by": str(review.reviewer_id) if review else None,
            "last_edited_by": details.get("last_edited_by"),
            "can_manage_jury": manager,
            "can_edit": bool(manager or review is None or review.reviewer_id == actor.id),
            "candidate_notifications": 0,
        }

    @router.put("/applications/{application_id}/interview/collective")
    def save_collective(application_id: UUID, payload: CollectiveEvaluationSave,
                        db: Session = Depends(get_db),
                        actor: User = Depends(require_recruitment_access)):
        app, attendance, member_ids, manager = _private_access(db, application_id, actor)
        lock_row(db, RecruitmentCampaign, app.campaign_id)
        new_jury = payload.actual_jury_member_ids or member_ids
        if new_jury != member_ids:
            if not manager or not (payload.exception_reason or "").strip():
                raise HTTPException(409, "Un remplacement de juré exige une justification et un responsable.")
            allowed = {
                m.id: u for m, u in db.query(RecruitmentJuryMember, User).join(
                    User, User.id == RecruitmentJuryMember.user_id
                ).filter(RecruitmentJuryMember.campaign_id == app.campaign_id).all()
                if m.is_active and eligible_juror(u)
            }
            if any(member_id not in allowed for member_id in new_jury):
                raise HTTPException(409, "Un membre du jury remplacé n'est pas habilité.")
            # A real-world emergency may legitimately break the department-coverage
            # rule, but only the authorized manager can record that exception.
            create_audit_log(
                db, "entretien_presence_jury_modifiee", actor.id,
                "application", app.id,
                old_value={"actual_jury_member_ids": [str(x) for x in member_ids]},
                new_value={
                    "actual_jury_member_ids": [str(x) for x in new_jury],
                    "status": (
                "postponed"
                if attendance and attendance.action == "entretien_report_replanifie_interne"
                else (attendance.new_value or {}).get("status", "scheduled")
                if attendance else "scheduled"
            ),
                    "reason": payload.exception_reason.strip(),
                },
            )
        existing = _review(db, app.id)
        if existing is not None and existing.reviewer_id != actor.id and not manager:
            raise HTTPException(403, "La note du jury a déjà un saisisseur désigné. Contacter les responsables.")
        previous_assessment = dict(existing.criteria_assessment or {}) if existing else None
        previous_score = float(existing.score) if existing and existing.score is not None else None
        if existing is None:
            existing = ApplicationReview(
                application_id=app.id, reviewer_id=actor.id, stage="interview",
            )
            db.add(existing)
        general = collective_score(payload.ratings)
        english_total = (
            sum(payload.english.values())
            if payload.english is not None and all(v is not None for v in payload.english.values())
            else None
        )
        existing.score = general
        existing.recommendation = payload.recommendation
        existing.comment = payload.justification
        existing.criteria_assessment = {
            "rubric_version": RUBRIC_VERSION,
            "ratings": payload.ratings,
            "weights": WEIGHTS,
            "english": payload.english,
            "english_score": english_total,
            "strengths": payload.strengths,
            "vigilance": payload.vigilance,
            "potential": payload.potential,
            "recommended_pole": payload.recommended_pole,
            "justification": payload.justification,
            "actual_jury_member_ids": [str(x) for x in new_jury],
            "last_edited_by": str(actor.id),
        }
        existing.updated_at = utc_now()
        create_audit_log(
            db, "notation_collective_entretien", actor.id,
            "application", app.id,
            old_value={"score": previous_score, "assessment": previous_assessment},
            new_value={
                "score": general,
                "assessment": dict(existing.criteria_assessment),
                "english_score": english_total,
                "rubric_version": RUBRIC_VERSION,
                "notification_candidates": 0,
            },
        )
        db.commit()
        return {"saved": True, "collective": True, "general_score": general,
                "complete": general is not None,
                "english_score": english_total,
                "candidate_notifications": 0}

    @router.put("/applications/{application_id}/interview/attendance")
    def record_attendance(application_id: UUID, payload: AttendanceSave,
                          db: Session = Depends(get_db),
                          actor: User = Depends(require_recruitment_access)):
        app, attendance, previous, manager = _private_access(db, application_id, actor)
        lock_row(db, RecruitmentCampaign, app.campaign_id)
        actual = payload.actual_jury_member_ids or previous
        if not actual:
            raise HTTPException(409, "Aucun jury n'est rattaché à cet entretien.")
        changed = set(actual) != set(previous)
        if changed and (not manager or not payload.reason.strip()):
            raise HTTPException(403, "Seul un responsable peut valider un remplacement motivé.")
        if changed:
            authorized = {
                m.id for m, u in db.query(RecruitmentJuryMember, User).join(
                    User, User.id == RecruitmentJuryMember.user_id
                ).filter(RecruitmentJuryMember.campaign_id == app.campaign_id).all()
                if m.is_active and eligible_juror(u)
            }
            if any(mid not in authorized for mid in actual):
                raise HTTPException(409, "Un juré indiqué n'est pas habilité.")
        value = {
            "status": payload.status,
            "actual_day": payload.actual_day.isoformat() if payload.actual_day else None,
            "actual_jury_member_ids": [str(x) for x in actual],
            "reason": payload.reason.strip(),
            "public_schedule_changed": False,
            "candidate_notifications": 0,
        }
        create_audit_log(
            db, "entretien_presence_enregistree", actor.id,
            "application", app.id,
            old_value=attendance.new_value if attendance else None,
            new_value=value,
        )
        db.commit()
        return {"saved": True, **value}

    @router.get("/campaigns/{campaign_id}/interviews/jury-options")
    def jury_options(campaign_id: UUID, db: Session = Depends(get_db),
                     actor: User = Depends(require_recruitment_access)):
        if not can_manage_jury(db, actor) and not active_jury_member(db, actor, campaign_id):
            raise HTTPException(403, "Liste réservée aux membres du jury.")
        rows = db.query(RecruitmentJuryMember, User).join(
            User, User.id == RecruitmentJuryMember.user_id
        ).filter(RecruitmentJuryMember.campaign_id == campaign_id).all()
        return {"members": [
            {"id": str(m.id), "name": f"{u.first_name} {u.last_name}".strip(),
             "department": u.department}
            for m, u in rows if m.is_active and eligible_juror(u)
        ]}

    @router.get("/campaigns/{campaign_id}/interviews/collective/ranking")
    def collective_ranking(campaign_id: UUID, db: Session = Depends(get_db),
                           actor: User = Depends(require_recruitment_access)):
        if not can_manage_jury(db, actor):
            raise HTTPException(403, "Classement réservé aux responsables.")
        reviews = db.query(ApplicationReview, Application).join(
            Application, Application.id == ApplicationReview.application_id
        ).filter(
            Application.campaign_id == campaign_id,
            ApplicationReview.stage == "interview",
            ApplicationReview.score.is_not(None),
        ).all()
        collective = [
            (review, app) for review, app in reviews
            if (review.criteria_assessment or {}).get("rubric_version") == RUBRIC_VERSION
        ]
        if len({app.id for _, app in collective}) != len(collective):
            raise HTTPException(409, "Des notes collectives en double nécessitent une revue.")
        ordered = sorted(collective, key=lambda row: (
            -float(row[0].score), row[1].last_name.casefold(), row[1].first_name.casefold()
        ))
        return {
            "evaluated": len(ordered),
            "ranking": [{
                "rank": index + 1,
                "application_id": str(app.id),
                "candidate_name": f"{app.first_name} {app.last_name}".strip(),
                "department": app.department,
                "score": float(review.score),
                "english_score": (review.criteria_assessment or {}).get("english_score"),
                "recommendation": review.recommendation,
            } for index, (review, app) in enumerate(ordered)],
            "published_to_candidates": False,
        }
