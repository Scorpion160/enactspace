"""Candidate-facing messages; internal reviews never enter the email body."""
from datetime import timezone
import hashlib
import json

from app.services.email_delivery_service import enqueue_email_delivery
from app.services.email_templates import APP_URL

MESSAGES = {
    "under_review": ("Votre candidature est en cours d’étude",
                    "L’équipe recrutement étudie votre dossier. Vous pouvez suivre son avancement dans EnactSpace."),
    "interview_scheduled": ("Votre entretien avec Enactus ESP",
                           "Nous vous invitons à un entretien pour échanger sur votre parcours, vos envies et votre engagement."),
    "accepted": ("Votre candidature à Enactus ESP est retenue",
                 "Félicitations ! L’équipe a retenu votre candidature. Nous vous accompagnerons dans les prochaines étapes de votre intégration."),
    "rejected": ("La réponse à votre candidature à Enactus ESP",
                 "Merci pour le temps et l’énergie consacrés à votre candidature. L’équipe ne peut pas vous proposer de place pour cette campagne. Nous vous souhaitons une belle continuation dans vos engagements."),
    "waiting_list": ("Votre candidature est en liste d’attente",
                     "Votre candidature est conservée en liste d’attente. L’équipe vous recontactera si une place se libère."),
    "cancelled": ("Le suivi de votre candidature à Enactus ESP",
                  "Votre candidature est clôturée pour cette campagne. Merci pour votre intérêt et votre engagement."),
}


def enqueue_candidate_update(db, application):
    state = {"received":"submitted", "preselected":"under_review",
             "interview":"interview_scheduled"}.get(application.status, application.status)
    content = MESSAGES.get(state)
    if content is None:
        return None
    title, message = content
    details = []
    if state == "interview_scheduled":
        when = application.interview_at
        if when is not None:
            if when.tzinfo is None:
                when = when.replace(tzinfo=timezone.utc)
            when = when.astimezone(timezone.utc)
            details.append("Date : " + when.strftime("%d/%m/%Y à %H:%M UTC"))
        if application.interview_location:
            details.append("Lieu : " + application.interview_location.strip())
        if application.interview_link:
            details.append("Lien de l’entretien : " + application.interview_link.strip())
        if not details:
            details.append("L’équipe vous communiquera prochainement la date et le lieu de l’entretien.")
    body = "\n\n".join([
        f"Bonjour {application.first_name},",
        message,
        "\n".join(details),
        ("Code de suivi : " + application.tracking_code) if application.tracking_code else "",
        "Suivre ma candidature : " + APP_URL + "/application-tracking",
        "L’équipe Enactus ESP",
    ])
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
