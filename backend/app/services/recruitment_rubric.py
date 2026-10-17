"""Versioned human assessment. No candidate identity, prose length or academic proxy enters scoring."""
from copy import deepcopy
import json
from pathlib import Path

RUBRIC = json.loads(Path(__file__).with_suffix(".json").read_text(encoding="utf-8"))
VERSION = RUBRIC["version"]
CRITERION_IDS = {criterion["id"] for criterion in RUBRIC["criteria"]}

def rubric_payload(version=None):
    if version not in (None, VERSION):
        raise ValueError("Cette grille d’évaluation n’est pas disponible.")
    return deepcopy(RUBRIC)

def assess_ratings(ratings, version=VERSION):
    if version != VERSION:
        raise ValueError("La version de la grille d’évaluation ne correspond pas.")
    if not isinstance(ratings, list) or len(ratings) != len(CRITERION_IDS):
        raise ValueError("Évalue les cinq critères avant d’enregistrer.")
    ids = [row.get("criterion_id") for row in ratings if isinstance(row, dict)]
    if len(ids) != len(ratings) or any(not isinstance(value, str) for value in ids) or set(ids) != CRITERION_IDS or len(set(ids)) != len(ids):
        raise ValueError("Les critères de l’évaluation ne correspondent pas à la grille.")
    normalized = []
    total = 0
    for criterion in RUBRIC["criteria"]:
        row = next(row for row in ratings if row["criterion_id"] == criterion["id"])
        score = row.get("rating")
        evidence = row.get("evidence")
        if type(score) is not int or not 0 <= score <= RUBRIC["scale_max"]:
            raise ValueError("Chaque note doit être un entier de 0 à 4.")
        if not isinstance(evidence, str) or not evidence.strip() or len(evidence) > 2000:
            raise ValueError("Précise un exemple ou une observation pour chaque critère.")
        normalized.append({"criterion_id":criterion["id"], "rating":score, "evidence":evidence.strip()})
        total += score
    return {"rubric_version":version, "ratings":normalized}, float(total)

def structured_summary(reviews, version=VERSION):
    values = []
    for review in reviews:
        snapshot = getattr(review, "criteria_assessment", None)
        if not isinstance(snapshot, dict) or snapshot.get("rubric_version") != version:
            continue
        try:
            _, score = assess_ratings(snapshot.get("ratings"), version)
        except ValueError:
            continue
        values.append(score * 5)
    if not values:
        return {"screening_score":None, "screening_review_count":0, "screening_spread":None}
    return {"screening_score":round(sum(values)/len(values),2),
            "screening_review_count":len(values),
            "screening_spread":round(max(values)-min(values),2)}
