"""Generate CI-only synthetic resources; never copy production business data."""
import json
import os
from pathlib import Path

MAIL_KINDS = (
    "submitted", "under_review", "screening_shortlisted",
    "screening_not_shortlisted", "interview_scheduled", "interview_updated",
    "questionnaire", "accepted", "rejected", "waiting_list",
    "cancelled", "activation", "activation_complete",
)
CRITERIA = ("mission", "community", "initiative", "teamwork", "commitment")


def main():
    if os.environ.get("APP_ENV") != "test":
        raise RuntimeError("APP_ENV=test is required for synthetic CI fixtures")
    directory = Path(__file__).resolve().parents[1] / "app" / "services"
    fixtures = {
        "project_presentations.json": [],
        "club_voices_2023.json": [],
        "recruitment_mail_copy.json": {
            kind: {
                "subject": f"[CI fictif] Notification {kind}",
                "body": "Bonjour {first_name}, message de test uniquement. "
                        "Code {code}. Identifiant {username}. {details}",
            }
            for kind in MAIL_KINDS
        },
        "recruitment_rubric.json": {
            "version": "enactus-esp-2026-v1",
            "scale_max": 4,
            "guidance": "Grille synthétique de test, jamais destinée aux jurés.",
            "criteria": [
                {
                    "id": name,
                    "label": f"Critère fictif {i}",
                    "description": "Test technique, sans contenu d'évaluation réel.",
                    "anchors": [f"Niveau fictif {n}" for n in range(5)],
                }
                for i, name in enumerate(CRITERIA, 1)
            ],
        },
    }
    for name, data in fixtures.items():
        path = directory / name
        if path.exists():
            raise RuntimeError(f"Refusing to overwrite existing resource: {name}")
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    manuscript = directory / "academy_lessons.md"
    if manuscript.exists():
        raise RuntimeError("Refusing to overwrite the existing Academy manuscript")
    manuscript.write_text(
        "# Premiers pas dans EnactSpace\n"
        "## Bienvenue dans l'environnement de test\n"
        "Contenu fictif réservé à la CI.\n",
        encoding="utf-8",
    )
    print("CREATED_FIVE_SYNTHETIC_TEST_RESOURCES")


if __name__ == "__main__":
    main()
