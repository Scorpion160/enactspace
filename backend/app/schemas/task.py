from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional, List


class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    priority: str = "normale"
    due_date: Optional[datetime] = None
    proof_required: bool = True
    assignee_ids: List[UUID] = []


class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    due_date: Optional[datetime] = None
    proof_required: Optional[bool] = None
    proof_url: Optional[str] = None


class TaskRead(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    creator_id: Optional[UUID]
    assigned_by: Optional[UUID]
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    priority: str
    status: str
    due_date: Optional[datetime]
    completed_at: Optional[datetime]
    validated_at: Optional[datetime]
    validated_by: Optional[UUID]
    proof_required: bool
    proof_url: Optional[str]
    is_late_alert_sent: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TaskAssigneeCreate(BaseModel):
    task_id: UUID
    user_ids: List[UUID]


class TaskAssigneeRead(BaseModel):
    id: UUID
    task_id: UUID
    user_id: UUID
    assigned_at: datetime

    class Config:
        from_attributes = True


class TaskChecklistItemCreate(BaseModel):
    task_id: UUID
    title: str


class TaskChecklistItemUpdate(BaseModel):
    title: Optional[str] = None
    is_done: Optional[bool] = None


class TaskChecklistItemRead(BaseModel):
    id: UUID
    task_id: UUID
    title: str
    is_done: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class TaskCommentCreate(BaseModel):
    task_id: UUID
    content: str


class TaskCommentRead(BaseModel):
    id: UUID
    task_id: UUID
    user_id: UUID
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


class TaskProofSubmit(BaseModel):
    proof_url: str


class TaskStatusChange(BaseModel):
    status: str