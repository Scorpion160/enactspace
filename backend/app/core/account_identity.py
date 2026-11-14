"""Shared account identifiers for every ORM creation path."""
import re
import unicodedata
from uuid import uuid4
from datetime import datetime, timezone

def generated_username(context):
    values = context.get_current_parameters()
    name = ".".join(str(values.get(key) or "") for key in ("first_name", "last_name"))
    ascii_name = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode()
    base = re.sub(r"[^a-z0-9]+", ".", ascii_name.lower()).strip(".")[:36].rstrip(".")
    return (base or "membre") + "." + uuid4().hex[:12]

def normalize_username(value):
    if value is None:
        return None
    value = value.strip().lower()
    if not value or len(value) > 50 or any(unicodedata.category(c).startswith("C") for c in value):
        raise ValueError("Le nom d'utilisateur doit contenir entre 1 et 50 caractères lisibles.")
    return value

def validate_join_year(value):
    if value is not None and not 1900 <= value <= datetime.now(timezone.utc).year:
        raise ValueError("Renseignez une année d'entrée valide, sans dépasser l'année actuelle.")
    return value
