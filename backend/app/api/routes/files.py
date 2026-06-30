from datetime import datetime
from pathlib import Path
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, user_has_any_role
from app.db.database import get_db
from app.models.chat import ChatParticipant
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.stored_file import StoredFileRead
from app.services.file_storage_service import (
    MAX_FILE_SIZE_BYTES,
    delete_physical_file,
    file_path,
    store_bytes,
)


router = APIRouter(prefix="/files", tags=["Fichiers"])

GLOBAL_FILE_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}


def file_payload(stored_file: StoredFile) -> dict:
    data = StoredFileRead.model_validate(stored_file).model_dump()
    data["download_url"] = f"/api/files/{stored_file.id}/download"
    data["preview_url"] = f"/api/files/{stored_file.id}/preview"
    return data


def get_file_or_404(db: Session, file_id: str) -> StoredFile:
    stored_file = db.query(StoredFile).filter(StoredFile.id == file_id).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier introuvable.",
        )
    if stored_file.expires_at and stored_file.expires_at <= datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail="Ce fichier a expire.",
        )
    return stored_file


def parse_entity_id(entity_id: str | None):
    if not entity_id:
        return None
    try:
        return UUID(str(entity_id))
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Identifiant d'entite fichier invalide.",
        )


def ensure_file_access(
    db: Session,
    stored_file: StoredFile,
    current_user: User,
    *,
    manage: bool = False,
) -> None:
    if user_has_any_role(db, current_user.id, GLOBAL_FILE_ROLES):
        return

    if stored_file.uploaded_by_id == current_user.id:
        return

    if manage:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action reservee au proprietaire ou aux responsables.",
        )

    if stored_file.visibility in {"internal", "public_club"}:
        return

    if stored_file.entity_type == "chat_thread" and stored_file.entity_id:
        participant = db.query(ChatParticipant.id).filter(
            ChatParticipant.thread_id == stored_file.entity_id,
            ChatParticipant.user_id == current_user.id,
        ).first()
        if participant:
            return

    if stored_file.entity_type == "post" and stored_file.entity_id:
        from app.api.routes.posts import visible_posts_query
        from app.models.post import Post

        visible_post = visible_posts_query(db, current_user).filter(
            Post.id == stored_file.entity_id
        ).first()
        if visible_post:
            return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Vous n'avez pas acces a ce fichier.",
    )


@router.post("/upload", response_model=StoredFileRead)
async def upload_file(
    file: UploadFile = File(...),
    storage_scope: str = Form(default="temporary"),
    visibility: str = Form(default="private"),
    entity_type: str | None = Form(default=None),
    entity_id: str | None = Form(default=None),
    is_temporary: bool = Form(default=True),
    is_ephemeral: bool = Form(default=False),
    ephemeral_duration: str | None = Form(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    data = await file.read(MAX_FILE_SIZE_BYTES + 1)
    stored_file = store_bytes(
        db,
        data=data,
        original_filename=file.filename or "file.bin",
        uploaded_by=current_user,
        mime_type=file.content_type,
        storage_scope=storage_scope,
        visibility=visibility,
        entity_type=entity_type,
        entity_id=parse_entity_id(entity_id),
        is_temporary=is_temporary,
        is_ephemeral=is_ephemeral,
        ephemeral_duration=ephemeral_duration,
    )
    db.commit()
    db.refresh(stored_file)
    return file_payload(stored_file)


@router.get("/{file_id}", response_model=StoredFileRead)
def get_file_metadata(
    file_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    stored_file = get_file_or_404(db, file_id)
    ensure_file_access(db, stored_file, current_user)
    return file_payload(stored_file)


@router.get("/{file_id}/download")
def download_file(
    file_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    stored_file = get_file_or_404(db, file_id)
    ensure_file_access(db, stored_file, current_user)
    path = file_path(stored_file)
    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier physique introuvable.",
        )
    return FileResponse(
        path,
        media_type=stored_file.mime_type or "application/octet-stream",
        filename=stored_file.original_filename,
    )


@router.get("/{file_id}/preview")
def preview_file(
    file_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    stored_file = get_file_or_404(db, file_id)
    ensure_file_access(db, stored_file, current_user)
    path = file_path(stored_file)
    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier physique introuvable.",
        )
    preview_name = Path(stored_file.original_filename).name
    return FileResponse(
        path,
        media_type=stored_file.mime_type or "application/octet-stream",
        filename=preview_name,
        headers={"Content-Disposition": f'inline; filename="{preview_name}"'},
    )


@router.delete("/{file_id}")
def delete_file(
    file_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    stored_file = get_file_or_404(db, file_id)
    ensure_file_access(db, stored_file, current_user, manage=True)
    delete_physical_file(stored_file)
    db.delete(stored_file)
    db.commit()
    return {"ok": True, "message": "Fichier supprime."}
