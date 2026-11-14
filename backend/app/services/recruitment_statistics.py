"""Campaign totals shared with members, without disclosing individual dossiers."""
from collections import Counter
import re
import unicodedata

from sqlalchemy import func

from app.models.recruitment import Application
from app.services.academic_profile import ACADEMIC_LEVELS
from app.services.recruitment_application_metadata import DISCOVERY_CHANNELS


DEPARTMENTS = {
    'GCBA': 'Génie chimique et biologie appliquée',
    'GC': 'Génie civil', 'GE': 'Génie électrique',
    'GI': 'Génie informatique', 'GM': 'Génie mécanique', 'GESTION': 'Gestion',
}
UNKNOWN = 'Non renseigné'


def plain(value):
    return ''.join(c for c in unicodedata.normalize('NFKD', value or '').casefold()
                   if not unicodedata.combining(c)).strip()


def department_label(value):
    key = re.sub(r'[^a-z]', '', plain(value))
    aliases = {'gcba': 'GCBA', 'geniechimiqueetbiologieappliquee': 'GCBA',
               'gc': 'GC', 'geniecivil': 'GC', 'ge': 'GE', 'genieelectrique': 'GE',
               'gi': 'GI', 'genieinformatique': 'GI', 'gm': 'GM', 'geniemecanique': 'GM',
               'gestion': 'GESTION'}
    code = aliases.get(key)
    return DEPARTMENTS[code] if code else ('Autre département' if key else UNKNOWN)


LEVELS = {plain(level): level for values in ACADEMIC_LEVELS.values() for level in values}
YEAR_BY_LEVEL = {
    'DUT1': 1, 'Licence1': 1, 'DST1': 1,
    'DUT2': 2, 'Licence2': 2,
    'Licence3': 3, 'DIC1': 3, 'DIT1': 3, 'DESCAF1': 3,
    'Master1': 4, 'DIC2': 4, 'DIT2': 4, 'DESCAF2': 4,
    'Master2': 5, 'DIC3': 5, 'DESCAF3': 5,
}


def level_label(value):
    key = re.sub(r'\s+', '', plain(value)).replace('descfaf', 'descaf')
    return LEVELS.get(key, 'Autre niveau' if key else UNKNOWN)


def year_label(value):
    level = level_label(value)
    if level == UNKNOWN:
        return UNKNOWN
    year = YEAR_BY_LEVEL.get(level)
    if year is None:
        return 'Année à préciser'
    return '1re année' if year == 1 else f'{year}e année'


def promotion_label(value):
    match = re.fullmatch(r'(\d{4})\s*[-/]\s*(\d{4})', (value or '').strip())
    if match and int(match[2]) == int(match[1]) + 1:
        return f'{match[1]}-{match[2]}'
    return 'Autre promotion' if (value or '').strip() else UNKNOWN


def discovery_label(value):
    key = plain(value)
    if not key:
        return UNKNOWN
    for code, label in DISCOVERY_CHANNELS.items():
        if key == code or key == plain(label):
            return label
    if key.partition(':')[0].strip() == 'autre':
        return DISCOVERY_CHANNELS['other']
    if any(word in key for word in ('reseau', 'instagram', 'facebook', 'tiktok', 'whatsapp', 'linkedin')):
        return DISCOVERY_CHANNELS['social_media']
    if any(word in key for word in ('membre', 'enacteur', 'enactrice')):
        return DISCOVERY_CHANNELS['member']
    if any(word in key for word in ('enseignant', 'professeur', 'cours')):
        return DISCOVERY_CHANNELS['teaching']
    if any(word in key for word in ('activite', 'evenement', 'conference', 'stand')):
        return DISCOVERY_CHANNELS['activities']
    if any(word in key for word in ('affiche', 'imprime', 'flyer')):
        return DISCOVERY_CHANNELS['poster']
    if any(word in key for word in ('site', 'google', 'recherche en ligne')):
        return DISCOVERY_CHANNELS['web']
    return DISCOVERY_CHANNELS['other']


def campaign_statistics(db, campaign_id, *, campaign=None):
    fields = (Application.department, Application.study_level, Application.class_name,
              Application.known_enactus_from)
    rows = db.query(*fields, func.count(Application.id)).filter(
        Application.campaign_id == campaign_id).group_by(*fields).all() if campaign_id else []
    counts = {key: Counter() for key in ('department', 'study_level', 'study_year', 'promotion', 'discovery_channel')}
    for label in DEPARTMENTS.values():
        counts['department'][label] = 0
    for label in DISCOVERY_CHANNELS.values():
        counts['discovery_channel'][label] = 0
    total = 0
    for department, level, promotion, discovery, count in rows:
        total += count
        for key, label in (
            ('department', department_label(department)), ('study_level', level_label(level)),
            ('study_year', year_label(level)), ('promotion', promotion_label(promotion)),
            ('discovery_channel', discovery_label(discovery)),
        ):
            counts[key][label] += count
    result = {'total': total, 'breakdowns': {
        key: [{'label': label, 'count': count,
               'percentage': round(count * 100 / total, 1) if total else 0}
              for label, count in sorted(counter.items(), key=lambda item: (
                  0 if key == 'study_year' else -item[1], item[0]
              ))]
        for key, counter in counts.items()
    }}

    if campaign is not None:
        applications = db.query(Application).filter(
            Application.campaign_id == campaign.id,
        ).all()
        reviews = (
            db.query(ApplicationReview)
            .join(Application, Application.id == ApplicationReview.application_id)
            .filter(Application.campaign_id == campaign.id)
            .all()
        )
        minimum = getattr(campaign, "screening_min_reviews", None) or MINIMUM_SCORED_REVIEWS
        result["evaluation"] = internal_campaign_statistics(
            applications, reviews, minimum=minimum
        )
        result["evaluation"]["target_headcount"] = getattr(campaign, "target_headcount", None)
    return result

