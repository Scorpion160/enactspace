from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class AttendanceSessionCreate(BaseModel):
    title: str
    description: Optional[str] = None
    session_type: str = "general_meeting"
    scope_type: str = "club"
    group_name: Optional[str] = None
    event_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    scheduled_at: Optional[datetime] = None
    checkin_start: Optional[datetime] = None
    checkin_end: Optional[datetime] = None
    late_after_minutes: int = 15
    qr_token: Optional[str] = None
    status: str = "draft"
    notes: Optional[str] = None


class AttendanceSessionUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    session_type: Optional[str] = None
    scope_type: Optional[str] = None
    group_name: Optional[str] = None
    event_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    scheduled_at: Optional[datetime] = None
    checkin_start: Optional[datetime] = None
    checkin_end: Optional[datetime] = None
    late_after_minutes: Optional[int] = None
    status: Optional[str] = None
    notes: Optional[str] = None


class AttendanceSessionRead(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    session_type: str
    scope_type: str = "club"
    group_name: Optional[str] = None
    status: str = "draft"
    event_id: Optional[UUID]
    pole_id: Optional[UUID]
    project_id: Optional[UUID]
    scheduled_at: Optional[datetime]
    checkin_start: Optional[datetime]
    checkin_end: Optional[datetime]
    late_after_minutes: int
    qr_token: Optional[str]
    created_by: Optional[UUID]
    is_closed: bool
    notes: Optional[str] = None
    can_manage: bool = False
    expected_count: int = 0
    recorded_count: int = 0
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AttendanceExpectedMemberCreate(BaseModel):
    session_id: UUID
    user_id: UUID
    is_required: bool = True


class AttendanceExpectedMemberRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    is_required: bool
    created_at: datetime

    class Config:
        from_attributes = True


class AttendanceCheckIn(BaseModel):
    session_id: UUID
    qr_token: str


class AttendanceManualCreate(BaseModel):
    session_id: UUID
    user_id: UUID
    status: str
    arrival_time: Optional[datetime] = None
    delay_minutes: Optional[int] = None
    justification: Optional[str] = None
    justification_status: Optional[str] = None
    justification_reason: Optional[str] = None
    justification_file_id: Optional[UUID] = None
    justification_file_url: Optional[str] = None
    note: Optional[str] = None


class AttendanceRecordCreate(BaseModel):
    user_id: UUID
    status: str
    arrival_time: Optional[datetime] = None
    delay_minutes: Optional[int] = None
    justification: Optional[str] = None
    justification_status: Optional[str] = None
    justification_reason: Optional[str] = None
    justification_file_id: Optional[UUID] = None
    justification_file_url: Optional[str] = None
    note: Optional[str] = None


class AttendanceRecordUpdate(BaseModel):
    status: Optional[str] = None
    arrival_time: Optional[datetime] = None
    delay_minutes: Optional[int] = None
    justification: Optional[str] = None
    justification_status: Optional[str] = None
    justification_reason: Optional[str] = None
    justification_file_id: Optional[UUID] = None
    justification_file_url: Optional[str] = None
    note: Optional[str] = None


class AttendanceRecordRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    member_id: UUID
    status: str
    checkin_time: Optional[datetime]
    arrival_time: Optional[datetime]
    delay_minutes: Optional[int] = None
    recorded_by: Optional[UUID]
    recorded_at: Optional[datetime] = None
    justification: Optional[str]
    justification_status: str = "not_submitted"
    justification_reason: Optional[str] = None
    justification_file_id: Optional[UUID] = None
    justification_file_url: Optional[str]
    is_justified: bool
    penalty_amount: float
    penalty_fee_id: Optional[UUID]
    note: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Alias pour compatibilité avec attendance.py
AttendanceExpectedMembersCreate = AttendanceExpectedMemberCreate
AttendanceRead = AttendanceRecordRead
