import base64
import binascii
import hashlib
import mimetypes
import re
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.document import Document
from app.models.post import Post
from app.models.stored_file import StoredFile
from app.models.user import User


MAX_FILE_SIZE_BYTES = 500 * 1024 * 1024
TEMPORARY_RETENTION_DAYS = 90
UPLOAD_ROOT = Path(__file__).resolve().parents[2] / "uploads" / "files"
ALLOWED_STORAGE_SCOPES = {
    "chat",
    "document",
    "post",
    "project",
    "pole",
    "impact",
    "recruitment",
    "academy",
    "archive",
    "official",
    "temporary",
}
ALLOWED_VISIBILITIES = {
    "private",
    "participants",
    "pole_only",
    "project_only",
    "enacchef_only",
    "internal",
    "public_club",
    "alumni_only",
}
ALLOWED_EPHEMERAL_DURATIONS = {
    "24h": timedelta(hours=24),
    "7d": timedelta(days=7),
    "30d": timedelta(days=30),
}
BLOCKED_EXTENSIONS = {
    ".bat",
    ".cmd",
    ".com",
    ".dll",
    ".exe",
    ".js",
    ".msi",
    ".ps1",
    ".scr",
    ".sh",
    ".vbs",
}
BLOCKED_MIME_PREFIXES = ("application/x-msdownload",)
PROTECTED_STORAGE_SCOPES = {"official", "archive"}
PROTECTED_DOCUMENT_STATUSES = {"validated", "submitted"}


def safe_filename(file_name: str) -> str:
    base_name = Path(file_name or "file.bin").name
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "_", base_name).strip("._")
    return sanitized or "file.bin"


def normalize_base64(data: str) -> str:
    stripped = (data or "").strip()
    if "," in stripped and stripped.lower().startswith("data:"):
        return stripped.split(",", 1)[1]
    return stripped


def infer_mime_type(file_name: str, provided_mime_type: str | None = None) -> str:
    if provided_mime_type and "/" in provided_mime_type:
        return provided_mime_type[:160]
    guessed, _ = mimetypes.guess_type(file_name)
    return guessed or "application/octet-stream"


def validate_file_metadata(
    *,
    file_name: str,
    mime_type: str | None,
    file_size: int,
) -> None:
    if file_size <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le fichier est vide.",
        )

    if file_size > MAX_FILE_SIZE_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail="Le fichier depasse la limite de 500 Mo.",
        )

    extension = Path(file_name).suffix.lower()
    if extension in BLOCKED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ce type de fichier n'est pas autorise.",
        )

    normalized_mime = (mime_type or "").lower()
    if any(normalized_mime.startswith(prefix) for prefix in BLOCKED_MIME_PREFIXES):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ce type MIME n'est pas autorise.",
        )


def build_expiration(
    *,
    is_temporary: bool,
    is_ephemeral: bool,
    ephemeral_duration: str | None,
) -> datetime | None:
    now = datetime.utcnow()
    if is_ephemeral:
        duration = ALLOWED_EPHEMERAL_DURATIONS.get(ephemeral_duration or "")
        if duration is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Duree ephemere invalide.",
            )
        return now + duration
    if is_temporary:
        return now + timedelta(days=TEMPORARY_RETENTION_DAYS)
    return None


def store_bytes(
    db: Session,
    *,
    data: bytes,
    original_filename: str,
    uploaded_by: User,
    mime_type: str | None = None,
    storage_scope: str = "temporary",
    visibility: str = "private",
    entity_type: str | None = None,
    entity_id=None,
    is_temporary: bool = True,
    is_ephemeral: bool = False,
    ephemeral_duration: str | None = None,
) -> StoredFile:
    if storage_scope not in ALLOWED_STORAGE_SCOPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Scope de stockage invalide.",
        )
    if visibility not in ALLOWED_VISIBILITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Visibilite fichier invalide.",
        )

    file_name = safe_filename(original_filename)
    detected_mime = infer_mime_type(file_name, mime_type)
    validate_file_metadata(
        file_name=file_name,
        mime_type=detected_mime,
        file_size=len(data),
    )

    extension = Path(file_name).suffix.lower().lstrip(".") or None
    checksum = hashlib.sha256(data).hexdigest()
    stored_filename = f"{uuid4().hex}_{file_name}"
    scope_dir = UPLOAD_ROOT / storage_scope
    scope_dir.mkdir(parents=True, exist_ok=True)
    file_path = scope_dir / stored_filename
    file_path.write_bytes(data)

    stored_file = StoredFile(
        original_filename=file_name,
        stored_filename=stored_filename,
        mime_type=detected_mime,
        file_size=len(data),
        extension=extension,
        storage_path=str(file_path.relative_to(UPLOAD_ROOT)),
        storage_scope=storage_scope,
        uploaded_by_id=uploaded_by.id,
        is_temporary=is_temporary,
        is_ephemeral=is_ephemeral,
        ephemeral_duration=ephemeral_duration if is_ephemeral else None,
        checksum=checksum,
        visibility=visibility,
        entity_type=entity_type,
        entity_id=entity_id,
        expires_at=build_expiration(
            is_temporary=is_temporary,
            is_ephemeral=is_ephemeral,
            ephemeral_duration=ephemeral_duration,
        ),
    )
    db.add(stored_file)
    db.flush()
    return stored_file


