from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class ArchiveItemCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str = "Autre"
    year: Optional[int] = None
    season_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    document_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    visibility: str = "interne"
    status: str = "draft"
    is_featured: bool = False
    is_public: bool = False
    source_label: Optional[str] = None
    source_url: Optional[str] = None
    tags: list[str] = Field(default_factory=list)
    metadata_json: dict = Field(default_factory=dict)


class ArchiveItemUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    year: Optional[int] = None
    season_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    document_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    visibility: Optional[str] = None
    status: Optional[str] = None
    is_featured: Optional[bool] = None
    is_public: Optional[bool] = None
    source_label: Optional[str] = None
    source_url: Optional[str] = None
    tags: Optional[list[str]] = None
    metadata_json: Optional[dict] = None


class ArchiveItemRead(ArchiveItemCreate):
    id: UUID
    created_by_id: Optional[UUID]
    validated_by_id: Optional[UUID]
    validated_at: Optional[datetime]
    rejected_by_id: Optional[UUID]
    rejected_at: Optional[datetime]
    rejection_reason: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class ArchivedProjectCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    name: str
    year: Optional[int] = None
    season_label: Optional[str] = None
    description: Optional[str] = None
    problem: Optional[str] = None
    solution: Optional[str] = None
    impact_summary: Optional[str] = None
    status: str = "historique"
    linked_project_id: Optional[UUID] = None
    key_members: list[str] = Field(default_factory=list)
    awards: list[str] = Field(default_factory=list)
    document_ids: list[str] = Field(default_factory=list)
    media_file_ids: list[str] = Field(default_factory=list)


class ArchivedProjectUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    name: Optional[str] = None
    year: Optional[int] = None
    season_label: Optional[str] = None
    description: Optional[str] = None
    problem: Optional[str] = None
    solution: Optional[str] = None
    impact_summary: Optional[str] = None
    status: Optional[str] = None
    linked_project_id: Optional[UUID] = None
    key_members: Optional[list[str]] = None
    awards: Optional[list[str]] = None
    document_ids: Optional[list[str]] = None
    media_file_ids: Optional[list[str]] = None


class ArchivedProjectRead(ArchivedProjectCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AwardCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: str
    year: Optional[int] = None
    competition: Optional[str] = None
    rank: Optional[str] = None
    result: Optional[str] = None
    description: Optional[str] = None
    archived_project_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    media_url: Optional[str] = None
    is_featured: bool = False


class AwardUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: Optional[str] = None
    year: Optional[int] = None
    competition: Optional[str] = None
    rank: Optional[str] = None
    result: Optional[str] = None
    description: Optional[str] = None
    archived_project_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    media_url: Optional[str] = None
    is_featured: Optional[bool] = None


class AwardRead(AwardCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class CompetitionRecordCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    name: str
    year: Optional[int] = None
    stage: Optional[str] = None
    result: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    project_ids: list[str] = Field(default_factory=list)
    award_ids: list[str] = Field(default_factory=list)
    file_id: Optional[UUID] = None
    is_featured: bool = False


class CompetitionRecordUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    name: Optional[str] = None
    year: Optional[int] = None
    stage: Optional[str] = None
    result: Optional[str] = None
    location: Optional[str] = None
    description: Optional[str] = None
    project_ids: Optional[list[str]] = None
    award_ids: Optional[list[str]] = None
    file_id: Optional[UUID] = None
    is_featured: Optional[bool] = None


class CompetitionRecordRead(CompetitionRecordCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class MediaArchiveCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: str
    media_type: str = "image"
    year: Optional[int] = None
    description: Optional[str] = None
    file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    source_label: Optional[str] = None
    archived_project_id: Optional[UUID] = None
    is_featured: bool = False


class MediaArchiveUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: Optional[str] = None
    media_type: Optional[str] = None
    year: Optional[int] = None
    description: Optional[str] = None
    file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    source_label: Optional[str] = None
    archived_project_id: Optional[UUID] = None
    is_featured: Optional[bool] = None


class MediaArchiveRead(MediaArchiveCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class HistoricalDocumentCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: str
    document_type: str = "Document officiel"
    year: Optional[int] = None
    description: Optional[str] = None
    document_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    source_label: Optional[str] = None
    visibility: str = "interne"
    is_featured: bool = False


class HistoricalDocumentUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: Optional[str] = None
    document_type: Optional[str] = None
    year: Optional[int] = None
    description: Optional[str] = None
    document_id: Optional[UUID] = None
    file_id: Optional[UUID] = None
    source_label: Optional[str] = None
    visibility: Optional[str] = None
    is_featured: Optional[bool] = None


class HistoricalDocumentRead(HistoricalDocumentCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class HallOfFameEntryCreate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: str
    subtitle: Optional[str] = None
    entry_type: str = "Moment fort"
    year: Optional[int] = None
    description: Optional[str] = None
    score_value: Optional[float] = None
    score_label: Optional[str] = None
    file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    order_index: int = 0
    is_featured: bool = True


class HallOfFameEntryUpdate(BaseModel):
    archive_item_id: Optional[UUID] = None
    title: Optional[str] = None
    subtitle: Optional[str] = None
    entry_type: Optional[str] = None
    year: Optional[int] = None
    description: Optional[str] = None
    score_value: Optional[float] = None
    score_label: Optional[str] = None
    file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    order_index: Optional[int] = None
    is_featured: Optional[bool] = None


class HallOfFameEntryRead(HallOfFameEntryCreate):
    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class HistoricalImpactStatisticCreate(BaseModel):
    metric_key: str
    label: str
    value: float = 0
    unit: Optional[str] = None
    description: Optional[str] = None
    source_label: Optional[str] = None
    source_file_id: Optional[UUID] = None
    status: str = "validated"
    is_featured: bool = True


class HistoricalImpactStatisticUpdate(BaseModel):
    label: Optional[str] = None
    value: Optional[float] = None
    unit: Optional[str] = None
    description: Optional[str] = None
    source_label: Optional[str] = None
    source_file_id: Optional[UUID] = None
    status: Optional[str] = None
    is_featured: Optional[bool] = None


class HistoricalImpactStatisticRead(HistoricalImpactStatisticCreate):
    id: UUID
    updated_by_id: Optional[UUID]
    validated_by_id: Optional[UUID]
    validated_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
