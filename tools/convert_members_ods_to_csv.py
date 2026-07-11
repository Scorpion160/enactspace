import argparse
import csv
import re
import unicodedata
import zipfile
from pathlib import Path
from xml.etree import ElementTree


NS = {
    "office": "urn:oasis:names:tc:opendocument:xmlns:office:1.0",
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
}
TABLE_REPEAT = f"{{{NS['table']}}}number-rows-repeated"
CELL_REPEAT = f"{{{NS['table']}}}number-columns-repeated"

OUTPUT_COLUMNS = [
    "prenom",
    "nom",
    "email",
    "telephone",
    "genre",
    "niveau_etude",
    "role",
    "statut",
    "pole_coeur",
    "poles_support",
    "projet",
    "responsabilite",
    "date_adhesion",
]


def normalize_header(value: str) -> str:
    without_accents = "".join(
        char
        for char in unicodedata.normalize("NFKD", value.strip().lower())
        if not unicodedata.combining(char)
    )
    return re.sub(r"[^a-z0-9]+", "_", without_accents).strip("_")


def cell_text(cell: ElementTree.Element) -> str:
    parts = []
    for paragraph in cell.findall(".//text:p", NS):
        parts.append("".join(paragraph.itertext()))
    return " ".join(part.strip() for part in parts if part.strip()).strip()


def read_first_sheet(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        content = archive.read("content.xml")

    root = ElementTree.fromstring(content)
    table = root.find(".//table:table", NS)
    if table is None:
        return []

    rows = []
    for row in table.findall("table:table-row", NS):
        repeat_rows = min(int(row.attrib.get(TABLE_REPEAT, "1")), 200)
        values = []
        for cell in list(row):
            if not cell.tag.endswith("table-cell"):
                continue
            repeat_columns = min(int(cell.attrib.get(CELL_REPEAT, "1")), 50)
            values.extend([cell_text(cell)] * repeat_columns)
        if any(value.strip() for value in values):
            for _ in range(repeat_rows):
                rows.append(values)
    return rows


def yes(value: str) -> bool:
    return normalize_header(value) in {"oui", "yes", "x", "1", "true", "vrai"}


def normalize_gender(value: str) -> str:
    normalized = normalize_header(value)
    if normalized == "m":
        return "masculin"
    if normalized == "f":
        return "feminin"
    return normalized


def normalize_status(value: str) -> str:
    normalized = normalize_header(value)
    if not normalized:
        return "active"
    if normalized == "actif":
        return "active"
    if normalized == "inactif":
        return "inactive"
    return normalized


def role_from_responsibility(value: str) -> str:
    normalized = normalize_header(value)
    roles = []
    if "team_leader" in normalized:
        roles.append("team_leader")
    if "chef" in normalized and "pole" in normalized:
        roles.append("chef_pole")
    if "adjoint" in normalized and "pole" in normalized:
        roles.append("adjoint_chef_pole")
    if "chef" in normalized and "projet" in normalized:
        roles.append("chef_projet")
    if "adjoint" in normalized and "projet" in normalized:
        roles.append("adjoint_chef_projet")
    if normalized in {"sg", "secretaire_general", "secretaire_generale"}:
        roles.append("secretaire_generale")
    if "financier" in normalized or "finance" in normalized:
        roles.append("financier")
    roles.append("enacteur")
    return ";".join(dict.fromkeys(roles))


def convert_rows(rows: list[list[str]]) -> list[dict[str, str]]:
    if not rows:
        return []

    header_index = None
    headers = []
    for index, row in enumerate(rows):
        normalized = [normalize_header(value) for value in row]
        header_set = set(normalized)
        if "nom" in header_set and (
            "prenoms" in header_set or "prenom" in header_set
        ) and ("telephone" in header_set or "email" in header_set):
            header_index = index
            headers = normalized
            break

    if header_index is None:
        raise ValueError("Ligne d'en-tetes introuvable dans le fichier ODS.")

    output = []
    for row in rows[header_index + 1 :]:
        data = {
            headers[index]: value.strip()
            for index, value in enumerate(row[: len(headers)])
            if index < len(headers)
        }
        if not any(
            data.get(key, "")
            for key in ("nom", "prenoms", "email", "telephone", "pole_coeur")
        ):
            continue
        supports = []
        if yes(data.get("com", "")):
            supports.append("Communication")
        if yes(data.get("orga", "")):
            supports.append("Organisation")
        if yes(data.get("veille", "")):
            supports.append("Veille")

        output.append(
            {
                "prenom": data.get("prenoms", ""),
                "nom": data.get("nom", ""),
                "email": data.get("email", ""),
                "telephone": data.get("telephone", ""),
                "genre": normalize_gender(data.get("sexe", "")),
                "niveau_etude": data.get("classse", "") or data.get("classe", ""),
                "role": role_from_responsibility(
                    data.get("fonction_responsabilite", "")
                ),
                "statut": normalize_status(data.get("statut", "")),
                "pole_coeur": data.get("pole_coeur", ""),
                "poles_support": ";".join(supports),
                "projet": data.get("projet_principal", ""),
                "responsabilite": data.get("fonction_responsabilite", ""),
                "date_adhesion": "",
            }
        )
    return output


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Convert members ODS to import CSV.")
    parser.add_argument("--input", required=True, help="ODS file path.")
    parser.add_argument("--output", required=True, help="CSV output path.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)
    converted = convert_rows(read_first_sheet(input_path))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=OUTPUT_COLUMNS)
        writer.writeheader()
        writer.writerows(converted)
    print(f"{len(converted)} ligne(s) convertie(s): {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
