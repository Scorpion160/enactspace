from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field


class AcademyCourseCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category: str = "Vie interne Enactus ESP"
    level: str = "debutant"
    target_roles: list[str] = Field(default_factory=list)
    estimated_duration_minutes: int = 0
    points: int = 0
    is_required: bool = False
    is_published: bool = False
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None


class AcademyCourseUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    level: Optional[str] = None
    target_roles: Optional[list[str]] = None
    estimated_duration_minutes: Optional[int] = None
    points: Optional[int] = None
    is_required: Optional[bool] = None
    is_published: Optional[bool] = None
    is_archived: Optional[bool] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None


class AcademyCourseRead(AcademyCourseCreate):
    id: UUID
    is_archived: bool
    created_by_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AcademyLessonCreate(BaseModel):
    title: str
    summary: Optional[str] = None
    content: Optional[str] = None
    lesson_type: str = "texte"
    order_index: int = 0
    duration_minutes: int = 0
    resource_file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    is_published: bool = True


class AcademyLessonUpdate(BaseModel):
    title: Optional[str] = None
    summary: Optional[str] = None
    content: Optional[str] = None
    lesson_type: Optional[str] = None
    order_index: Optional[int] = None
    duration_minutes: Optional[int] = None
    resource_file_id: Optional[UUID] = None
    external_url: Optional[str] = None
    is_published: Optional[bool] = None


class AcademyLessonRead(AcademyLessonCreate):
    id: UUID
    course_id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AcademyQuestionCreate(BaseModel):
    question_type: str = "single_choice"
    prompt: str
    choices: list[str] = Field(default_factory=list)
    correct_answers: list[int] = Field(default_factory=list)
    explanation: Optional[str] = None
    points: float = 1
    order_index: int = 0


class AcademyQuestionRead(AcademyQuestionCreate):
    id: UUID
    quiz_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True


class AcademyQuizCreate(BaseModel):
    course_id: Optional[UUID] = None
    lesson_id: Optional[UUID] = None
    title: str
    description: Optional[str] = None
    passing_score: float = 60
    time_limit_minutes: int = 8
    allow_retake: bool = True
    is_published: bool = False


class AcademyQuizRead(AcademyQuizCreate):
    id: UUID
    created_by_id: Optional[UUID]
    created_at: datetime
    updated_at: datetime
    questions: list[AcademyQuestionRead] = Field(default_factory=list)

    class Config:
        from_attributes = True


class AcademyProgressRead(BaseModel):
    id: UUID
    user_id: UUID
    course_id: UUID
    lesson_id: Optional[UUID]
    status: str
    progress_percent: float
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    updated_at: datetime

    class Config:
        from_attributes = True


class AcademyQuizSubmit(BaseModel):
    answers: list = Field(default_factory=list)


class AcademyQuizAttemptRead(BaseModel):
    id: UUID
    quiz_id: UUID
    user_id: UUID
    score: float
    max_score: float
    passed: bool
    attempt_number: int
    started_at: datetime
    submitted_at: Optional[datetime]

    class Config:
        from_attributes = True


class AcademyCertificateRead(BaseModel):
    id: UUID
    course_id: UUID
    user_id: UUID
    certificate_code: str
    issued_at: datetime
    file_id: Optional[UUID]

    class Config:
        from_attributes = True
