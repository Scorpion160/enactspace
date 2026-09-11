from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, model_validator


MemoryValidationStatus = Literal[
    "HISTORICAL_REPORTED",
    "EVIDENCE_PENDING",
    "EVIDENCE_ATTACHED",
    "UNDER_REVIEW",
    "VERIFIED",
    "REJECTED",
    "SUPERSEDED",
]
MemoryVisibility = Literal["private", "internal"]
RelationshipType = Literal[
    "renamed_from",
    "continued_as",
    "merged_into",
    "split_from",
    "inspired_by",
    "technology_transferred_to",
    "other",
]


class MemorySchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


class MemoryFactCreate(MemorySchema):
    source_id: UUID | None = None
    validation_status: MemoryValidationStatus = "HISTORICAL_REPORTED"


class MemoryFactUpdate(MemorySchema):
    source_id: UUID | None = None
    validation_status: MemoryValidationStatus | None = None


class MemoryReadMetadata(MemorySchema):
    id: UUID
    created_by_id: UUID | None
    validated_by_id: UUID | None
    validated_at: datetime | None
    created_at: datetime
    updated_at: datetime


def _validate_year_range(start_year: int | None, end_year: int | None) -> None:
    if start_year is not None and end_year is not None and end_year < start_year:
        raise ValueError("end_year must be greater than or equal to start_year")


class InstitutionalSourceCreate(MemorySchema):
    source_type: str = Field(min_length=1, max_length=50)
    title: str = Field(min_length=1, max_length=220)
    document_id: UUID | None = None
    file_id: UUID | None = None
    external_url: str | None = None
    source_label: str | None = Field(default=None, max_length=220)
    publication_date: date | None = None
    year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None
    visibility: MemoryVisibility = "internal"
    validation_status: MemoryValidationStatus = "HISTORICAL_REPORTED"

    @model_validator(mode="after")
    def validate_source(self):
        if not any(
            (
                self.document_id,
                self.file_id,
                (self.external_url or "").strip(),
                (self.source_label or "").strip(),
            )
        ):
            raise ValueError("A source requires a document, file, URL, or source label")
        if self.publication_date and self.year and self.publication_date.year != self.year:
            raise ValueError("publication_date and year must be coherent")
        return self


class InstitutionalSourceUpdate(MemorySchema):
    source_type: str | None = Field(default=None, min_length=1, max_length=50)
    title: str | None = Field(default=None, min_length=1, max_length=220)
    document_id: UUID | None = None
    file_id: UUID | None = None
    external_url: str | None = None
    source_label: str | None = Field(default=None, max_length=220)
    publication_date: date | None = None
    year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None
    visibility: MemoryVisibility | None = None
    validation_status: MemoryValidationStatus | None = None


class InstitutionalSourceRead(InstitutionalSourceCreate, MemoryReadMetadata):
    pass


class TerritoryCreate(MemoryFactCreate):
    name: str = Field(min_length=1, max_length=180)
    place_type: str = Field(min_length=1, max_length=60)
    country: str = Field(min_length=1, max_length=120)
    region: str | None = Field(default=None, max_length=160)
    department_or_locality: str | None = Field(default=None, max_length=180)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    notes: str | None = None


class TerritoryUpdate(MemoryFactUpdate):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    place_type: str | None = Field(default=None, min_length=1, max_length=60)
    country: str | None = Field(default=None, min_length=1, max_length=120)
    region: str | None = Field(default=None, max_length=160)
    department_or_locality: str | None = Field(default=None, max_length=180)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    notes: str | None = None


class TerritoryRead(TerritoryCreate, MemoryReadMetadata):
    pass


