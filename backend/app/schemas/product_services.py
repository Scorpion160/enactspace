from datetime import datetime
from enum import Enum
import ipaddress
from urllib.parse import urlparse
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


VERSION_PATTERN = r"^\d+(?:\.\d+){1,3}(?:[-+][0-9A-Za-z.-]+)?$"


def _validate_public_https_url(value: str | None) -> str | None:
    if value is None:
        return None
    normalized = value.strip()
    if not normalized:
        return None
    parsed = urlparse(normalized)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("store_url must be a public HTTPS URL")
    hostname = parsed.hostname.lower()
    if hostname == "localhost" or hostname.endswith(".localhost"):
        raise ValueError("store_url must be a public HTTPS URL")
    try:
        address = ipaddress.ip_address(hostname)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ValueError("store_url must be a public HTTPS URL")
    return normalized


class ProductPlatform(str, Enum):
    ios = "ios"
    android = "android"
    web = "web"


class InstallationUpsert(BaseModel):
    installation_key: UUID
    platform: ProductPlatform
    app_version: str | None = Field(default=None, max_length=40)
    build_number: int | None = Field(default=None, gt=0)
    os_version: str | None = Field(default=None, max_length=80)
    device_model: str | None = Field(default=None, max_length=120)
    locale: str | None = Field(default=None, max_length=20)


class InstallationRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    installation_key: UUID
    platform: ProductPlatform
    app_version: str | None
    build_number: int | None
    os_version: str | None
    device_model: str | None
    locale: str | None
    last_seen_at: datetime
    revoked_at: datetime | None
    created_at: datetime
    updated_at: datetime


class SupportCategory(str, Enum):
    general = "general"
    account = "account"
    access = "access"
    technical = "technical"
    billing = "billing"
    other = "other"


class SupportStatus(str, Enum):
    open = "open"
    in_progress = "in_progress"
    resolved = "resolved"
    closed = "closed"


class SupportPriority(str, Enum):
    low = "low"
    normal = "normal"
    high = "high"
    urgent = "urgent"


class SupportTicketCreate(BaseModel):
    subject: str = Field(min_length=1, max_length=200)
    category: SupportCategory = SupportCategory.general
    priority: SupportPriority = SupportPriority.normal
    message: str = Field(min_length=1, max_length=10000)

    @field_validator("subject", "message")
    @classmethod
    def text_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("value must not be blank")
        return value


class SupportTicketMessageCreate(BaseModel):
    message: str = Field(min_length=1, max_length=10000)

    @field_validator("message")
    @classmethod
    def message_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("value must not be blank")
        return value


class SupportTicketMessageRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    ticket_id: UUID
    author_id: UUID | None
    message: str
    created_at: datetime


class SupportTicketRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    subject: str
    category: SupportCategory
    status: SupportStatus
    priority: SupportPriority
    assigned_to_id: UUID | None
    created_at: datetime
    updated_at: datetime
    resolved_at: datetime | None
    closed_at: datetime | None


class SupportTicketDetail(SupportTicketRead):
    messages: list[SupportTicketMessageRead]


class SupportTicketManage(BaseModel):
    status: SupportStatus | None = None
    priority: SupportPriority | None = None
    assigned_to_id: UUID | None = None


class FeedbackCategory(str, Enum):
    bug = "bug"
    idea = "idea"
    usability = "usability"
    other = "other"


class FeedbackStatus(str, Enum):
    new = "new"
    reviewed = "reviewed"
    planned = "planned"
    closed = "closed"


class ProductFeedbackCreate(BaseModel):
    category: FeedbackCategory
    message: str = Field(min_length=1, max_length=10000)
    rating: int | None = Field(default=None, ge=1, le=5)
    platform: ProductPlatform | None = None
    app_version: str | None = Field(default=None, max_length=40)
    build_number: int | None = Field(default=None, gt=0)

    @field_validator("message")
    @classmethod
    def message_must_not_be_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("value must not be blank")
        return value


class ProductFeedbackRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    category: FeedbackCategory
    message: str
    rating: int | None
    platform: ProductPlatform | None
    app_version: str | None
    build_number: int | None
    status: FeedbackStatus
    created_at: datetime
    updated_at: datetime


class ProductFeedbackAdminRead(ProductFeedbackRead):
    admin_note: str | None


class ProductFeedbackManage(BaseModel):
    status: FeedbackStatus | None = None
    admin_note: str | None = Field(default=None, max_length=10000)


class AppReleaseCreate(BaseModel):
    platform: ProductPlatform
    version: str = Field(min_length=3, max_length=40, pattern=VERSION_PATTERN)
    build_number: int = Field(gt=0)
    release_notes: str | None = Field(default=None, max_length=20000)
    store_url: str | None = Field(default=None, max_length=2000)

    @field_validator("store_url")
    @classmethod
    def store_url_must_be_public_https(cls, value: str | None) -> str | None:
        return _validate_public_https_url(value)


class AppReleaseUpdate(BaseModel):
    version: str | None = Field(default=None, min_length=3, max_length=40, pattern=VERSION_PATTERN)
    build_number: int | None = Field(default=None, gt=0)
    release_notes: str | None = Field(default=None, max_length=20000)
    store_url: str | None = Field(default=None, max_length=2000)

    @field_validator("store_url")
    @classmethod
    def store_url_must_be_public_https(cls, value: str | None) -> str | None:
        return _validate_public_https_url(value)


class AppReleaseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    platform: ProductPlatform
    version: str
    build_number: int
    release_notes: str | None
    status: str
    store_url: str | None
    published_at: datetime | None
    created_by_id: UUID | None
    created_at: datetime
    updated_at: datetime


class AppVersionPolicyUpdate(BaseModel):
    current_release_id: UUID | None = None
    minimum_supported_release_id: UUID | None = None
    force_update_to_current: bool | None = None
    maintenance_enabled: bool | None = None
    maintenance_message: str | None = Field(default=None, max_length=4000)
    maintenance_starts_at: datetime | None = None
    maintenance_ends_at: datetime | None = None


class AppVersionPolicyRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    platform: ProductPlatform
    current_release_id: UUID | None
    minimum_supported_release_id: UUID | None
    force_update_to_current: bool
    maintenance_enabled: bool
    maintenance_message: str | None
    maintenance_starts_at: datetime | None
    maintenance_ends_at: datetime | None
    updated_by_id: UUID | None
    created_at: datetime
    updated_at: datetime


class MaintenanceDecision(BaseModel):
    active: bool
    message: str | None


class ProductBootstrapRead(BaseModel):
    configured: bool
    platform: ProductPlatform
    client_version: str
    client_build_number: int
    current_version: str | None
    current_build_number: int | None
    minimum_supported_version: str | None
    minimum_supported_build_number: int | None
    update_available: bool
    update_required: bool
    force_update: bool
    store_url: str | None
    maintenance: MaintenanceDecision
