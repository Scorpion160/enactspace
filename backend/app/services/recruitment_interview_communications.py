"""Human-reviewed, campaign-scoped interview communication.

Preview has no side effects. Sending requires an exact preview fingerprint and
one batch UUID. Delivery and appointment changes commit in one transaction.
Nothing is sent simply because a private proposal was edited.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date, datetime, timedelta
from email import policy
from email.message import EmailMessage
from email.parser import BytesParser
from hashlib import sha256
import json
import re
from typing import Literal
from uuid import UUID

from fastapi import Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy.orm import Session

from app.api.deps import require_recruitment_access
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import get_db
from app.models.audit import AuditLog
from app.models.email_delivery import EmailDelivery
from app.models.recruitment import (
    Application, ApplicationReview, ApplicationInterviewJuror,
    RecruitmentCampaign, RecruitmentJuryMember,
)
from app.models.recruitment_interview_drafts import RecruitmentInterviewDraft
from app.models.recruitment_interview_policy import RecruitmentJuryAvailability
from app.models.user import User
from app.services.audit_service import create_audit_log
from app.services.email_delivery_service import enqueue_email_delivery
from app.services.email_templates import app_link, render_email_html
from app.services.operational_integrity import lock_row
from app.services.recruitment_access import can_manage_jury, require_campaign_access
from app.services.recruitment_interview_policy import fetch_policy, within_windows, juror_available
from app.services.recruitment_jury_constraints import jury_constraints, juror_respects_constraints
from app.services.recruitment_interviews import department_key, effective_interview_end

DAYS = ("lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche")
MONTHS = ("", "janvier", "février", "mars", "avril", "mai", "juin",
          "juillet", "août", "septembre", "octobre", "novembre", "décembre")
AUDIT_ACTION = "communication_entretiens_validee"


class InterviewCommunicationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    action: Literal["publish", "venue", "reminder"]
    application_ids: list[UUID] = Field(default_factory=list, max_length=80)
    interview_date: date | None = None
    from_time: str = Field(default="00:00", pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    until_time: str = Field(default="23:59", pattern=r"^(?:[01]\d|2[0-3]):[0-5]\d$")
    location: str | None = Field(default=None, max_length=180)
    exception_reason: str | None = Field(default=None, max_length=900)
    send_candidates: bool = True
    send_jurors: bool = True
    batch_id: UUID | None = None
    preview_signature: str | None = None

    @model_validator(mode="after")
    def valid(self):
        if bool(self.application_ids) == bool(self.interview_date):
            raise ValueError("Sélectionne un ou plusieurs candidats, ou une journée.")
        if self.from_time > self.until_time:
            raise ValueError("La plage horaire est inversée.")
        if len(self.application_ids) != len(set(self.application_ids)):
            raise ValueError("Un même candidat est sélectionné plusieurs fois.")
        if not self.send_candidates and not self.send_jurors:
            raise ValueError("Sélectionne au moins un type de destinataire.")
        if self.action in {"publish", "venue"} and not self.send_candidates:
            raise ValueError("Informe les candidats quand leur rendez-vous officiel change.")
        if self.action == "venue" and not (self.location or "").strip():
            raise ValueError("Renseigne la nouvelle salle avant de communiquer.")
        if self.action == "reminder" and self.location:
            raise ValueError("Pour modifier le lieu, choisis « Changement de salle ».")
        return self


def _allowed_status(status, action):
    if action == "publish":
        return status in {"under_review", "interview", "interview_scheduled"}
    return status in {"interview", "interview_scheduled"}


def _has_confirmed_realization(events):
    """Missed appointments can be reprogrammed; completed ones cannot."""
    return any(
        (event.new_value or {}).get("status") in {"completed", "completed_pending_score"}
        for event in events
    )


def _name(value):
    return f"{value.first_name} {value.last_name}".strip()


def _when(dt):
    return (f"{DAYS[dt.weekday()]} {dt.day} {MONTHS[dt.month]} {dt.year}"
            f" à {dt.hour:02d} h {dt.minute:02d}")


def _room_text(place):
    return f"Lieu : {place}." if place else "Le lieu exact sera communiqué ultérieurement."


def _email_ok(email):
    return bool(email and re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email.strip()))


def _validate_mail(mail):
    subject, body = mail["subject"], mail["body"]
    if any(ch in subject + body for ch in ("\ufffd", "\x00", "?")):
        raise HTTPException(409, "Un caractère invalide a été détecté dans le message.")
    if not _email_ok(mail["email"]):
        raise HTTPException(409, "Une adresse e-mail est absente ou invalide.")
    html = render_email_html(subject, body)
    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = "enactus@esp.sn"
    message["To"] = mail["email"]
    message.set_content(body, charset="utf-8")
    message.add_alternative(html, subtype="html", charset="utf-8")
    parsed = BytesParser(policy=policy.default).parsebytes(message.as_bytes())
    if (str(parsed["Subject"]) != subject
            or parsed.get_body(preferencelist=("plain",)).get_content().rstrip("\n") != body):
        raise HTTPException(409, "Le contrôle de l'encodage UTF-8 a échoué.")
    mail["html"] = html


def _insert_candidate_instructions(body: str, addition: str) -> str:
    footer = "\n\nL\u2019\u00e9quipe de recrutement Enactus ESP"
    if not body.endswith(footer):
        raise HTTPException(409, "La signature du message est introuvable.")
    return body[:-len(footer)] + addition + footer


def _online_candidate_instructions(application) -> str:
    if not application.tracking_code:
        raise HTTPException(409, "Le candidat n'a pas de code de suivi utilisable.")
    tracking_url = app_link("application-tracking")
    return (
        "\n\nPour rejoindre ton entretien EnactMeet :"
        f"\n1. Ouvre cette page : {tracking_url}"
        f"\n2. Saisis ton code de suivi : {application.tracking_code}"
        "\n3. Saisis l'adresse e-mail utilis\u00e9e lors de ta candidature."
        "\n4. Si ton questionnaire n'est pas encore envoy\u00e9, termine-le "
        "et valide tes r\u00e9ponses avant le rendez-vous."
        "\n5. Quinze minutes avant ton cr\u00e9neau, clique sur "
        "Rejoindre mon entretien, une fois la salle ouverte par le jury."
        "\n6. Reste dans la salle d'attente jusqu'\u00e0 ce qu'un jur\u00e9 t'admette. "
        "Ne rejoins pas le passage d'un autre candidat."
        "\n7. Si la connexion est interrompue, reviens sur le suivi "
        "de ta candidature et clique de nouveau sur Rejoindre mon entretien."
        "\nPr\u00e9pare ton micro et ta cam\u00e9ra et utilise une connexion stable."
    )


def _members(db, campaign_id):
    return {str(member.id): (member, user)
            for member, user in db.query(RecruitmentJuryMember, User).join(
                User, User.id == RecruitmentJuryMember.user_id,
            ).filter(RecruitmentJuryMember.campaign_id == campaign_id).all()}


def _get_old_jury(db, app):
    return [str(row.jury_member_id) for row in db.query(ApplicationInterviewJuror).filter(
        ApplicationInterviewJuror.application_id == app.id,
    ).all()]


def _scoped(db, campaign, actor, payload):
    require_campaign_access(db, actor, campaign.id)
    if not can_manage_jury(db, actor):
        raise HTTPException(403, "Seule la coordination du recrutement peut envoyer ces messages.")
    query = db.query(Application, RecruitmentInterviewDraft).join(
        RecruitmentInterviewDraft, RecruitmentInterviewDraft.application_id == Application.id,
    ).filter(Application.campaign_id == campaign.id)
    if payload.application_ids:
        query = query.filter(Application.id.in_(payload.application_ids))
    else:
        # The date filter uses the prepared slot for publication, the official slot
        # for reminders and venue announcements. No cross-campaign leakage.
        date_column = (RecruitmentInterviewDraft.starts_at if payload.action == "publish"
                       else Application.interview_at)
        start = datetime.combine(payload.interview_date, datetime.min.time())
        query = query.filter(date_column >= start,
                             date_column < start + timedelta(days=1))
    rows = query.all()
    if payload.application_ids and len(rows) != len(payload.application_ids):
        raise HTTPException(404, "Une des candidatures n'appartient pas à cette campagne.")
    rows = sorted(rows, key=lambda pair: (
        pair[1].starts_at if payload.action == "publish" else pair[0].interview_at or datetime.max,
        str(pair[0].id),
    ))
    if not payload.application_ids:
        rows = [(app, draft) for app, draft in rows
                if payload.from_time <= (draft.starts_at if payload.action == "publish"
                                          else app.interview_at).strftime("%H:%M") <= payload.until_time]
    if not rows:
        raise HTTPException(422, "Aucun entretien ne correspond à la sélection.")
    if len(rows) > 80:
        raise HTTPException(422, "Sélectionne au maximum 80 entretiens par envoi.")
    return rows


def _build(db, campaign, actor, payload):
    rows = _scoped(db, campaign, actor, payload)
    members = _members(db, campaign.id)
    current = utc_now()
    chosen_ids = {app.id for app, _ in rows}
    availabilities = {str(x.user_id): x.windows for x in db.query(
        RecruitmentJuryAvailability).filter(
            RecruitmentJuryAvailability.campaign_id == campaign.id,
        ).all()}
    blackouts, remote_only = jury_constraints(db, campaign.id)
    notices = []
    jury_lines = defaultdict(list)
    changes = []
    for app, draft in rows:
        if not _allowed_status(app.status, payload.action) or app.screening_decision != "shortlisted":
            raise HTTPException(409, f"{_name(app)} : candidature non autorisée pour une convocation.")
        if not _email_ok(app.email):
            raise HTTPException(409, f"{_name(app)} : adresse e-mail manquante ou invalide.")
        old_start, old_end = app.interview_at, app.interview_end_at
        old_jury = _get_old_jury(db, app)
        new_start = draft.starts_at if payload.action == "publish" else old_start
        new_end = draft.ends_at if payload.action == "publish" else (effective_interview_end(old_start, old_end) if old_start else None)
        new_jury = [str(mid) for mid in draft.jury_member_ids] if payload.action == "publish" else old_jury
        new_mode = draft.mode if payload.action == "publish" else app.interview_mode
        new_location = ((payload.location or "").strip() or draft.location) if payload.action == "publish" \
            else ((payload.location or "").strip() if payload.action == "venue" else app.interview_location)
        if not new_start or not new_end or new_end <= new_start:
            raise HTTPException(409, f"{_name(app)} : horaire officiel ou préparé manquant.")
        if new_end <= current:
            raise HTTPException(409, f"{_name(app)} : l'entretien est déjà passé.")
        if payload.action == "publish":
            existing_score = db.query(ApplicationReview.id).filter(
                ApplicationReview.application_id == app.id, ApplicationReview.stage == "interview",
                ApplicationReview.score.isnot(None),
            ).first()
            realized = db.query(AuditLog).filter(
                AuditLog.entity_type == "application", AuditLog.entity_id == app.id,
                AuditLog.action.in_(("entretien_presence_enregistree",
                                     "entretien_reel_confirme_par_organisateur")),
            ).all()
            if existing_score or _has_confirmed_realization(realized):
                raise HTTPException(
                    409, f"{_name(app)} : l'entretien est déjà marqué réalisé."
                )
            if not within_windows(fetch_policy(db, campaign.id), new_start, new_end):
                raise HTTPException(409, f"{_name(app)} : horaire hors des règles de campagne.")
            if len(new_jury) != 3 or len(set(new_jury)) != 3:
                raise HTTPException(409, f"{_name(app)} : le jury doit avoir trois membres distincts.")
            dept_set = set()
            for mid in new_jury:
                if mid not in members:
                    raise HTTPException(409, f"{_name(app)} : juré introuvable.")
                member, user = members[mid]
                if not member.is_active or not user.is_active or not user.email_verified or user.status not in ("active", "alumni"):
                    raise HTTPException(409, f"{_name(app)} : juré non actif.")
                if not juror_available(availabilities.get(str(user.id), []), new_start, new_end) \
                        or not juror_respects_constraints(user.id, new_start, new_mode, blackouts, remote_only):
                    raise HTTPException(409, f"{_name(app)} : {_name(user)} est indisponible.")
                if user.email.casefold() == app.email.casefold():
                    raise HTTPException(409, "Un juré ne peut pas évaluer sa propre candidature.")
                dept_set.add(department_key(user.department))
            if (len(dept_set) != 3 or department_key(app.department) not in dept_set) \
                    and len((payload.exception_reason or "").strip()) < 12:
                raise HTTPException(409, f"{_name(app)} : justifie l'exception de composition du jury.")
            same = (old_start == new_start and old_end == new_end
                    and set(old_jury) == set(new_jury) and app.interview_mode == new_mode
                    and (app.interview_location or "") == (new_location or ""))
            if same:
                raise HTTPException(409, f"{_name(app)} : ce créneau est déjà publié. Utilise « Rappel ».")
            # Cross-check the draft against every published appointment that is
            # NOT being replaced in this exact manager-approved batch.
            occupied = db.query(Application).filter(
                Application.campaign_id == campaign.id,
                Application.id.notin_(chosen_ids),
                Application.interview_at.isnot(None),
                Application.interview_at < new_end,
            ).all()
            for other in occupied:
                other_end = other.interview_end_at or other.interview_at + timedelta(minutes=20)
                if other_end > new_start and set(_get_old_jury(db, other)) & set(new_jury):
                    raise HTTPException(409, "Un juré a un conflit avec un entretien déjà publié.")
        if payload.action in ("reminder", "venue") and not old_jury and payload.send_jurors:
            raise HTTPException(409, f"{_name(app)} : aucun juré officiellement affecté.")
        if payload.action == "venue" and (not new_location or len(new_location) < 3):
            raise HTTPException(422, "Renseigne une salle suffisamment précise.")
        change = {
            "application_id": str(app.id), "name": _name(app),
            "old": old_start.isoformat() if old_start else None,
            "new": new_start.isoformat(), "end": new_end.isoformat(),
            "old_jury": old_jury, "new_jury": new_jury,
            "old_location": app.interview_location, "location": new_location,
            "mode": new_mode, "draft_revision": draft.revision,
        }
        changes.append(change)
        if payload.action == "publish":
            lead = f"Ton entretien de recrutement est désormais prévu le {_when(new_start)}."
            if old_start and old_start != new_start:
                lead += f"\nCe créneau remplace le rendez-vous du {_when(old_start)}."
        elif payload.action == "venue":
            lead = f"Le lieu de ton entretien du {_when(new_start)} est confirmé ou modifié."
        else:
            lead = f"Nous te rappelons ton entretien de recrutement prévu le {_when(new_start)}."
        if payload.send_candidates:
            body = (f"Bonjour {app.first_name},\n\n{lead}\n"
                    f"Durée : {int((new_end - new_start).total_seconds()/60)} minutes.\n"
                    f"{_room_text(new_location)}\n"
                    f"{'L’entretien se déroulera à distance.' if new_mode == 'online' else 'Tu es attendu(e) en présentiel.'}\n\n"
                    "Merci de te présenter quelques minutes avant ton passage. "
                    "En cas d'empêchement, informe rapidement l'équipe de recrutement.\n\n"
                    "L’équipe de recrutement Enactus ESP")
            if new_mode == "online":
                body = _insert_candidate_instructions(
                    body, _online_candidate_instructions(app),
                )
            if payload.action in ("publish", "reminder"):
                from app.services.recruitment_interview_outcomes import (
                    confirmed_absence_days, absence_limit,
                )
                misses = len(confirmed_absence_days(db, app.id))
                if misses >= absence_limit(campaign) - 1:
                    warning = (
                        "Ce rendez-vous constitue ta dernière chance "
                        "de passer l'entretien. Une nouvelle absence "
                        "confirmée pourra conduire à une exclusion "
                        "après vérification et décision "
                        "de l'équipe de recrutement."
                    )
                    signature = "\n\nL’équipe de recrutement Enactus ESP"
                    if not body.endswith(signature):
                        raise HTTPException(409, "Signature de convocation invalide.")
                    body = body[:-len(signature)] + "\n\n" + warning + signature
            subject = {"publish": "Confirmation ou reprogrammation de ton entretien",
                       "venue": "Lieu de ton entretien",
                       "reminder": "Rappel de ton entretien"}[payload.action]
            notices.append({
                "kind": "candidate", "name": _name(app), "email": app.email.strip().lower(),
                "subject": f"Enactus ESP — {subject}", "body": body, "application_id": str(app.id),
            })
        if payload.send_jurors:
            for mid in set(old_jury if payload.action == "publish" else new_jury) | set(new_jury):
                if mid not in members:
                    raise HTTPException(409, f"{_name(app)} : ancien juré introuvable.")
                member, user = members[mid]
                if not _email_ok(user.email):
                    raise HTTPException(409, f"{_name(user)} : adresse e-mail manquante.")
                if payload.action == "publish" and mid not in new_jury:
                    line = f"- {_name(app)} : ton ancienne affectation du {_when(old_start)} est annulée."
                else:
                    line = (f"- {_name(app)} : {_when(new_start)}, "
                            f"{int((new_end-new_start).total_seconds()/60)} minutes. "
                            f"{_room_text(new_location)}")
                    if payload.action == "publish" and mid in old_jury and old_start != new_start:
                        line += f" L'ancien créneau du {_when(old_start)} est remplacé."
                jury_lines[mid].append(line)
    if payload.send_jurors:
        for mid, lines in sorted(jury_lines.items()):
            member, user = members[mid]
            intro = {"publish": "Le planning des jurys a été mis à jour.",
                     "venue": "Voici la salle communiquée pour tes entretiens.",
                     "reminder": "Voici le rappel de tes entretiens."}[payload.action]
            notices.append({
                "kind": "juror", "name": _name(user), "email": user.email.strip().lower(),
                "subject": "Enactus ESP — Mise à jour de tes entretiens de jury",
                "body": (f"Bonjour {user.first_name},\n\n{intro}\n\n"
                         + "\n".join(lines)
                         + "\n\nTes autres affectations restent inchangées. "
                           "Les autres Enacteurs et Alumni peuvent prendre part aux entretiens, "
                           "en coordination avec l'équipe de recrutement.\n\n"
                           "Merci pour ton engagement.\nL’équipe de recrutement Enactus ESP"),
                "member_id": mid,
            })
    if payload.action == "publish":
        # All new juries in the batch must be collision-free, including parallel
        # sessions. A conflict must fail before any appointment or email changes.
        for i, left in enumerate(changes):
            for right in changes[i + 1:]:
                if (left["new"] < right["end"] and right["new"] < left["end"]
                        and set(left["new_jury"]) & set(right["new_jury"])):
                    raise HTTPException(409, "Un juré figure dans deux entretiens simultanés.")
    # One individual email per juror, no ambiguous duplicate recipients.
    if len({(m["kind"], m["email"]) for m in notices}) != len(notices):
        raise HTTPException(409, "Deux comptes destinataires utilisent la même adresse.")
    if len(notices) > 240:
        raise HTTPException(422, "Trop de destinataires pour un seul envoi.")
    for message in notices:
        _validate_mail(message)
    fingerprint_data = {
        "campaign_id": str(campaign.id), "action": payload.action,
        "location": payload.location, "exception_reason": payload.exception_reason,
        "changes": changes,
        "messages": [{key: msg[key] for key in ("kind", "name", "email", "subject", "body")}
                     for msg in notices],
    }
    fingerprint = sha256(json.dumps(fingerprint_data, sort_keys=True,
                                   ensure_ascii=False, default=str).encode("utf-8")).hexdigest()
    return {"signature": fingerprint, "changes": changes, "messages": notices,
            "candidates": len(rows), "candidate_emails": sum(m["kind"] == "candidate" for m in notices),
            "juror_emails": sum(m["kind"] == "juror" for m in notices)}


def register_interview_communications(router):
    @router.post("/campaigns/{campaign_id}/interviews/communications/preview")
    def preview(campaign_id: UUID, payload: InterviewCommunicationRequest,
                db: Session = Depends(get_db),
                actor: User = Depends(require_recruitment_access)):
        campaign = db.get(RecruitmentCampaign, campaign_id)
        if not campaign:
            raise HTTPException(404, "Campagne introuvable.")
        result = _build(db, campaign, actor, payload)
        db.rollback()
        return result

    @router.post("/campaigns/{campaign_id}/interviews/communications/send")
    def send(campaign_id: UUID, payload: InterviewCommunicationRequest,
             db: Session = Depends(get_db),
             actor: User = Depends(require_recruitment_access)):
        if not payload.batch_id or not payload.preview_signature:
            raise HTTPException(422, "Prévisualise d'abord les messages avant de confirmer l'envoi.")
        campaign = lock_row(db, RecruitmentCampaign, campaign_id)
        if campaign is None:
            raise HTTPException(404, "Campagne introuvable.")
        require_campaign_access(db, actor, campaign.id)
        if not can_manage_jury(db, actor):
            raise HTTPException(403, "Action réservée aux responsables du recrutement.")
        existing = db.query(AuditLog).filter(
            AuditLog.entity_type == "recruitment_campaign",
            AuditLog.entity_id == campaign.id, AuditLog.action == AUDIT_ACTION,
        ).order_by(AuditLog.created_at.desc()).all()
        prior = next((log for log in existing if (log.new_value or {}).get("batch_id") == str(payload.batch_id)), None)
        if prior:
            saved = prior.new_value or {}
            if saved.get("signature") != payload.preview_signature:
                raise HTTPException(409, "Ce lot d'envoi existe déjà avec un contenu différent.")
            deliveries = db.query(EmailDelivery).filter(EmailDelivery.id.in_(
                [UUID(x) for x in saved.get("delivery_ids", [])],
            )).all()
            return {"already_sent": True, "batch_id": str(payload.batch_id),
                    "statuses": {str(m.id): m.status for m in deliveries},
                    "candidate_emails": saved.get("candidate_emails", 0),
                    "juror_emails": saved.get("juror_emails", 0)}
        result = _build(db, campaign, actor, payload)
        if payload.preview_signature != result["signature"]:
            raise HTTPException(409, "Le planning ou les destinataires ont changé. Reprends la prévisualisation.")
        if (not settings.email_enabled or not settings.SMTP_HOST
                or settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT):
            raise HTTPException(503, "L'envoi institutionnel n'est pas disponible.")
        if settings.NOTIFICATION_EMAIL_FROM.strip().casefold() != "enactus@esp.sn":
            raise HTTPException(503, "L'adresse d'envoi officielle n'est pas configurée.")
        for change in result["changes"]:
            app = db.get(Application, UUID(change["application_id"]))
            draft = db.get(RecruitmentInterviewDraft, app.id)
            if payload.action == "publish":
                db.query(ApplicationInterviewJuror).filter_by(
                    application_id=app.id).delete(synchronize_session=False)
                db.flush()
                for member_id in change["new_jury"]:
                    db.add(ApplicationInterviewJuror(application_id=app.id,
                                                    jury_member_id=UUID(member_id)))
                app.interview_at = datetime.fromisoformat(change["new"])
                app.interview_end_at = datetime.fromisoformat(change["end"])
                app.interview_mode = change["mode"]
                app.status = "interview_scheduled"
                app.interview_jury = ", ".join(
                    _name(db.get(User, db.get(RecruitmentJuryMember, UUID(mid)).user_id))
                    for mid in change["new_jury"])
                app.interview_location = change["location"]
                draft.location = change["location"]
                draft.revision = (draft.revision or 0) + 1
                draft.updated_by = actor.id
                draft.updated_at = utc_now()
            if payload.action == "venue":
                app.interview_location = change["location"]
                # A private rescheduling proposal can target another venue.
                # Do not overwrite its room when announcing the current slot.
                if draft.starts_at == app.interview_at:
                    draft.location = change["location"]
                    draft.revision = (draft.revision or 0) + 1
                    draft.updated_by = actor.id
                    draft.updated_at = utc_now()
            if payload.action != "reminder":
                app.updated_at = utc_now()
            create_audit_log(db, "communication_entretien_dossier", actor.id,
                             "application", app.id,
                             old_value={"interview_at": change["old"],
                                        "location": change["old_location"],
                                        "jury_member_ids": change["old_jury"]},
                             new_value={"action": payload.action, "batch_id": str(payload.batch_id),
                                        "interview_at": change["new"],
                                        "location": change["location"],
                                        "jury_member_ids": change["new_jury"]})
        db.flush()
        delivery_ids = []
        for index, msg in enumerate(result["messages"]):
            delivery = enqueue_email_delivery(
                db, recipient_email=msg["email"], subject=msg["subject"],
                text_body=msg["body"], html_body=msg["html"],
                dedupe_key=f"recruitment:communication:{campaign.id}:{payload.batch_id}:{index}",
            )
            if delivery is None or delivery.text_body != msg["body"] or delivery.html_body != msg["html"]:
                raise HTTPException(503, "Échec de préparation du message. Aucun envoi n'a été validé.")
            db.flush()
            delivery_ids.append(str(delivery.id))
        create_audit_log(
            db, AUDIT_ACTION, actor.id, "recruitment_campaign", campaign.id,
            new_value={"batch_id": str(payload.batch_id), "action": payload.action,
                       "signature": result["signature"],
                       "application_ids": [x["application_id"] for x in result["changes"]],
                       "delivery_ids": delivery_ids,
                       "candidate_emails": result["candidate_emails"],
                       "juror_emails": result["juror_emails"]},
        )
        db.commit()
        return {"already_sent": False, "batch_id": str(payload.batch_id),
                "queued": len(delivery_ids), "candidate_emails": result["candidate_emails"],
                "juror_emails": result["juror_emails"]}

    @router.get("/campaigns/{campaign_id}/interviews/communications/history")
    def history(campaign_id: UUID, db: Session = Depends(get_db),
                actor: User = Depends(require_recruitment_access)):
        campaign = db.get(RecruitmentCampaign, campaign_id)
        if not campaign:
            raise HTTPException(404, "Campagne introuvable.")
        require_campaign_access(db, actor, campaign.id)
        if not can_manage_jury(db, actor):
            raise HTTPException(403, "Historique réservé aux responsables.")
        logs = db.query(AuditLog).filter(
            AuditLog.entity_type == "recruitment_campaign",
            AuditLog.entity_id == campaign.id, AuditLog.action == AUDIT_ACTION,
        ).order_by(AuditLog.created_at.desc()).limit(40).all()
        all_ids = [UUID(did) for log in logs for did in (log.new_value or {}).get("delivery_ids", [])]
        deliveries = {str(row.id): row for row in db.query(EmailDelivery).filter(
            EmailDelivery.id.in_(all_ids)).all()} if all_ids else {}
        return {"batches": [
            {"date": log.created_at.isoformat(), **(log.new_value or {}),
             "statuses": dict(Counter(
                 deliveries[did].status for did in (log.new_value or {}).get("delivery_ids", [])
                 if did in deliveries))}
            for log in logs
        ]}
