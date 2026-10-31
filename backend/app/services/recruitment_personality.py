"""Versioned self-report prompts, separate from human Enactus observations.

IPIP English items and keys are public domain. French wording below is our
working translation, NOT the copyrighted published French validation.
No norms, diagnostic categories, aggregate fit score or admission recommendation.
"""
from copy import deepcopy

VERSION = "enactspace-ipip20-fr-pilot-2026-1"
NOTICE = ("Ce questionnaire aide à préparer notre échange sur ta façon de travailler. "
          "Il n’y a pas de profil idéal ni de note d’admission. Les réponses sont déclaratives ; "
          "cette traduction de travail n’a pas été validée auprès des étudiants de l’ESP. "
          "Tu peux préférer en parler pendant l’entretien. Les réponses terminées sont accessibles "
          "aux responsables du recrutement et au jury habilité de ta campagne.")

# Original Mini-IPIP order, polarity and four items per dimension.
ITEMS = [
    ("p01", "Je mets de l’animation dans les rencontres sociales.", "extraversion", False),
    ("p02", "Je suis sensible aux sentiments des autres.", "cooperation", False),
    ("p03", "Je m’occupe de mes tâches sans attendre.", "organisation", False),
    ("p04", "Mon humeur change souvent.", "reactivite", False),
    ("p05", "J’ai une imagination vive.", "ouverture", False),
    ("p06", "Je parle peu.", "extraversion", True),
    ("p07", "Je m’intéresse peu aux autres.", "cooperation", True),
    ("p08", "J’oublie de remettre les choses à leur place.", "organisation", True),
    ("p09", "Je suis détendu la plupart du temps.", "reactivite", True),
    ("p10", "J’ai du mal à comprendre les idées abstraites.", "ouverture", True),
    ("p11", "Je parle à beaucoup de personnes différentes lors des rencontres.", "extraversion", False),
    ("p12", "Je ressens les émotions des autres.", "cooperation", False),
    ("p13", "J’aime que les choses soient en ordre.", "organisation", False),
    ("p14", "Je me contrarie facilement.", "reactivite", False),
    ("p15", "Les idées abstraites m’intéressent peu.", "ouverture", True),
    ("p16", "Je reste en retrait.", "extraversion", True),
    ("p17", "Je m’intéresse peu aux problèmes des autres.", "cooperation", True),
    ("p18", "Je laisse mes affaires en désordre.", "organisation", True),
    ("p19", "Je me sens rarement abattu.", "reactivite", True),
    ("p20", "Je n’ai pas beaucoup d’imagination.", "ouverture", True),
]
DIMENSIONS = {
    "extraversion": ("Expression et échanges", "Comment préfères-tu contribuer : en petit groupe, en préparant les idées ou en prenant la parole ?"),
    "cooperation": ("Attention aux autres", "Raconte une situation où tu as écouté un besoin différent du tien."),
    "organisation": ("Organisation", "Comment t’organises-tu quand une mission et les cours se chevauchent ?"),
    "reactivite": ("Réactions aux imprévus", "Qu’est-ce qui t’aide à faire face à un contretemps et à demander du soutien ?"),
    "ouverture": ("Imagination et idées", "Raconte comment tu as essayé une idée nouvelle ou appris une méthode différente."),
}
SCENARIOS = [
    {"id": "needs", "title": "Écouter avant d’agir", "question": "Ton équipe a préparé une solution, mais les personnes concernées disent qu’elle ne répond pas à leur priorité. Que fais-tu d’abord, et pourquoi ?", "observe": "Écoute, vérification des besoins et coconstruction ; demander un exemple vécu."},
    {"id": "commitment", "title": "Cours et engagement", "question": "Un examen est avancé et tu ne pourras pas finir ta mission à temps. Comment préviens-tu l’équipe et que proposes-tu ?", "observe": "Anticipation, communication et engagement réaliste ; ne pas récompenser la disponibilité illimitée."},
    {"id": "learning", "title": "Tester et apprendre", "question": "Le premier prototype ne fonctionne pas avec le budget disponible. Quelle petite étape proposes-tu pour apprendre avant de dépenser davantage ?", "observe": "Hypothèse vérifiable, apprentissage et usage responsable des ressources."},
    {"id": "integrity", "title": "Un impact honnête", "question": "Avant une présentation, quelqu’un propose d’annoncer un nombre de bénéficiaires supérieur à ce que vous avez vérifié. Comment réagis-tu ?", "observe": "Honnêteté, distinction entre personnes touchées et impact démontré ; aucun score automatique."},
    {"id": "team", "title": "Faire une place à chacun", "question": "En réunion, deux personnes monopolisent la discussion et une autre n’ose pas participer. Que peux-tu faire ? Donne si possible un exemple réel.", "observe": "Coopération, inclusion, écoute et capacité à s’appuyer sur plusieurs façons de contribuer."},
]


def instrument():
    return {"version": VERSION, "title": "Mieux te connaître pour préparer l’entretien",
            "notice": NOTICE, "translation_status": "working_translation_not_locally_validated",
            "source": "https://ipip.ori.org/MiniIPIPKey.htm",
            "items": [{"id": key, "label": label, "dimension": dimension, "reverse": reverse}
                      for key, label, dimension, reverse in ITEMS],
            "scenarios": deepcopy(SCENARIOS),
            "scale": ["Ne me ressemble pas du tout", "Me ressemble peu", "Me ressemble un peu", "Me ressemble assez", "Me ressemble tout à fait"]}


def public_instrument(snapshot):
    result = deepcopy(snapshot)
    result["items"] = [{"id": row["id"], "label": row["label"]} for row in snapshot["items"]]
    result["scenarios"] = [{key: value for key, value in row.items() if key != "observe"} for row in snapshot["scenarios"]]
    return result


def validate_answers(snapshot, answers, scenarios, *, complete=False):
    item_ids = {row["id"] for row in snapshot["items"]}
    scenario_ids = {row["id"] for row in snapshot["scenarios"]}
    if set(answers) - item_ids or set(scenarios) - scenario_ids:
        raise ValueError("Une question n’appartient pas à ce questionnaire. Recharge-le.")
    if any(type(value) is not int or not 1 <= value <= 5 for value in answers.values()):
        raise ValueError("Choisis une réponse de 1 à 5 pour chaque affirmation.")
    if any(not isinstance(value, str) or len(value) > 2000 for value in scenarios.values()):
        raise ValueError("Chaque réponse doit contenir au plus 2 000 caractères.")
    if complete and (set(answers) != item_ids or any(not scenarios.get(key, "").strip() for key in scenario_ids)):
        raise ValueError("Réponds à toutes les affirmations et mises en situation avant de terminer.")


def score(snapshot, answers):
    grouped = {key: [] for key in DIMENSIONS}
    for item in snapshot["items"]:
        value = answers[item["id"]]
        grouped[item["dimension"]].append(6 - value if item["reverse"] else value)
    return {"version": snapshot["version"], "scale_min": 1, "scale_max": 5,
            "interpretation": "Moyennes déclaratives à discuter, sans seuil ni classement. Les deux extrémités décrivent des préférences, pas une valeur personnelle.",
            "dimensions": [{"id": key, "label": DIMENSIONS[key][0],
                            "mean": round(sum(values) / len(values), 2),
                            "discussion": DIMENSIONS[key][1]} for key, values in grouped.items()]}
