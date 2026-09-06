from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class Locale(str, Enum):
    fr = "fr"
    en = "en"


class ThemePreference(str, Enum):
    system = "system"
    light = "light"
    dark = "dark"


class LegalDocumentType(str, Enum):
    privacy_policy = "privacy_policy"
    terms_of_use = "terms_of_use"


class LegalAcceptanceSource(str, Enum):
    web = "web"
    android = "android"
    ios = "ios"
    api = "api"


class DeletionStatus(str, Enum):
    pending = "pending"
    cancelled = "cancelled"
    approved = "approved"
    completed = "completed"
    rejected = "rejected"


class UserPreferenceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: UUID
    locale: Locale
    theme: ThemePreference
    notification_in_app_enabled: bool
    notification_email_enabled: bool
    notification_push_enabled: bool
    created_at: datetime
    updated_at: datetime


class UserPreferenceUpdate(BaseModel):
    locale: Locale | None = None
    theme: ThemePreference | None = None
    notification_in_app_enabled: bool | None = None
    notification_email_enabled: bool | None = None
    notification_push_enabled: bool | None = None


class LegalDocumentCreate(BaseModel):
    document_type: LegalDocumentType
    version: str = Field(min_length=1, max_length=40, pattern=r"^[A-Za-z0-9._-]+$")
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(min_length=1)
    effective_at: datetime | None = None
    requires_acceptance: bool = True


class LegalDocumentRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    document_type: LegalDocumentType
    version: str
    title: str
    content: str
    effective_at: datetime | None
    published_at: datetime | None
    is_active: bool
    requires_acceptance: bool
    created_at: datetime
    updated_at: datetime


class LegalDocumentPublish(BaseModel):
    effective_at: datetime | None = None


class LegalAcceptanceCreate(BaseModel):
    legal_document_id: UUID
    version: str = Field(min_length=1, max_length=40)
    source: LegalAcceptanceSource | None = None


class LegalAcceptanceRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    legal_document_id: UUID
    document_version: str
    source: LegalAcceptanceSource | None
    accepted_at: datetime


class LegalStatusItem(BaseModel):
    document_type: LegalDocumentType
    document_id: UUID
    version: str
    requires_acceptance: bool
    accepted: bool
    accepted_at: datetime | None = None


class DataExportRead(BaseModel):
    metadata: dict
    data: dict


class AccountDeletionCreate(BaseModel):
    reason: str | None = Field(default=None, max_length=2000)


class AccountDeletionUserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    status: DeletionStatus
    requested_at: datetime
    processed_at: datetime | None
    cancelled_at: datetime | None
    reason: str | None


class AccountDeletionRead(AccountDeletionUserRead):
    admin_note: str | None


class AccountDeletionProcess(BaseModel):
    status: DeletionStatus
    admin_note: str | None = Field(default=None, max_length=4000)
