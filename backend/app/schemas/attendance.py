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


class AttendanceSettingRead(BaseModel):
    key: str
    value: str
    description: Optional[str] = None


class AttendanceSettingsUpdate(BaseModel):
    montant_absence_non_justifiee: Optional[float] = None
    montant_retard: Optional[float] = None
    seuil_avertissement_absences: Optional[int] = None
    seuil_retards: Optional[int] = None
    delai_max_justification: Optional[int] = None
    debut_application_sanctions: Optional[datetime] = None


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


class AttendanceJustificationSubmit(BaseModel):
    reason: str
    file_id: Optional[UUID] = None
    file_url: Optional[str] = None


class AttendanceJustificationReview(BaseModel):
    reason: Optional[str] = None


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
    source: str = "manual"
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


class AttendanceQrTokenRead(BaseModel):
    token: str
    expires_at: datetime
    rotation_seconds: int
    session_id: UUID


class AttendanceQrStatusRead(BaseModel):
    qr_enabled: bool
    session_id: UUID
    session_status: str
    expected_count: int
    present_count: int
    late_count: int
    remaining_count: int
    last_scan_at: Optional[datetime] = None
    last_scan_status: Optional[str] = None


class AttendanceQrScanRequest(BaseModel):
    token: str


class AttendanceQrScanResult(BaseModel):
    success: bool
    result: str
    attendance_status: Optional[str] = None
    message: str
    recorded_at: Optional[datetime] = None


class AttendanceNfcTagEnrollRequest(BaseModel):
    member_id: UUID
    tag_payload: str
    label: Optional[str] = "Badge principal"
    tag_type: str = "nfc_uid"
    replace_existing: bool = True


class AttendanceNfcTagRead(BaseModel):
    id: UUID
    member_id: UUID
    tag_label: Optional[str] = None
    tag_type: str
    status: str
    masked_tag: str
    assigned_by_id: Optional[UUID] = None
    assigned_at: datetime
    revoked_by_id: Optional[UUID] = None
    revoked_at: Optional[datetime] = None
    last_used_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class AttendanceNfcTagRevokeRequest(BaseModel):
    status: str = "revoked"


class AttendanceNfcTagReplaceRequest(BaseModel):
    tag_payload: str
    label: Optional[str] = "Badge principal"
    tag_type: str = "nfc_uid"


class AttendanceNfcCheckInRequest(BaseModel):
    session_id: UUID
    tag_payload: str


class AttendanceNfcCheckInResult(BaseModel):
    success: bool
    result: str
    member_display_name: Optional[str] = None
    attendance_status: Optional[str] = None
    message: str
    recorded_at: Optional[datetime] = None
