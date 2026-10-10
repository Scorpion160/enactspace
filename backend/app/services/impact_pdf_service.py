"""Generate the official EnactSpace Impact summary PDF."""

from __future__ import annotations

from datetime import date, datetime
from pathlib import Path
import shutil
import subprocess
import tempfile
from typing import Any


class ImpactPdfGenerationError(RuntimeError):
    """Raised when the Impact report cannot be rendered safely."""


_LATEX_REPLACEMENTS = {
    "\\": r"\textbackslash{}",
    "&": r"\&",
    "%": r"\%",
    "$": r"\$",
    "#": r"\#",
    "_": r"\_",
    "{": r"\{",
    "}": r"\}",
    "~": r"\textasciitilde{}",
    "^": r"\textasciicircum{}",
}


def _escape(value: Any) -> str:
    if value is None or value == "":
        return "Non renseigne"
    if isinstance(value, (datetime, date)):
        value = value.isoformat()
    text = str(value).replace("\r\n", "\n").replace("\r", "\n")
    escaped = "".join(_LATEX_REPLACEMENTS.get(char, char) for char in text)
    return escaped.replace("\n", r"\\ ")


def _number(value: Any) -> str:
    if value is None:
        return "Non renseigne"
    if isinstance(value, float):
        value = f"{value:,.2f}".rstrip("0").rstrip(".")
    elif isinstance(value, int):
        value = f"{value:,}"
    return _escape(str(value).replace(",", " "))


def _historical_number(value: Any, *, minimum: bool = False) -> str:
    rendered = _number(value)
    if value is None:
        return rendered
    return f"Plus de {rendered}" if minimum else rendered


def _project_section(project: dict[str, Any]) -> str:
    indicators = project.get("key_indicators") or {}
    sdgs = project.get("sdgs") or []
    improvements = project.get("improvement_points") or []
    claims = project.get("claims") or []
    rows = [
        ("Beneficiaires directs", indicators.get("direct")),
        ("Beneficiaires indirects", indicators.get("indirect")),
        ("Portee", indicators.get("reach")),
        ("Emplois crees", indicators.get("jobs_created")),
        ("Revenus", indicators.get("revenue")),
        ("Excedent", indicators.get("surplus")),
        ("Preuves", indicators.get("evidence")),
        ("Preuves verifiees", indicators.get("verified_evidence")),
    ]
    table_rows = "\n".join(
        rf"{_escape(label)} & {_number(value)} \\" for label, value in rows
    )
    improvement_text = (
        r"\begin{itemize}"
        + "".join(rf"\item {_escape(item)}" for item in improvements)
        + r"\end{itemize}"
        if improvements
        else "Aucun point automatique signale."
    )
    return rf"""
\section{{{_escape(project.get('project_name'))}}}
\textbf{{Resume :}} {_escape(project.get('summary'))}

\medskip
\begin{{tabularx}}{{\textwidth}}{{@{{}}Xr@{{}}}}
\toprule
\textbf{{Indicateur}} & \textbf{{Valeur}} \\
\midrule
{table_rows}
\bottomrule
\end{{tabularx}}

\medskip
\textbf{{ODD :}} {_escape(', '.join(map(str, sdgs)) if sdgs else None)}\\
\textbf{{Methodologie :}} {_escape(project.get('methodology'))}\\
\textbf{{Hypotheses / projection :}} {_escape(project.get('projection'))}\\
\textbf{{Declarations documentees :}} {_number(len(claims))}

\subsection*{{Points d'amelioration}}
{improvement_text}
"""


