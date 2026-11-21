"""Shared editorial presentations; no operational records or totals are mutated."""
from copy import deepcopy
import json
from pathlib import Path
import unicodedata


def normalize_name(value):
    text = unicodedata.normalize("NFKD", str(value or "")).casefold()
    return "".join(c for c in text if c.isalnum() and not unicodedata.combining(c))


CATALOG = json.loads(Path(__file__).with_suffix(".json").read_text(encoding="utf-8"))
_BY_NAME = {normalize_name(alias): item for item in CATALOG
            for alias in [item["id"], item["name"], *item["aliases"]]}


def get_project_presentation(name):
    item = _BY_NAME.get(normalize_name(name))
    return deepcopy(item) if item else None


def enrich_project_archive(row, *, replace=False):
    presentation = get_project_presentation(row.get("name"))
    if presentation is None:
        return row
    if replace:
        for field in ("description", "problem", "solution", "impact_summary", "image_asset"):
            row[field] = presentation[field]
        row["story_sections"] = deepcopy(presentation["sections"])
    row["presentation"] = presentation
    row["reference_documents"] = deepcopy(presentation["documents"])
    return row


def enrich_project_archives(projects):
    for row in projects:
        enrich_project_archive(row, replace=True)