def store_base64(db: Session, *, data_base64: str, **kwargs) -> StoredFile:
    try:
        data = base64.b64decode(normalize_base64(data_base64), validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Fichier base64 invalide.",
        )
    return store_bytes(db, data=data, **kwargs)


def file_path(stored_file: StoredFile) -> Path:
    return (UPLOAD_ROOT / stored_file.storage_path).resolve()


def delete_physical_file(stored_file: StoredFile) -> None:
    path = file_path(stored_file)
    try:
        if path.is_file() and UPLOAD_ROOT.resolve() in path.parents:
            path.unlink()
    except OSError:
        pass


def is_storage_path_safe(stored_file: StoredFile) -> bool:
    try:
        path = file_path(stored_file)
        root = UPLOAD_ROOT.resolve()
        return path != root and root in path.parents
    except OSError:
        return False


def cleanup_skip_reason(
    db: Session,
    stored_file: StoredFile,
    *,
    cleanup_time: datetime,
) -> str | None:
    if not is_storage_path_safe(stored_file):
        return "unsafe_path"

    if stored_file.storage_scope in PROTECTED_STORAGE_SCOPES:
        return "protected_scope"

    if not stored_file.is_temporary and not stored_file.is_ephemeral:
        return "permanent_file"

    if stored_file.expires_at and stored_file.expires_at > cleanup_time:
        return "not_expired"

    if stored_file.entity_type == "chat_thread" and not stored_file.is_ephemeral:
        return "linked_chat_message"

    linked_post = db.query(Post).filter(Post.media_file_id == stored_file.id).first()
    if linked_post or stored_file.entity_type == "post":
        return "linked_post"

    linked_document = db.query(Document).filter(
        Document.file_id == stored_file.id
    ).first()
    if not linked_document and stored_file.entity_type == "document":
        linked_document = db.query(Document).filter(
            Document.id == stored_file.entity_id
        ).first()
    if linked_document:
        if (
            linked_document.status in PROTECTED_DOCUMENT_STATUSES
            or linked_document.is_official
            or linked_document.is_permanent
            or linked_document.validated_at is not None
        ):
            return "protected_document"
        return "linked_document"

    return None


def cleanup_expired_files(
    db: Session,
    *,
    now: datetime | None = None,
    limit: int = 500,
    dry_run: bool = True,
) -> dict:
    cleanup_time = now or datetime.utcnow()
    temporary_cutoff = cleanup_time - timedelta(days=TEMPORARY_RETENTION_DAYS)
    candidates = (
        db.query(StoredFile)
        .filter(
            (
                StoredFile.is_ephemeral.is_(True)
                & (StoredFile.expires_at.isnot(None))
                & (StoredFile.expires_at <= cleanup_time)
            )
            | (
                StoredFile.is_temporary.is_(True)
                & (
                    (
                        (StoredFile.expires_at.isnot(None))
                        & (StoredFile.expires_at <= cleanup_time)
                    )
                    | (
                        (StoredFile.expires_at.is_(None))
                        & (StoredFile.created_at <= temporary_cutoff)
                    )
                )
            )
        )
        .order_by(StoredFile.created_at.asc())
        .limit(limit)
        .all()
    )

    scanned_count = len(candidates)
    deleted_bytes = 0
    deleted_count = 0
    skipped_count = 0
    error_count = 0
    for stored_file in candidates:
        skip_reason = cleanup_skip_reason(
            db,
            stored_file,
            cleanup_time=cleanup_time,
        )
        if skip_reason:
            skipped_count += 1
            continue

        if dry_run:
            deleted_count += 1
            deleted_bytes += stored_file.file_size or 0
            continue

        try:
            delete_physical_file(stored_file)
            deleted_bytes += stored_file.file_size or 0
            db.delete(stored_file)
            deleted_count += 1
        except OSError:
            error_count += 1

    if not dry_run:
        db.flush()
    return {
        "scanned": scanned_count,
        "deleted": deleted_count,
        "skipped": skipped_count,
        "errors": error_count,
        "dry_run": dry_run,
        "deleted_bytes": deleted_bytes,
        "limit": limit,
        "cleanup_time": cleanup_time.isoformat(),
    }
