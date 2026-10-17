"""Campaign-specific public questions and immutable answer labels for each submission."""
import hashlib
import json

DEFAULT_QUESTIONS = [
  {
    "id": "personality",
    "label": "Décris-toi : personnalité, caractère et manière d’être.",
    "hint": "Quelques qualités, un point à améliorer et ce qui te ressemble.",
    "section": "motivation",
    "required": False,
    "legacy_field": "leadership_profile"
  },
  {
    "id": "motivation",
    "label": "Qu’est-ce qui te motive à rejoindre Enactus ESP ?",
    "hint": "Qu’aimerais-tu apprendre et apporter pour agir avec les communautés ? Tu n’as pas besoin d’une expérience associative.",
    "section": "motivation",
    "required": True,
    "legacy_field": "motivation"
  },
  {
    "id": "other-clubs",
    "label": "Es-tu engagé dans une structure étudiante, bénévole ou entrepreneuriale ?",
    "hint": "La structure, ton rôle et ce que tu y fais ; sinon, indique-le simplement.",
    "section": "motivation",
    "required": False,
    "legacy_field": "other_clubs"
  },
  {
    "id": "priority",
    "label": "Comment organiserais-tu Enactus ESP avec tes études et tes autres engagements ?",
    "hint": "Donne une organisation réaliste et explique comment tu préviendrais l’équipe en cas d’empêchement.",
    "section": "availability",
    "required": False
  },
  {
    "id": "social-problem",
    "label": "Quel problème social te tient particulièrement à cœur ?",
    "hint": "Décris une situation concrète et pourquoi elle te touche.",
    "section": "motivation",
    "required": True
  },
  {
    "id": "solution",
    "label": "Quelle solution proposerais-tu face à ce problème ?",
    "hint": "Une première piste suffit : elle pourra évoluer avec le terrain.",
    "section": "motivation",
    "required": True,
    "legacy_field": "project_ideas"
  },
  {
    "id": "community",
    "label": "Avec qui construirais-tu cette solution et comment comprendrais-tu leurs besoins ?",
    "hint": "Précise les personnes concernées et une première manière de les écouter avant de choisir une solution.",
    "section": "motivation",
    "required": True
  },
  {
    "id": "teamwork-example",
    "label": "Une tâche d’équipe prend du retard et un désaccord apparaît : comment réagirais-tu ?",
    "hint": "Explique comment tu écouterais les autres, clarifierais les responsabilités et chercherais une prochaine étape ensemble.",
    "section": "motivation",
    "required": True
  },
  {
    "id": "learning-example",
    "label": "Raconte une situation où tu as essayé, appris ou amélioré quelque chose.",
    "hint": "Un exemple des études, de la famille, d’un petit projet ou du quotidien suffit. Qu’as-tu fait et que changerais-tu aujourd’hui ?",
    "section": "motivation",
    "required": True
  },
  {
    "id": "travel",
    "label": "Pourrais-tu participer à des missions de plusieurs jours à l’intérieur du pays ?",
    "hint": "Oui, non ou sous conditions. Tu peux aussi contribuer à la préparation ou au suivi des missions.",
    "section": "availability",
    "required": False
  },
  {
    "id": "availability",
    "label": "Quelles sont tes disponibilités pour l’équipe ?",
    "hint": "Indique des créneaux réalistes et tes périodes d’examens ou d’indisponibilité. Promettre plus d’heures ne donne pas automatiquement plus de points.",
    "section": "availability",
    "required": True,
    "legacy_field": "availability"
  },
  {
    "id": "last-word",
    "label": "Un dernier mot ?",
    "hint": "Un message, une précision ou quelque chose que tu aimerais partager.",
    "section": "availability",
    "required": False,
    "legacy_field": "public_comment"
  }
]
LEGACY_FIELDS = {'motivation','known_enactus_from','enactus_knowledge','other_clubs',
                 'contribution','project_ideas','leadership_profile','associative_experience',
                 'availability','public_comment'}


def effective_questions(value):
    # None is a legacy campaign; an explicit empty list is a deliberate questionnaire.
    return [dict(q) for q in (DEFAULT_QUESTIONS if value is None else value)]


def questionnaire_version(value):
    return hashlib.sha256(json.dumps(effective_questions(value), sort_keys=True,
                         ensure_ascii=False).encode()).hexdigest()[:16]
