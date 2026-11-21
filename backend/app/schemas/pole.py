from pydantic import Field, field_validator, model_validator, BaseModel
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class PoleCreate(BaseModel):
    season_id: Optional[UUID] = None
    name: str = Field(min_length=1, max_length=100)
    short_name: Optional[str] = Field(default=None, max_length=50)
    type: str = Field(min_length=1, max_length=50)
    description: Optional[str] = None
    objectives: Optional[str] = None


    @field_validator("name", "type", mode="before")
    @classmethod
    def trim_required_text(cls, value):
        return value.strip() if isinstance(value, str) else value

class PoleUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    short_name: Optional[str] = Field(default=None, max_length=50)
    type: Optional[str] = Field(default=None, min_length=1, max_length=50)
    description: Optional[str] = None
    objectives: Optional[str] = None


    @field_validator("name", "type", mode="before")
    @classmethod
    def trim_required_text(cls, value):
        return value.strip() if isinstance(value, str) else value

    @model_validator(mode="after")
    def reject_null_required_fields(self):
        for name in ['name', 'type']:
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError("Ce champ ne peut pas être vide")
        return self

class PoleRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    name: str
    short_name: Optional[str]
    type: str
    description: Optional[str]
    objectives: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class PoleMemberAssign(BaseModel):
    user_id: UUID
    position: str = "membre"


class PoleMemberRead(BaseModel):
    id: UUID
    pole_id: UUID
    user_id: UUID
    position: str
    joined_at: date
    left_at: Optional[date]
    is_active: bool

    class Config:
        from_attributes = True


class PoleMemberDirectoryRead(BaseModel):
    id: UUID
    first_name: str
    last_name: str
    email: str
    photo_url: Optional[str] = None
    department: Optional[str] = None
    status: str
    core_pole_id: UUID
    pole_position: str
    roles: list[str] = []
