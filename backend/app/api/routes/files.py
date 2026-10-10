from app.core.time import utc_now
from datetime import datetime
from pathlib import Path
from uuid import UUID

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    HTTPException,
    Query,
    UploadFile,
    status,
)
from fastapi.responses import FileResponse
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, user_has_any_role
from app.db.database import get_db
from app.models.chat import ChatParticipant
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.stored_file import StoredFileRead
from app.services.file_storage_service import (
    MAX_FILE_SIZE_BYTES,
    cleanup_expired_files,
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
    try:
        identifier = UUID(str(file_id))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(status_code=404, detail="Fichier introuvable.")
    stored_file = db.query(StoredFile).filter(StoredFile.id == identifier).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier introuvable.",
        )
    if stored_file.expires_at and stored_file.expires_at <= utc_now():
        from app.models.finance import Payment
        linked_payment = db.query(Payment.id).filter(or_(
            Payment.proof_file_id == stored_file.id,
            Payment.receipt_file_id == stored_file.id,
        )).first()
        if linked_payment is None:
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
    from app.models.finance import Payment
    payment = db.query(Payment).filter(or_(
        Payment.proof_file_id == stored_file.id,
        Payment.receipt_file_id == stored_file.id,
    )).first()
    if payment is not None or stored_file.entity_type == "payment":
        if manage:
            raise HTTPException(409, "Ce justificatif appartient à un paiement et doit être conservé.")
        from app.api.routes.finance import is_finance_manager
        if payment is not None and (
            payment.user_id == current_user.id or is_finance_manager(db, current_user)
        ):
            return
        raise HTTPException(403, "Ce justificatif est réservé au membre concerné et aux responsables financiers.")
    if stored_file.entity_type in {"task", "application", "event", "impact_record", "attendance_record"} and stored_file.entity_id:
        if manage:
            raise HTTPException(409, "Cette pièce jointe appartient à un dossier. Modifiez-la depuis sa fiche.")
        if stored_file.entity_type == "attendance_record":
            from app.models.attendance import AttendanceRecord, AttendanceSession
            from app.api.routes.attendance import _can_manage_session
            record = db.get(AttendanceRecord, stored_file.entity_id)
            session = db.get(AttendanceSession, record.session_id) if record else None
            if record and session and (record.user_id == current_user.id or _can_manage_session(db, current_user, session)):
                return
            raise HTTPException(403, "Ce justificatif est réservé au membre concerné et aux responsables de la présence.")
        if stored_file.entity_type == "task":
            from app.models.task import Task
            from app.api.routes.tasks import ensure_task_viewer
            task = db.get(Task, stored_file.entity_id)
            if task is None:
                raise HTTPException(404, "Tâche introuvable")
            ensure_task_viewer(db, task, current_user)
            return
        if stored_file.entity_type == "event":
            from app.models.event import Event
            if current_user.status == "active" and db.get(Event, stored_file.entity_id):
                return
            raise HTTPException(403, "Ce rapport est réservé aux membres actifs.")
        if stored_file.entity_type == "impact_record":
            from app.core.roles import ENACCHEF_ROLES
            if current_user.status == "active" and user_has_any_role(db,current_user.id,ENACCHEF_ROLES):
                return
            raise HTTPException(403, "Ce justificatif est réservé aux responsables du suivi d’impact.")
        from app.models.recruitment import Application
        from app.api.deps import can_access_recruitment
        application = db.get(Application, stored_file.entity_id)
        if application and can_access_recruitment(db, current_user):
            return
        raise HTTPException(403, "Cette pièce jointe est réservée à l’équipe recrutement.")
    if current_user.status == "active" and current_user.is_active and user_has_any_role(db, current_user.id, GLOBAL_FILE_ROLES):
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

    if stored_file.entity_type == "document" and stored_file.entity_id:
        from app.api.routes.documents import visible_documents_query
        from app.models.document import Document

        visible_document = (
            visible_documents_query(db, current_user)
            .filter(Document.id == stored_file.entity_id)
            .first()
        )
        if visible_document:
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
    if entity_type in {"task", "application", "event", "attendance_record", "payment"}:
        raise HTTPException(400, "Joignez ce fichier depuis la fiche concernée.")
    if entity_type == "impact_record":
        from app.core.roles import ENACCHEF_ROLES
        from app.models.impact import ImpactProject
        if current_user.status != "active" or not user_has_any_role(db,current_user.id,ENACCHEF_ROLES):
            raise HTTPException(403,"Action réservée aux responsables du suivi d’impact.")
        if not entity_id or not db.get(ImpactProject,parse_entity_id(entity_id)):
            raise HTTPException(404,"Fiche impact introuvable.")
        visibility="private"
        is_temporary=False
    if entity_type == "impact_record":
        from app.services.attachment_service import read_attachment
        _, data = await read_attachment(file)
    else:
        data = await file.read(MAX_FILE_SIZE_BYTES + 1)
    stored_file = store_bytes(
        db,
        data=data,
        original_filename=file.filename or "file.bin",
        uploaded_by=current_user,
        mime_type=None if entity_type == "impact_record" else file.content_type,
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


@router.post("/cleanup")
def cleanup_files(
    dry_run: bool = Query(default=True),
    limit: int = Query(default=500, ge=1, le=2000),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if current_user.status != "active" or not current_user.is_active or not user_has_any_role(db, current_user.id, GLOBAL_FILE_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Nettoyage reserve aux responsables.",
        )
    result = cleanup_expired_files(db, limit=limit, dry_run=dry_run)
    if dry_run:
        db.rollback()
    else:
        db.commit()
    return {"ok": True, **result}


@router.get("/{file_id}/profile-photo")
def profile_photo(
    file_id: str,
    db: Session = Depends(get_db),
):
    stored_file = get_file_or_404(db, file_id)
    if (
        stored_file.storage_scope != "profile"
        or stored_file.entity_type != "profile_photo"
        or stored_file.visibility != "public_club"
        or (stored_file.mime_type or "").lower() not in {"image/png", "image/jpeg", "image/webp", "image/gif"}
    ):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo de profil introuvable.",
        )
    path = file_path(stored_file)
    if not path.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo de profil introuvable.",
        )
    return FileResponse(
        path,
        media_type=stored_file.mime_type or "image/jpeg",
        filename=Path(stored_file.original_filename).name,
        headers={"Cache-Control": "public, max-age=31536000, immutable",
                 "X-Content-Type-Options": "nosniff",
                 "Content-Security-Policy": "sandbox; default-src 'none'; base-uri 'none'"},
    )


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
        headers={"X-Content-Type-Options": "nosniff",
                 "Content-Security-Policy": "sandbox; default-src 'none'; base-uri 'none'"},
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
    mime = (stored_file.mime_type or "").lower()
    inline_types = {"application/pdf", "text/plain", "image/png", "image/jpeg", "image/webp", "image/gif"}
    return FileResponse(
        path,
        media_type=mime if mime in inline_types else "application/octet-stream",
        filename=Path(stored_file.original_filename).name,
        content_disposition_type="inline" if mime in inline_types else "attachment",
        headers={"X-Content-Type-Options": "nosniff",
                 "Content-Security-Policy": "sandbox; default-src 'none'; base-uri 'none'"},
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