class InstitutionalGenerationCreate(MemoryFactCreate):
    name: str = Field(min_length=1, max_length=180)
    start_year: int = Field(ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    description: str | None = None
    status: str = Field(default="historical", min_length=1, max_length=40)

    @model_validator(mode="after")
    def validate_years(self):
        _validate_year_range(self.start_year, self.end_year)
        return self


class InstitutionalGenerationUpdate(MemoryFactUpdate):
    name: str | None = Field(default=None, min_length=1, max_length=180)
    start_year: int | None = Field(default=None, ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    description: str | None = None
    status: str | None = Field(default=None, min_length=1, max_length=40)


class InstitutionalGenerationRead(InstitutionalGenerationCreate, MemoryReadMetadata):
    pass


class CanonicalProjectCreate(MemoryFactCreate):
    canonical_name: str = Field(min_length=1, max_length=180)
    slug: str = Field(min_length=1, max_length=180)
    description: str | None = None
    first_year: int | None = Field(default=None, ge=1000, le=9999)
    last_year: int | None = Field(default=None, ge=1000, le=9999)
    status: str = Field(default="historical", min_length=1, max_length=50)
    current_project_id: UUID | None = None

    @model_validator(mode="after")
    def validate_years(self):
        _validate_year_range(self.first_year, self.last_year)
        return self


class CanonicalProjectUpdate(MemoryFactUpdate):
    canonical_name: str | None = Field(default=None, min_length=1, max_length=180)
    slug: str | None = Field(default=None, min_length=1, max_length=180)
    description: str | None = None
    first_year: int | None = Field(default=None, ge=1000, le=9999)
    last_year: int | None = Field(default=None, ge=1000, le=9999)
    status: str | None = Field(default=None, min_length=1, max_length=50)
    current_project_id: UUID | None = None


class CanonicalProjectRead(CanonicalProjectCreate, MemoryReadMetadata):
    pass


class LeadershipTermCreate(MemoryFactCreate):
    user_id: UUID | None = None
    display_name: str | None = Field(default=None, max_length=180)
    role_label: str = Field(min_length=1, max_length=180)
    pole_id: UUID | None = None
    generation_id: UUID | None = None
    start_year: int = Field(ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    is_current: bool = False
    notes: str | None = None

    @model_validator(mode="after")
    def validate_term(self):
        if self.user_id is None and not (self.display_name or "").strip():
            raise ValueError("A current user or historical display name is required")
        _validate_year_range(self.start_year, self.end_year)
        if self.is_current and self.end_year is not None:
            raise ValueError("A current term cannot have an end_year")
        return self


class LeadershipTermUpdate(MemoryFactUpdate):
    user_id: UUID | None = None
    display_name: str | None = Field(default=None, max_length=180)
    role_label: str | None = Field(default=None, min_length=1, max_length=180)
    pole_id: UUID | None = None
    generation_id: UUID | None = None
    start_year: int | None = Field(default=None, ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    is_current: bool | None = None
    notes: str | None = None


class LeadershipTermRead(LeadershipTermCreate, MemoryReadMetadata):
    pass


class ProjectAliasCreate(MemoryFactCreate):
    canonical_project_id: UUID
    alias: str = Field(min_length=1, max_length=180)
    start_year: int | None = Field(default=None, ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None

    @model_validator(mode="after")
    def validate_years(self):
        _validate_year_range(self.start_year, self.end_year)
        return self


class ProjectAliasUpdate(MemoryFactUpdate):
    canonical_project_id: UUID | None = None
    alias: str | None = Field(default=None, min_length=1, max_length=180)
    start_year: int | None = Field(default=None, ge=1000, le=9999)
    end_year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None


class ProjectAliasRead(ProjectAliasCreate, MemoryReadMetadata):
    pass


class ProjectYearCreate(MemoryFactCreate):
    canonical_project_id: UUID
    year: int = Field(ge=1000, le=9999)
    display_name: str | None = Field(default=None, max_length=180)
    status: str = Field(default="reported", min_length=1, max_length=50)
    problem_summary: str | None = None
    solution_summary: str | None = None
    territory_id: UUID | None = None
    operational_project_id: UUID | None = None
    notes: str | None = None


class ProjectYearUpdate(MemoryFactUpdate):
    canonical_project_id: UUID | None = None
    year: int | None = Field(default=None, ge=1000, le=9999)
    display_name: str | None = Field(default=None, max_length=180)
    status: str | None = Field(default=None, min_length=1, max_length=50)
    problem_summary: str | None = None
    solution_summary: str | None = None
    territory_id: UUID | None = None
    operational_project_id: UUID | None = None
    notes: str | None = None


class ProjectYearRead(ProjectYearCreate, MemoryReadMetadata):
    pass


class ProjectRelationshipCreate(MemoryFactCreate):
    source_project_id: UUID
    target_project_id: UUID
    relationship_type: RelationshipType
    year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None

    @model_validator(mode="after")
    def validate_projects(self):
        if self.source_project_id == self.target_project_id:
            raise ValueError("A project relationship cannot reference itself")
        return self


class ProjectRelationshipUpdate(MemoryFactUpdate):
    source_project_id: UUID | None = None
    target_project_id: UUID | None = None
    relationship_type: RelationshipType | None = None
    year: int | None = Field(default=None, ge=1000, le=9999)
    notes: str | None = None


class ProjectRelationshipRead(ProjectRelationshipCreate, MemoryReadMetadata):
    pass


class InstitutionalEventCreate(MemoryFactCreate):
    title: str = Field(min_length=1, max_length=220)
    event_type: str = Field(min_length=1, max_length=60)
    event_date: date | None = None
    year: int = Field(ge=1000, le=9999)
    end_date: date | None = None
    description: str | None = None
    territory_id: UUID | None = None
    canonical_project_id: UUID | None = None
    generation_id: UUID | None = None
    visibility: MemoryVisibility = "internal"
    status: str = Field(default="reported", min_length=1, max_length=40)

    @model_validator(mode="after")
    def validate_dates(self):
        if self.event_date and self.event_date.year != self.year:
            raise ValueError("event_date and year must be coherent")
        if self.end_date and self.event_date and self.end_date < self.event_date:
            raise ValueError("end_date must follow event_date")
        return self


class InstitutionalEventUpdate(MemoryFactUpdate):
    title: str | None = Field(default=None, min_length=1, max_length=220)
    event_type: str | None = Field(default=None, min_length=1, max_length=60)
    event_date: date | None = None
    year: int | None = Field(default=None, ge=1000, le=9999)
    end_date: date | None = None
    description: str | None = None
    territory_id: UUID | None = None
    canonical_project_id: UUID | None = None
    generation_id: UUID | None = None
    visibility: MemoryVisibility | None = None
    status: str | None = Field(default=None, min_length=1, max_length=40)


class InstitutionalEventRead(InstitutionalEventCreate, MemoryReadMetadata):
    origin: Literal["manual", "operational"] = "manual"
    capture_key: str | None = None
    source_entity_type: str | None = None
    source_entity_id: UUID | None = None
    source_entity_version: str | None = None
    captured_at: datetime | None = None
    operational_project_id: UUID | None = None
    pole_id: UUID | None = None
    operational_event_id: UUID | None = None


class InstitutionalFrameworkCreate(MemoryFactCreate):
    name: str = Field(min_length=1, max_length=220)
    description: str | None = None
    framework_type: str = Field(min_length=1, max_length=80)
    version_label: str = Field(min_length=1, max_length=100)
    effective_from_year: int = Field(ge=1000, le=9999)
    effective_to_year: int | None = Field(default=None, ge=1000, le=9999)
    steps: list | dict = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_years(self):
        _validate_year_range(self.effective_from_year, self.effective_to_year)
        return self


class InstitutionalFrameworkUpdate(MemoryFactUpdate):
    name: str | None = Field(default=None, min_length=1, max_length=220)
    description: str | None = None
    framework_type: str | None = Field(default=None, min_length=1, max_length=80)
    version_label: str | None = Field(default=None, min_length=1, max_length=100)
    effective_from_year: int | None = Field(default=None, ge=1000, le=9999)
    effective_to_year: int | None = Field(default=None, ge=1000, le=9999)
    steps: list | dict | None = None


class InstitutionalFrameworkRead(InstitutionalFrameworkCreate, MemoryReadMetadata):
    pass


class CompetitionRecordMemoryCreate(MemoryFactCreate):
    name: str = Field(min_length=1, max_length=220)
    year: int = Field(ge=1000, le=9999)
    stage: str | None = Field(default=None, max_length=140)
    result: str | None = Field(default=None, max_length=180)
    location: str | None = Field(default=None, max_length=180)
    territory_id: UUID | None = None
    description: str | None = None
    file_id: UUID | None = None
    is_featured: bool = False


class CompetitionRecordMemoryUpdate(MemoryFactUpdate):
    name: str | None = Field(default=None, min_length=1, max_length=220)
    year: int | None = Field(default=None, ge=1000, le=9999)
    stage: str | None = Field(default=None, max_length=140)
    result: str | None = Field(default=None, max_length=180)
    location: str | None = Field(default=None, max_length=180)
    territory_id: UUID | None = None
    description: str | None = None
    file_id: UUID | None = None
    is_featured: bool | None = None


class CompetitionRecordMemoryRead(CompetitionRecordMemoryCreate, MemoryReadMetadata):
    archive_item_id: UUID | None


class CompetitionParticipationCreate(MemoryFactCreate):
    competition_record_id: UUID
    participant_scope: Literal["organization", "project"]
    canonical_project_id: UUID | None = None
    stage: str | None = Field(default=None, max_length=140)
    result: str | None = Field(default=None, max_length=180)

    @model_validator(mode="after")
    def validate_participant(self):
        if self.participant_scope == "organization" and self.canonical_project_id:
            raise ValueError("Organization participation cannot name a project")
        if self.participant_scope == "project" and not self.canonical_project_id:
            raise ValueError("Project participation requires a canonical project")
        return self


class CompetitionParticipationUpdate(MemoryFactUpdate):
    competition_record_id: UUID | None = None
    participant_scope: Literal["organization", "project"] | None = None
    canonical_project_id: UUID | None = None
    stage: str | None = Field(default=None, max_length=140)
    result: str | None = Field(default=None, max_length=180)


class CompetitionParticipationRead(CompetitionParticipationCreate, MemoryReadMetadata):
    pass


class AwardMemoryCreate(MemoryFactCreate):
    title: str = Field(min_length=1, max_length=220)
    year: int | None = Field(default=None, ge=1000, le=9999)
    competition: str | None = Field(default=None, max_length=180)
    competition_record_id: UUID | None = None
    canonical_project_id: UUID | None = None
    rank: str | None = Field(default=None, max_length=120)
    result: str | None = Field(default=None, max_length=180)
    description: str | None = None
    file_id: UUID | None = None
    media_url: str | None = None
    is_featured: bool = False


class AwardMemoryUpdate(MemoryFactUpdate):
    title: str | None = Field(default=None, min_length=1, max_length=220)
    year: int | None = Field(default=None, ge=1000, le=9999)
    competition: str | None = Field(default=None, max_length=180)
    competition_record_id: UUID | None = None
    canonical_project_id: UUID | None = None
    rank: str | None = Field(default=None, max_length=120)
    result: str | None = Field(default=None, max_length=180)
    description: str | None = None
    file_id: UUID | None = None
    media_url: str | None = None
    is_featured: bool | None = None


class AwardMemoryRead(AwardMemoryCreate, MemoryReadMetadata):
    archive_item_id: UUID | None
    archived_project_id: UUID | None


class MemoryValidationRequest(MemorySchema):
    reason: str | None = None