from collections import defaultdict
from math import ceil, floor
from statistics import mean, median, pstdev
from app.models.recruitment import ApplicationReview

MINIMUM_SCORED_REVIEWS = 3
HIGH_DISAGREEMENT_POINTS = 5

def _number(value, digits=2):
    return round(float(value), digits) if value is not None else None


def _percent(value, total):
    return round(value * 100 / total, 1) if total else 0.0


def _percentile(values, fraction):
    if not values:
        return None
    sorted_values = sorted(values)
    position = (len(sorted_values) - 1) * fraction
    lower, upper = floor(position), ceil(position)
    return _number(sorted_values[lower] + (sorted_values[upper] - sorted_values[lower]) * (position - lower))


def _label(value):
    return str(value).strip() if value is not None and str(value).strip() else "Non renseigné"




def _score_band(score):
    if score < 5:
        return "Moins de 5"
    if score < 8:
        return "De 5 à moins de 8"
    if score < 10:
        return "De 8 à moins de 10"
    if score < 12:
        return "De 10 à moins de 12"
    if score < 14:
        return "De 12 à moins de 14"
    if score < 16:
        return "De 14 à moins de 16"
    if score < 18:
        return "De 16 à moins de 18"
    return "De 18 à 20"




def internal_campaign_statistics(applications, reviews, minimum=MINIMUM_SCORED_REVIEWS):
    """Aggregate the same rubric, statuses and recorded scores for every campaign.

    One recorded review per reviewer/application is enforced by the database.
    Missing score is not treated as zero. This function never returns row IDs.
    """
    grouped = defaultdict(list)
    reviewer_load = Counter()
    recommendations = Counter()
    daily_reviews = Counter()
    latest_review = None
    scores = []
    for r in reviews:
        grouped[str(r.application_id)].append(r)
        reviewer_load[str(r.reviewer_id)] += 1
        if r.score is not None:
            scores.append(float(r.score))
            recommendations[_label(r.recommendation)] += 1
        created = getattr(r, "created_at", None)
        if created:
            daily_reviews[created.date().isoformat()] += 1
        edited = getattr(r, "updated_at", None) or created
        if edited and (latest_review is None or edited > latest_review):
            latest_review = edited

    counts = Counter()
    candidates = []
    candidate_means = []
    complete_scores = []
    spreads = []
    majority = Counter()
    union_alerts = 0
    opposite = 0
    non_unanimous = 0
    high_spreads = 0
    spread_ge = {3: 0, 4: 0, 5: 0, 6: 0}
    statuses = Counter()
    daily_applications = Counter()
    missing = Counter()
    dept_groups = defaultdict(list)
    level_groups = defaultdict(list)
    gender_groups = defaultdict(list)

    for a in applications:
        statuses[_label(a.status)] += 1
        if a.created_at:
            daily_applications[a.created_at.date().isoformat()] += 1
        for field in ("phone", "motivation", "availability", "department", "study_level", "known_enactus_from", "questionnaire_answers"):
            value = getattr(a, field, None)
            if value is None or value == "" or value == [] or value == {} or (isinstance(value, str) and not value.strip()):
                missing[field] += 1

        rs = grouped[str(a.id)]
        graded = [r for r in rs if r.score is not None]
        individual = [float(r.score) for r in graded]
        count = len(individual)
        counts[count] += 1
        average = mean(individual) if individual else None
        spread = max(individual) - min(individual) if count >= 2 else None
        is_ready = count >= minimum
        has_high_spread = spread is not None and spread >= HIGH_DISAGREEMENT_POINTS
        choices = Counter(_label(r.recommendation) for r in graded)
        is_opposite = "favorable" in choices and "defavorable" in choices
        if spread is not None:
            spreads.append(spread)
            for threshold in spread_ge:
                if spread >= threshold:
                    spread_ge[threshold] += 1
        if has_high_spread:
            high_spreads += 1
        if is_opposite:
            opposite += 1
        if is_opposite or has_high_spread:
            union_alerts += 1
        if len(choices) >= 2:
            non_unanimous += 1
        if choices:
            most = max(choices.values())
            leading = [choice for choice, number in choices.items() if number == most]
            majority[leading[0] if len(leading) == 1 else "egalite"] += 1

        if average is not None:
            candidate_means.append(average)
            if is_ready:
                complete_scores.append(average)
        item = {
            "average": average, "scores": count, "ready": is_ready,
            "high_disagreement": has_high_spread, "opposite": is_opposite,
        }
        candidates.append(item)
        dept_groups[department_label(a.department)].append(item)
        level_groups[level_label(a.study_level)].append(item)
        gender_groups[_label(a.gender)].append(item)

    total = len(applications)
    completed = sum(row["ready"] for row in candidates)
    band_names = ["Moins de 5", "De 5 à moins de 8", "De 8 à moins de 10", "De 10 à moins de 12", "De 12 à moins de 14", "De 14 à moins de 16", "De 16 à moins de 18", "De 18 à 20"]
    bands = Counter(_score_band(score) for score in complete_scores)

    def group_stats(groups):
        result = []
        for label, items in sorted(groups.items(), key=lambda item: (-len(item[1]), item[0])):
            graded_means = [v["average"] for v in items if v["average"] is not None]
            result.append({
                "label": label, "count": len(items), "percentage": _percent(len(items), total),
                "average": _number(mean(graded_means)) if graded_means else None,
                "completed": sum(v["ready"] for v in items),
                "at_least_14": sum(v["average"] is not None and v["average"] >= 14 for v in items),
                "high_disagreement": sum(v["high_disagreement"] for v in items),
                "missing_reviews": sum(max(0, minimum - v["scores"]) for v in items),
            })
        return result

    def distribution_counts():
        return [
            {"label": str(i), "count": counts[i]} for i in range(minimum + 2)
        ] + [
            {"label": f"{minimum + 2}+", "count": sum(v for k, v in counts.items() if k >= minimum + 2)}
        ] if minimum >= 1 else []

    days = sorted(set(daily_applications) | set(daily_reviews))
    return {
        "minimum_reviews": minimum,
        "overview": {
            "applications": total, "reviews": len(reviews), "scored_reviews": len(scores),
            "reviewers": len(reviewer_load), "completed": completed,
            "completed_percentage": _percent(completed, total),
            "missing_reviews": sum(max(0, minimum - c["scores"]) for c in candidates),
            "beyond_minimum": sum(max(0, c["scores"] - minimum) for c in candidates),
            "average_reviews": _number(len(scores) / total) if total else None,
            "latest_review": latest_review.isoformat() if latest_review else None,
            "distribution": distribution_counts(),
        },
        "scoring": {
            "review_average": _number(mean(scores)) if scores else None,
            "candidate_average": _number(mean(candidate_means)) if candidate_means else None,
            "median": _number(median(candidate_means)) if candidate_means else None,
            "lowest": _number(min(candidate_means)) if candidate_means else None,
            "highest": _number(max(candidate_means)) if candidate_means else None,
            "lower_quarter": _percentile(candidate_means, .25),
            "upper_quarter": _percentile(candidate_means, .75),
            "top_tenth_threshold": _percentile(candidate_means, .90),
            "std_dev": _number(pstdev(candidate_means)) if candidate_means else None,
            "at_least_14": sum(v >= 14 for v in complete_scores),
            "at_least_16": sum(v >= 16 for v in complete_scores),
            "below_10": sum(v < 10 for v in complete_scores),
            "score_bands": [{"label": label, "count": bands[label]} for label in band_names],
        },
        "disagreements": {
            "with_two_or_more": len(spreads),
            "spread_ge_3": spread_ge[3], "spread_ge_4": spread_ge[4],
            "spread_ge_5": spread_ge[5], "spread_ge_6": spread_ge[6],
            "opposite_opinions": opposite, "sensitive_total": union_alerts,
            "mixed_recommendations": non_unanimous,
            "max_spread": _number(max(spreads)) if spreads else None,
            "mean_spread": _number(mean(spreads)) if spreads else None,
        },
        "recommendations": {
            "votes": {key: recommendations[key] for key in ("favorable", "reserve", "defavorable")},
            "majority": {key: majority[key] for key in ("favorable", "reserve", "defavorable", "egalite")},
        },
        "groups": {
            "department": group_stats(dept_groups),
            "study_level": group_stats(level_groups),
            "gender": group_stats(gender_groups),
        },
        "statuses": dict(sorted(statuses.items())),
        "missing_fields": dict(missing),
        "daily": [
            {"date": day, "applications": daily_applications[day], "reviews": daily_reviews[day]}
            for day in days
        ],
        "reviewer_workload": {
            "highest": max(reviewer_load.values()) if reviewer_load else 0,
            "lowest": min(reviewer_load.values()) if reviewer_load else 0,
            "average": _number(mean(reviewer_load.values())) if reviewer_load else None,
            "top_three_percentage": _percent(sum(sorted(reviewer_load.values(), reverse=True)[:3]), len(reviews)),
        },
        "interviews_scheduled": sum(a.interview_at is not None for a in applications),
        "converted_users": sum(a.converted_user_id is not None for a in applications),
        "target_headcount": None,  # Filled from the selected campaign by the route.
    }
