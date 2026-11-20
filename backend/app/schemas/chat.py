from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field


class ChatContactRead(BaseModel):
    id: UUID
    first_name: str
    last_name: str
    email: str
    status: str
    photo_url: Optional[str] = None

    class Config:
        from_attributes = True


class ChatThreadCreate(BaseModel):
    title: Optional[str] = None
    thread_type: str = "group"
    scope_type: Optional[str] = None
    scope_id: Optional[UUID] = None
    participant_ids: List[UUID] = []


class ChatThreadMemberRead(BaseModel):
    user_id: UUID
    first_name: str
    last_name: str
    email: str
    status: str
    photo_url: Optional[str] = None
    participant_role: str = "member"


class ChatThreadRead(BaseModel):
    id: UUID
    title: Optional[str]
    display_title: Optional[str] = None
    avatar_url: Optional[str] = None
    thread_type: str
    scope_type: Optional[str]
    scope_id: Optional[UUID]
    created_by: Optional[UUID]
    created_at: datetime
    updated_at: datetime
    participants_count: int = 0
    unread_count: int = 0
    last_message: Optional[str] = None
    last_message_at: Optional[datetime] = None
    current_user_role: str = "member"
    participants_preview: List[ChatThreadMemberRead] = []


class ChatUnreadCountRead(BaseModel):
    unread_count: int


class ChatParticipantRead(BaseModel):
    id: UUID
    thread_id: UUID
    user_id: UUID
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[str] = None
    status: Optional[str] = None
    photo_url: Optional[str] = None
    participant_role: str
    joined_at: datetime
    last_read_at: Optional[datetime]

    class Config:
        from_attributes = True


class ChatPollCreate(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    options: List[str] = Field(min_length=2, max_length=10)
    allows_multiple: bool = False
    closes_at: Optional[datetime] = None
    client_message_id: Optional[str] = None


class ChatPollVoteCreate(BaseModel):
    option_ids: List[UUID] = Field(min_length=1, max_length=10)


class ChatPollOptionRead(BaseModel):
    id: UUID
    label: str
    position: int
    votes_count: int = 0
    current_user_voted: bool = False


class ChatPollRead(BaseModel):
    id: UUID
    message_id: UUID
    question: str
    allows_multiple: bool
    closes_at: Optional[datetime] = None
    is_closed: bool = False
    total_votes: int = 0
    total_voters: int = 0
    options: List[ChatPollOptionRead] = Field(default_factory=list)

class ChatMessageCreate(BaseModel):
    content: str
    client_message_id: Optional[str] = None
    message_type: str = "text"
    attachment_file_id: Optional[UUID] = None
    attachment_url: Optional[str] = None
    attachment_name: Optional[str] = None
    attachment_mime_type: Optional[str] = None
    attachment_size_bytes: Optional[int] = None
    duration_seconds: Optional[int] = None
    thumbnail_url: Optional[str] = None
    sticker_pack: Optional[str] = None


class ChatMessageRead(BaseModel):
    id: UUID
    thread_id: UUID
    author_id: UUID
    client_message_id: Optional[str] = None
    content: str
    message_type: str
    created_at: datetime
    edited_at: Optional[datetime]
    deleted_at: Optional[datetime]
    attachment_file_id: Optional[UUID] = None
    attachment_url: Optional[str] = None
    attachment_name: Optional[str] = None
    attachment_mime_type: Optional[str] = None
    attachment_size_bytes: Optional[int] = None
    duration_seconds: Optional[int] = None
    thumbnail_url: Optional[str] = None
    sticker_pack: Optional[str] = None
    reactions_count: int = 0
    reactions_summary: dict[str, int] = Field(default_factory=dict)
    current_user_reaction: Optional[str] = None
    poll: Optional[ChatPollRead] = None

    class Config:
        from_attributes = True


class ChatMessageReactionCreate(BaseModel):
    reaction_type: str


class ChatMessageReactionRead(BaseModel):
    id: UUID
    message_id: UUID
    user_id: UUID
    reaction_type: str
    created_at: datetime

    class Config:
        from_attributes = True


class ChatUploadCreate(BaseModel):
    file_name: str
    content_type: Optional[str] = None
    data_base64: str
    message_type: str = "document"
    thread_id: Optional[UUID] = None


class ChatUploadRead(BaseModel):
    file_id: Optional[UUID] = None
    url: str
    file_name: str
    content_type: Optional[str]
    size_bytes: int
    message_type: str


class ChatParticipantsUpdate(BaseModel):
    user_ids: List[UUID]


class ChatParticipantRoleUpdate(BaseModel):
    participant_role: str