def _latex_document(report: dict[str, Any]) -> str:
    summary = report.get("global_summary") or {}
    historical = report.get("institutional_historical_impact") or {}
    projects = report.get("projects") or []
    global_rows = [
        ("Projets actifs", summary.get("active_projects")),
        ("Beneficiaires directs", summary.get("direct_beneficiaries")),
        ("Beneficiaires indirects", summary.get("indirect_beneficiaries")),
        ("Portee totale", summary.get("reach")),
        ("Vies impactees", summary.get("lives_impacted")),
        ("Emplois crees", summary.get("jobs_created")),
        ("Revenus", summary.get("revenue")),
        ("Excedent", summary.get("surplus")),
        ("Preuves validees", summary.get("validated_evidence")),
    ]
    table_rows = "\n".join(
        rf"{_escape(label)} & {_number(value)} \\" for label, value in global_rows
    )
    historical_rows = [
        (
            "Vies impactees",
            _historical_number(
                historical.get("impacted_lives"),
                minimum=bool(historical.get("impacted_lives_is_minimum")),
            ),
        ),
        (
            "Emplois crees",
            _historical_number(
                historical.get("created_jobs"),
                minimum=bool(historical.get("created_jobs_is_minimum")),
            ),
        ),
        ("Personnes formees", _number(historical.get("people_trained"))),
        ("Produits developpes", _number(historical.get("developed_products"))),
        ("Heures de travail investies", _number(historical.get("work_hours"))),
        ("ODD touches", _number(historical.get("touched_sdgs"))),
        (
            "Revenus 2021-2022 (USD)",
            _number(historical.get("revenue_usd_2021_2022")),
        ),
        ("Arbres plantes", _number(historical.get("planted_trees"))),
        ("Kilometres terrain", _number(historical.get("field_kilometers"))),
    ]
    historical_table_rows = "\n".join(
        rf"{_escape(label)} & {value} \\" for label, value in historical_rows
    )
    project_sections = "\n".join(_project_section(project) for project in projects)
    if not project_sections:
        project_sections = r"\emph{Aucun projet Impact disponible pour cette synthese.}"
    return rf"""\documentclass[11pt,a4paper]{{article}}
\usepackage[utf8]{{inputenc}}
\usepackage[T1]{{fontenc}}
\usepackage[french]{{babel}}
\usepackage[a4paper,margin=1.8cm]{{geometry}}
\usepackage{{booktabs}}
\usepackage{{tabularx}}
\usepackage{{xcolor}}
\usepackage{{hyperref}}
\definecolor{{enactusgold}}{{HTML}}{{FFC222}}
\definecolor{{enactusblack}}{{HTML}}{{171717}}
\hypersetup{{colorlinks=true,linkcolor=enactusblack,urlcolor=enactusblack}}
\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{6pt}}
\title{{\textbf{{{_escape(report.get('title') or 'Synthese Impact Enactus ESP')}}}}}
\author{{Enactus ESP -- EnactSpace}}
\date{{Genere le {_escape(report.get('generated_at'))}}}
\begin{{document}}
\maketitle
\color{{enactusblack}}
\section*{{Synthese globale}}
\begin{{tabularx}}{{\textwidth}}{{@{{}}Xr@{{}}}}
\toprule
\textbf{{Indicateur}} & \textbf{{Valeur}} \\
\midrule
{table_rows}
\bottomrule
\end{{tabularx}}

\medskip
\textbf{{ODD touches :}} {_escape(', '.join(map(str, summary.get('touched_sdgs') or [])) or None)}

\section*{{Impact historique institutionnel}}
\textbf{{Source :}} {_escape(historical.get('source_label'))}

\begin{{tabularx}}{{\textwidth}}{{@{{}}Xr@{{}}}}
\toprule
\textbf{{Indicateur}} & \textbf{{Valeur}} \\
\midrule
{historical_table_rows}
\bottomrule
\end{{tabularx}}

\medskip
\textbf{{Revenus beneficiaires :}} +{_number(historical.get('beneficiary_income_increase_pct'))}\%\\
\textbf{{Malnutrition dans les villages cibles :}} {_number(historical.get('malnutrition_before_pct'))}\% a {_number(historical.get('malnutrition_after_pct'))}\%

\section*{{Projets}}
{project_sections}

\vfill
\hrule
\small Ce rapport est produit depuis les donnees EnactSpace. Les valeurs non renseignees ne sont pas extrapolees.
\end{{document}}
"""


def build_impact_summary_pdf(report: dict[str, Any]) -> bytes:
    executable = shutil.which("pdflatex")
    if executable is None:
        raise ImpactPdfGenerationError("Le moteur PDF du serveur est indisponible.")

    with tempfile.TemporaryDirectory(prefix="enactspace-impact-") as directory:
        workdir = Path(directory)
        source = workdir / "impact-summary.tex"
        source.write_text(_latex_document(report), encoding="utf-8")
        command = [
            executable,
            "-halt-on-error",
            "-interaction=nonstopmode",
            "-no-shell-escape",
            source.name,
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=workdir,
                capture_output=True,
                check=False,
                timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired) as error:
            raise ImpactPdfGenerationError(
                "La generation du rapport Impact a echoue."
            ) from error

        output = workdir / "impact-summary.pdf"
        if completed.returncode != 0 or not output.exists():
            log = (completed.stdout + completed.stderr).decode(
                "utf-8", errors="replace"
            )[-2000:]
            raise ImpactPdfGenerationError(
                f"La generation du rapport Impact a echoue. {log}"
            )
        pdf = output.read_bytes()
        if not pdf.startswith(b"%PDF-"):
            raise ImpactPdfGenerationError("Le rapport PDF genere est invalide.")
        return pdf
