from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class PostCreate(BaseModel):
    title: Optional[str] = None
    content: str
    post_type: str = "general"
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    event_id: Optional[UUID] = None
    document_id: Optional[UUID] = None
    media_file_id: Optional[UUID] = None
    is_official: bool = False
    visibility: str = "internal"


class PostUpdate(BaseModel):
    title: Optional[str] = None
    content: Optional[str] = None
    post_type: Optional[str] = None
    visibility: Optional[str] = None
    media_file_id: Optional[UUID] = None
    is_official: Optional[bool] = None
    is_pinned: Optional[bool] = None


class PostRead(BaseModel):
    id: UUID
    author_id: UUID
    title: Optional[str]
    content: str
    post_type: str
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    event_id: Optional[UUID]
    document_id: Optional[UUID]
    media_file_id: Optional[UUID]
    media_url: Optional[str]
    media_name: Optional[str]
    media_mime_type: Optional[str]
    media_size_bytes: Optional[int]
    is_official: bool
    is_pinned: bool
    visibility: str
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class PostCommentCreate(BaseModel):
    post_id: UUID
    content: str


class PostUploadCreate(BaseModel):
    file_name: str
    content_type: Optional[str] = None
    data_base64: str


class PostUploadRead(BaseModel):
    file_id: UUID
    url: str
    file_name: str
    content_type: Optional[str]
    size_bytes: int


class PostCommentRead(BaseModel):
    id: UUID
    post_id: UUID
    user_id: UUID
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class PostReactionCreate(BaseModel):
    post_id: UUID
    reaction_type: str = "like"


class PostReactionRead(BaseModel):
    id: UUID
    post_id: UUID
    user_id: UUID
    reaction_type: str
    created_at: datetime

    class Config:
        from_attributes = True


class PostStatsRead(BaseModel):
    post_id: UUID
    comments_count: int
    reactions_count: int
