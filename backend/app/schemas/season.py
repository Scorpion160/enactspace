from pydantic import BaseModel, Field, model_validator
from uuid import UUID
from datetime import date, datetime
from typing import Optional


class SeasonCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    start_date: date
    end_date: Optional[date] = None
    is_current: bool = False

    @model_validator(mode="after")
    def dates_and_name(self):
        self.name = self.name.strip()
        if not self.name:
            raise ValueError("Donnez un nom à l’année.")
        if self.end_date and self.end_date <= self.start_date:
            raise ValueError("La fin doit suivre le début de l’année.")
        return self


class YearActivation(BaseModel):
    expected_current_id: Optional[UUID] = None


class SeasonRead(BaseModel):
    id: UUID
    name: str
    start_date: date
    end_date: Optional[date]
    is_current: bool
    archived: bool
    created_at: datetime

    class Config:
        from_attributes = True