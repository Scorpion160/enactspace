from __future__ import annotations

from dataclasses import dataclass


ACADEMIC_LEVELS: dict[str, tuple[str, ...]] = {
    "DUT": ("DUT1", "DUT2"),
    "Licence": ("Licence1", "Licence2", "Licence3"),
    "Master": ("Master1", "Master2"),
    "DIC": ("DIC1", "DIC2", "DIC3"),
    "DESCAF": ("DESCAF1", "DESCAF2", "DESCAF3"),
    "DST": ("DST1", "DST2"),
    "DIT": ("DIT1", "DIT2"),
}

ENGINEERING_CURSUS = {"DUT", "Licence", "Master", "DIC", "DST", "DIT"}
ACADEMIC_DEPARTMENTS: dict[str, set[str]] = {
    "GCBA": set(ENGINEERING_CURSUS),
    "Génie Civil": set(ENGINEERING_CURSUS),
    "Génie Informatique": set(ENGINEERING_CURSUS),
    "Génie Électrique": set(ENGINEERING_CURSUS),
    "Génie Mécanique": set(ENGINEERING_CURSUS),
    "Gestion": {"DUT", "Licence", "Master", "DESCAF"},
}


@dataclass(frozen=True)
class AcademicProgression:
    suggested_next_level: str | None
    terminal: bool


def clean_academic_text(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


def validate_academic_path(department: str, cursus: str, level: str) -> None:
    if department not in ACADEMIC_DEPARTMENTS:
        raise ValueError("Département ESP invalide")
    if cursus not in ACADEMIC_DEPARTMENTS[department]:
        raise ValueError("Cursus incompatible avec le département ESP")
    if cursus not in ACADEMIC_LEVELS or level not in ACADEMIC_LEVELS[cursus]:
        raise ValueError("Niveau incompatible avec le cursus")


def progression_for(cursus: str | None, level: str | None) -> AcademicProgression:
    levels = ACADEMIC_LEVELS.get(cursus or "")
    if not levels or level not in levels:
        return AcademicProgression(None, False)
    index = levels.index(level)
    if index + 1 >= len(levels):
        return AcademicProgression(None, True)
    return AcademicProgression(levels[index + 1], False)
