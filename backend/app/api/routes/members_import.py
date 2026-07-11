from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.deps import require_sg_or_admin
from app.db.database import get_db
from app.models.user import User
from app.scripts.import_members import run_members_import


router = APIRouter(prefix="/members/import", tags=["Import membres"])

MAX_IMPORT_BYTES = 2 * 1024 * 1024


def _template_path() -> Path:
    return (
        Path(__file__).resolve().parents[4]
        / "data"
        / "import"
        / "membres_enactus_template.csv"
    )


async def _read_csv_upload(file: UploadFile) -> str:
    filename = (file.filename or "").lower()
    if not filename.endswith(".csv"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le fichier doit etre un CSV.",
        )

    content = await file.read()
    if len(content) > MAX_IMPORT_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Le fichier CSV depasse la limite de 2 Mo.",
        )

    try:
        return content.decode("utf-8-sig")
    except UnicodeDecodeError:
        try:
            return content.decode("latin-1")
        except UnicodeDecodeError as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Le fichier CSV doit etre encode en UTF-8.",
            ) from error


@router.get("/template")
def download_members_import_template(
    current_user: User = Depends(require_sg_or_admin),
):
    path = _template_path()
    if not path.exists():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Modele CSV introuvable.",
        )

    return FileResponse(
        path,
        media_type="text/csv",
        filename="membres_enactus_template.csv",
    )


@router.post("/preview")
async def preview_members_import(
    file: UploadFile = File(...),
    update_existing: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    csv_content = await _read_csv_upload(file)
    report = run_members_import(
        db,
        csv_content,
        dry_run=True,
        update_existing=update_existing,
    )
    return report.to_dict()


@router.post("/apply")
async def apply_members_import(
    file: UploadFile = File(...),
    update_existing: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    csv_content = await _read_csv_upload(file)
    report = run_members_import(
        db,
        csv_content,
        dry_run=False,
        update_existing=update_existing,
    )
    return report.to_dict()
