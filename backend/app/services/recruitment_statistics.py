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


def level_label(value):
    key = re.sub(r'\s+', '', plain(value)).replace('descfaf', 'descaf')
    return LEVELS.get(key, 'Autre niveau' if key else UNKNOWN)


def year_label(value):
    match = re.search(r'([1-5])$', level_label(value))
    if not match:
        return UNKNOWN
    year = int(match[1])
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


def campaign_statistics(db, campaign_id):
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
    return {'total': total, 'breakdowns': {
        key: [{'label': label, 'count': count,
               'percentage': round(count * 100 / total, 1) if total else 0}
              for label, count in sorted(counter.items(), key=lambda item: (-item[1], item[0]))]
        for key, counter in counts.items()
    }}
