"""Public-facing descriptions of the private recruitment audit trail."""
from datetime import timezone

from sqlalchemy.orm import Session

from app.models.audit import AuditLog
from app.models.recruitment import Application
from app.models.user import User


def member_name(user: User | None) -> str:
    if user is None:
        return "L’équipe recrutement"
    return " ".join(part for part in (user.first_name, user.last_name) if part).strip() or "Un membre de l’équipe"


def utc_date(value):
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def application_history(db: Session, application: Application) -> list[dict]:
    rows = [{
        "id": "submission-" + str(application.id),
        "kind": "submission",
        "title": "Candidature reçue",
        "occurred_at": utc_date(application.created_at),
        "actor_name": "Le candidat ou la candidate",
        "from_status": None,
        "to_status": "submitted",
        "scheduled_for": None,
    }]
    actions = {"changement_statut_candidature", "programmation_entretien_candidature", "conversion_candidature"}
    logs = db.query(AuditLog, User).outerjoin(User, User.id == AuditLog.user_id).filter(
        AuditLog.entity_type == "application", AuditLog.entity_id == application.id,
        AuditLog.action.in_(actions),
    ).order_by(AuditLog.created_at, AuditLog.id).all()
    aliases = {"received": "submitted", "preselected": "under_review", "interview": "interview_scheduled"}
    for log, actor in logs:
        old, new = log.old_value or {}, log.new_value or {}
        previous, following = old.get("status"), new.get("status")
        previous, following = aliases.get(previous, previous), aliases.get(following, following)
        if log.action == "changement_statut_candidature":
            kind = "status"
            title = "Entretien programmé" if new.get("interview_scheduled") else "Statut mis à jour"
        elif log.action == "programmation_entretien_candidature":
            kind, title = "interview", "Entretien mis à jour"
        else:
            kind = "integration"
            title = "Compte membre associé" if new.get("existing_user") else "Compte membre créé"
        rows.append({
            "id": str(log.id), "kind": kind, "title": title,
            "occurred_at": utc_date(log.created_at), "actor_name": member_name(actor),
            "from_status": previous, "to_status": following,
            "scheduled_for": new.get("interview_at"),
        })
    return sorted(rows, key=lambda row: (row["occurred_at"], row["id"]))
