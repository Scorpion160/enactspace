"""Bounded, private attachments shared by operational and public forms."""
from pathlib import Path
import io
import zipfile

from fastapi import HTTPException, UploadFile

MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024
MAX_APPLICATION_ATTACHMENT_BYTES = 10 * 1024 * 1024
DOCUMENT_EXTENSIONS = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".docx", ".odt"}
TASK_EXTENSIONS = DOCUMENT_EXTENSIONS | {".txt", ".csv", ".xlsx", ".pptx", ".ods", ".odp", ".zip"}


async def read_attachment(file: UploadFile, *, application=False):
    limit = MAX_APPLICATION_ATTACHMENT_BYTES if application else MAX_ATTACHMENT_BYTES
    data = await file.read(limit + 1)
    if len(data) > limit:
        raise HTTPException(413, f"Le fichier dépasse la limite de {limit // (1024 * 1024)} Mo.")
    if not data:
        raise HTTPException(400, "Le fichier est vide.")
    name = (file.filename or "").replace("\\", "/").rsplit("/", 1)[-1]
    extension = Path(name).suffix.lower()
    if extension not in (DOCUMENT_EXTENSIONS if application else TASK_EXTENSIONS):
        raise HTTPException(400, "Choisissez un document ou une image dans un format autorisé.")
    signatures = {
        ".pdf": data.lstrip().startswith(b"%PDF-"),
        ".png": data.startswith(b"\x89PNG\r\n\x1a\n"),
        ".jpg": data.startswith(b"\xff\xd8\xff"),
        ".jpeg": data.startswith(b"\xff\xd8\xff"),
        ".webp": data.startswith(b"RIFF") and data[8:12] == b"WEBP",
    }
    if extension in signatures and not signatures[extension]:
        raise HTTPException(400, "Le contenu du fichier ne correspond pas à son format.")
    if extension in {".docx", ".xlsx", ".pptx", ".odt", ".ods", ".odp", ".zip"}:
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                names = set(archive.namelist())
                required = {".docx": "word/document.xml", ".xlsx": "xl/workbook.xml", ".pptx": "ppt/presentation.xml"}.get(extension)
                if required and required not in names:
                    raise ValueError("Invalid office file")
                if extension in {".odt", ".ods", ".odp"} and "content.xml" not in names:
                    raise ValueError("Invalid OpenDocument file")
        except (zipfile.BadZipFile, ValueError):
            raise HTTPException(400, "Le document est incomplet ou son format est invalide.")
    return name, data
