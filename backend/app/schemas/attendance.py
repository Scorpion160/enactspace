from pydantic import BaseModel
from uuid import UUID
from datetime import datetime
from typing import Optional


class AttendanceSessionCreate(BaseModel):
    title: str
    description: Optional[str] = None
    session_type: str = "general_meeting"
    event_id: Optional[UUID] = None
    pole_id: Optional[UUID] = None
    project_id: Optional[UUID] = None
    scheduled_at: Optional[datetime] = None
    checkin_start: Optional[datetime] = None
    checkin_end: Optional[datetime] = None
    late_after_minutes: int = 15
    qr_token: Optional[str] = None


class AttendanceSessionRead(BaseModel):
    id: UUID
    title: str
    description: Optional[str]
    session_type: str
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
    can_manage: bool = False
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
    justification: Optional[str] = None
    justification_file_url: Optional[str] = None
    note: Optional[str] = None



class AttendanceRecordRead(BaseModel):
    id: UUID
    session_id: UUID
    user_id: UUID
    status: str
    checkin_time: Optional[datetime]
    recorded_by: Optional[UUID]
    justification: Optional[str]
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
