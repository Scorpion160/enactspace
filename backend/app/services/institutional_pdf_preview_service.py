import shutil
import subprocess
import tempfile
from pathlib import Path

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.institutional_document import InstitutionalDocumentRequest
from app.services.institutional_pdf_service import (
    PDFLATEX_TIMEOUT_SECONDS,
    RESOURCE_ROOT,
    TEMPLATE_ROOT,
    InstitutionalPdfError,
    _copy_optional_assets,
    build_data_tex,
)


DRAFT_REFERENCE = "BROUILLON - NON OFFICIEL"


def build_preview_data_tex(
    db: Session,
    request: InstitutionalDocumentRequest,
) -> str:
    original_reference = request.official_reference
    try:
        request.official_reference = DRAFT_REFERENCE
        data = build_data_tex(db, request)
    finally:
        request.official_reference = original_reference
    return data + "\\EnableDraftWatermark\n"


def compile_request_preview_pdf(
    db: Session,
    request: InstitutionalDocumentRequest,
) -> bytes:
    if request.status == "cancelled":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une demande annulée ne peut pas être prévisualisée.",
        )

    executable = shutil.which("pdflatex")
    if executable is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Le moteur LaTeX pdflatex n'est pas installé sur le serveur.",
        )

    template_path = TEMPLATE_ROOT / f"{request.template_code}.tex"
    if not template_path.is_file():
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Modèle LaTeX serveur introuvable.",
        )

    with tempfile.TemporaryDirectory(prefix="enactspace-preview-") as tmp:
        work_dir = Path(tmp)
        (work_dir / "config").mkdir()
        (work_dir / "data").mkdir()
        shutil.copy2(RESOURCE_ROOT / "enactus_esp.sty", work_dir / "enactus_esp.sty")
        shutil.copy2(
            RESOURCE_ROOT / "config" / "institution.tex",
            work_dir / "config" / "institution.tex",
        )
        shutil.copy2(template_path, work_dir / "document.tex")
        _copy_optional_assets(work_dir)
        (work_dir / "data" / f"{request.template_code}_data.tex").write_text(
            build_preview_data_tex(db, request),
            encoding="utf-8",
        )

        command = [
            executable,
            "-halt-on-error",
            "-interaction=nonstopmode",
            "-no-shell-escape",
            "document.tex",
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=work_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=PDFLATEX_TIMEOUT_SECONDS,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except subprocess.TimeoutExpired as exc:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="La prévisualisation PDF a dépassé le délai autorisé.",
            ) from exc

        pdf_path = work_dir / "document.pdf"
        if completed.returncode != 0 or not pdf_path.is_file():
            log_tail = completed.stdout[-3000:] if completed.stdout else ""
            raise InstitutionalPdfError(
                f"Échec de compilation de l'aperçu LaTeX.\n{log_tail}"
            )
        pdf_bytes = pdf_path.read_bytes()
        if len(pdf_bytes) < 1000 or not pdf_bytes.startswith(b"%PDF-"):
            raise InstitutionalPdfError(
                "Le moteur LaTeX n'a pas produit un aperçu PDF valide."
            )
        return pdf_bytes
