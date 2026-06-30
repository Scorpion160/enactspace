from datetime import datetime
from uuid import UUID

from pydantic import BaseModel


class StoredFileRead(BaseModel):
    id: UUID
    original_filename: str
    stored_filename: str
    mime_type: str | None = None
    file_size: int
    extension: str | None = None
    storage_scope: str
    uploaded_by_id: UUID | None = None
    is_temporary: bool
    is_ephemeral: bool
    ephemeral_duration: str | None = None
    visibility: str
    entity_type: str | None = None
    entity_id: UUID | None = None
    expires_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    download_url: str = ""
    preview_url: str = ""

    class Config:
        from_attributes = True
