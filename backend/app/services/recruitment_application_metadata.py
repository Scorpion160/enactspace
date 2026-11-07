"""Canonical metadata for new applications; historical free text stays readable."""
import re

DISCOVERY_CHANNELS = {
    'social_media': 'Réseaux sociaux',
    'activities': 'Activités ou événements d’Enactus ESP',
    'member': 'Un membre d’Enactus ESP',
    'teaching': 'Un enseignant ou un cours',
    'poster': 'Une affiche ou un support imprimé',
    'web': 'Un site web ou une recherche en ligne',
    'other': 'Autre',
}


def academic_year(value):
    value = value.strip()
    match = re.fullmatch(r'(\d{4})-(\d{4})', value)
    if not match:
        raise ValueError('La promotion doit être au format 2025-2026.')
    start, end = map(int, match.groups())
    if not 1900 <= start <= 2199 or end != start + 1:
        raise ValueError('La promotion doit contenir deux années consécutives.')
    return value


def discovery_answer(channel, other=None):
    if channel not in DISCOVERY_CHANNELS:
        raise ValueError('Canal de découverte inconnu.')
    if channel == 'other':
        detail = (other or '').strip()
        if not detail or len(detail) > 200:
            raise ValueError('Précise cet autre moyen en 200 caractères maximum.')
        return 'Autre : ' + detail
    if other and other.strip():
        raise ValueError('La précision est réservée au choix Autre.')
    return DISCOVERY_CHANNELS[channel]
