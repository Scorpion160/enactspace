"""Candidate-facing messages; internal reviews never enter the email body."""
from datetime import timezone
import hashlib
import json

from app.services.email_delivery_service import enqueue_email_delivery



def enqueue_candidate_update(db, application, *, interview_updated=False):
    state = {"received":"submitted", "preselected":"under_review",
             "interview":"interview_scheduled"}.get(application.status, application.status)
    if state not in {"under_review", "interview_scheduled", "accepted", "rejected", "waiting_list", "cancelled"}:
        return None
    details = []
    if state == "interview_scheduled":
        when = application.interview_at
        if when is not None:
            if when.tzinfo is None:
                when = when.replace(tzinfo=timezone.utc)
            when = when.astimezone(timezone.utc)
            details.append("Date : " + when.strftime("%d/%m/%Y à %H:%M (heure de Dakar)"))
        if application.interview_end_at:
            details.append("Fin prévue à " + application.interview_end_at.strftime("%H:%M") + " (heure de Dakar)")
        if application.interview_mode:
            details.append("Format : " + {"in_person": "en présentiel", "online": "en ligne", "hybrid": "mixte"}.get(application.interview_mode, "entretien"))
        if application.interview_location:
            details.append("Lieu : " + application.interview_location.strip())
        if application.interview_link:
            details.append("Lien de l’entretien : " + application.interview_link.strip())
        if not details:
            details.append("L’équipe vous communiquera prochainement la date et le lieu de l’entretien.")
    if getattr(application, "interview_meeting_id", None):
        details = [part for part in details if not part.startswith("Lien de l’entretien")]
        details.append("EnactMeet : ouvre le suivi de ta candidature et choisis Rejoindre mon entretien. Aucun compte membre n’est nécessaire.")
    from app.services.recruitment_mail_copy import application_mail
    title, body = application_mail("interview_updated" if state == "interview_scheduled" and interview_updated else state,
                                   application, details="\n".join(details))
    fingerprint = hashlib.sha256(json.dumps({
        "status":state,
        "revision":application.updated_at.isoformat() if application.updated_at else None,
        "interview_at":application.interview_at.isoformat() if state=="interview_scheduled" and application.interview_at else None,
        "interview_location":application.interview_location if state=="interview_scheduled" else None,
        "interview_link":application.interview_link if state=="interview_scheduled" else None,
    },sort_keys=True,ensure_ascii=False).encode()).hexdigest()[:32]
    return enqueue_email_delivery(
        db,recipient_email=application.email,subject=title,text_body=body,
        dedupe_key=f"candidate-update:{application.id}:{fingerprint}",
    )
