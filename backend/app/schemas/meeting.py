from datetime import UTC, datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


def _naive_utc(value: datetime | None) -> datetime | None:
    if value is None or value.tzinfo is None:
        return value
    return value.astimezone(UTC).replace(tzinfo=None)


class MeetingCreate(BaseModel):
    title: str = Field(min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=4000)
    scope_type: str = "club"
    scope_id: UUID | None = None
    scheduled_start: datetime | None = None
    scheduled_end: datetime | None = None
    invite_user_ids: list[UUID] = Field(default_factory=list, max_length=250)
    start_with_audio_muted: bool = True
    start_with_video_muted: bool = True
    lobby_enabled: bool = True

    @field_validator("scheduled_start", "scheduled_end")
    @classmethod
    def normalize_schedule(cls, value: datetime | None) -> datetime | None:
        return _naive_utc(value)

    @field_validator("scope_type")
    @classmethod
    def validate_scope_type(cls, value: str) -> str:
        value = value.strip().lower()
        if value not in {"club", "pole", "project", "custom"}:
            raise ValueError("Portée de réunion invalide")
        return value

    @model_validator(mode="after")
    def validate_schedule_and_scope(self):
        if self.scope_type in {"pole", "project"} and self.scope_id is None:
            raise ValueError("scope_id est obligatoire pour une réunion de pôle/projet")
        if self.scope_type in {"club", "custom"} and self.scope_id is not None:
            raise ValueError("scope_id doit être vide pour cette portée")
        if self.scheduled_end is not None and self.scheduled_start is None:
            raise ValueError("Le début est obligatoire lorsqu’une fin est définie")
        if (
            self.scheduled_start is not None
            and self.scheduled_end is not None
            and self.scheduled_end <= self.scheduled_start
        ):
            raise ValueError("La fin doit être postérieure au début")
        return self


class MeetingUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=2, max_length=200)
    description: str | None = Field(default=None, max_length=4000)
    scheduled_start: datetime | None = None
    scheduled_end: datetime | None = None
    start_with_audio_muted: bool | None = None
    start_with_video_muted: bool | None = None
    lobby_enabled: bool | None = None

    @field_validator("scheduled_start", "scheduled_end")
    @classmethod
    def normalize_schedule(cls, value: datetime | None) -> datetime | None:
        return _naive_utc(value)


class MeetingMemberRead(BaseModel):
    user_id: UUID
    display_name: str
    first_name: str | None = None
    last_name: str | None = None
    role: str
    joined_at: datetime | None = None
    left_at: datetime | None = None


class MeetingRead(BaseModel):
    id: UUID
    room_key: str
    title: str
    description: str | None
    status: str
    scope_type: str
    scope_id: UUID | None
    provider: str
    server_url: str
    scheduled_start: datetime | None
    scheduled_end: datetime | None
    started_at: datetime | None
    ended_at: datetime | None
    created_by: UUID
    start_with_audio_muted: bool
    start_with_video_muted: bool
    lobby_enabled: bool
    recording_enabled: bool
    can_manage: bool = False
    can_delete: bool = False
    current_user_role: str = "participant"
    invited_count: int = 0
    joined_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class MeetingInviteRequest(BaseModel):
    user_ids: list[UUID] = Field(min_length=1, max_length=250)
    role: str = "participant"

    @field_validator("role")
    @classmethod
    def validate_role(cls, value: str) -> str:
        value = value.strip().lower()
        if value not in {"cohost", "participant"}:
            raise ValueError("Rôle d'invitation invalide")
        return value


class MeetingJoinRead(BaseModel):
    meeting_id: UUID
    room_key: str
    server_url: str
    jwt: str | None = None
    display_name: str
    email: str
    avatar_url: str | None = None
    moderator: bool
    start_with_audio_muted: bool
    start_with_video_muted: bool
    lobby_enabled: bool
    recording_enabled: bool
