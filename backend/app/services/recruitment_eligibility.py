"""Eligibility rules for new recruitment submissions."""
import re
import unicodedata

TERMINAL_LEVELS = {"DIC3", "DESCAF3", "DESCFAF3", "MASTER2", "DIT2"}


def normalized_level(value):
    plain = "".join(
        char for char in unicodedata.normalize("NFKD", value or "")
        if not unicodedata.combining(char)
    )
    return re.sub(r"[\s_-]+", "", plain).upper()


def eligibility_error(study_level, other_clubs_count, *, require_count=True):
    if normalized_level(study_level) in TERMINAL_LEVELS:
        return "Les candidatures en DIC3, DESCAF3, Master2 et DIT2 ne sont pas éligibles."
    if other_clubs_count is None:
        return "Indique le nombre de clubs et structures étudiantes que tu as déjà rejoints." if require_count else None
    if type(other_clubs_count) is not int or not 0 <= other_clubs_count <= 100:
        return "Indique un nombre entier de clubs compris entre 0 et 100."
    if other_clubs_count >= 3:
        return "Les étudiants engagés dans trois clubs ou structures étudiantes ou plus ne sont pas éligibles."
    return None
