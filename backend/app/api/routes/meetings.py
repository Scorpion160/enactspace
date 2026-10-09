from datetime import timedelta
from urllib.parse import urlparse
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, HTTPException, status
import jwt
from sqlalchemy.orm import Session

from app.api.deps import (
    get_current_active_validated_user,
    user_has_any_role,
)
from app.core.config import settings
from app.core.roles import ENACCHEF_ROLES, GLOBAL_MANAGEMENT_ROLES
from app.core.time import utc_now
from app.db.database import get_db
from app.models.meeting import Meeting, MeetingMember
from app.models.notification import Notification
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.meeting import (
    MeetingCreate,
    MeetingInviteRequest,
    MeetingJoinRead,
    MeetingMemberRead,
    MeetingRead,
    MeetingUpdate,
)
from app.services.notification_service import create_notifications

router = APIRouter(prefix="/meetings", tags=["Réunions en ligne"])


def _server_url() -> str:
    return settings.MEET_SERVER_URL.rstrip("/")


def _meeting_or_404(db: Session, meeting_id: str) -> Meeting:
    try:
        parsed = UUID(str(meeting_id))
    except ValueError:
        raise HTTPException(status_code=404, detail="Réunion introuvable")
    meeting = db.query(Meeting).filter(Meeting.id == parsed).first()
    if meeting is None:
        raise HTTPException(status_code=404, detail="Réunion introuvable")
    return meeting


def _member(db: Session, meeting: Meeting, user_id) -> MeetingMember | None:
    return db.query(MeetingMember).filter(
        MeetingMember.meeting_id == meeting.id,
        MeetingMember.user_id == user_id,
    ).first()


def _scope_member(db: Session, meeting: Meeting, user_id) -> bool:
    if meeting.scope_type == "club":
        return True
    if meeting.scope_type == "pole" and meeting.scope_id:
        return db.query(PoleMember.id).filter(
            PoleMember.pole_id == meeting.scope_id,
            PoleMember.user_id == user_id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        ).first() is not None
    if meeting.scope_type == "project" and meeting.scope_id:
        return db.query(ProjectMember.id).filter(
            ProjectMember.project_id == meeting.scope_id,
            ProjectMember.user_id == user_id,
            ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
        ).first() is not None
    return False


def _can_access(db: Session, meeting: Meeting, user: User) -> bool:
    if meeting.created_by == user.id:
        return True
    if user_has_any_role(db, user.id, GLOBAL_MANAGEMENT_ROLES):
        return True
    if _member(db, meeting, user.id) is not None:
        return True
    return _scope_member(db, meeting, user.id)


def _can_manage(db: Session, meeting: Meeting, user: User) -> bool:
    if meeting.created_by == user.id:
        return True
    member = _member(db, meeting, user.id)
    if member is not None and member.role in {"host", "cohost"}:
        return True
    return user_has_any_role(db, user.id, GLOBAL_MANAGEMENT_ROLES)


def _can_delete(db: Session, meeting: Meeting, user: User) -> bool:
    return meeting.created_by == user.id or user_has_any_role(
        db, user.id, GLOBAL_MANAGEMENT_ROLES
    )


def _require_access(db: Session, meeting: Meeting, user: User) -> None:
    if not _can_access(db, meeting, user):
        raise HTTPException(status_code=403, detail="Accès à cette réunion refusé")


def _require_manage(db: Session, meeting: Meeting, user: User) -> None:
    if not _can_manage(db, meeting, user):
        raise HTTPException(status_code=403, detail="Gestion de la réunion non autorisée")


def _meeting_payload(db: Session, meeting: Meeting, user: User) -> MeetingRead:
    member = _member(db, meeting, user.id)
    invited_count = db.query(MeetingMember.id).filter(
        MeetingMember.meeting_id == meeting.id
    ).count()
    joined_count = db.query(MeetingMember.id).filter(
        MeetingMember.meeting_id == meeting.id,
        MeetingMember.joined_at.is_not(None),
    ).count()
    return MeetingRead(
        id=meeting.id,
        room_key=meeting.room_key,
        title=meeting.title,
        description=meeting.description,
        status=meeting.status,
        scope_type=meeting.scope_type,
        scope_id=meeting.scope_id,
        provider=meeting.provider,
        server_url=meeting.server_url,
        scheduled_start=meeting.scheduled_start,
        scheduled_end=meeting.scheduled_end,
        started_at=meeting.started_at,
        ended_at=meeting.ended_at,
        created_by=meeting.created_by,
        start_with_audio_muted=meeting.start_with_audio_muted,
        start_with_video_muted=meeting.start_with_video_muted,
        lobby_enabled=meeting.lobby_enabled,
        recording_enabled=meeting.recording_enabled,
        can_manage=_can_manage(db, meeting, user),
        can_delete=_can_delete(db, meeting, user),
        current_user_role=(
            member.role
            if member is not None
            else "host" if meeting.created_by == user.id else "participant"
        ),
        invited_count=invited_count,
        joined_count=joined_count,
        created_at=meeting.created_at,
    )


def _display_name(user: User) -> str:
    value = f"{user.first_name} {user.last_name}".strip()
    return value or user.email


def _make_jitsi_token(meeting: Meeting, user: User, *, moderator: bool) -> str | None:
    if not settings.MEET_JWT_APP_ID or not settings.MEET_JWT_SECRET:
        if settings.MEET_REQUIRE_JWT:
            raise HTTPException(
                status_code=503,
                detail="Authentification du serveur Meet non configurée",
            )
        return None
    now = utc_now()
    subject = settings.MEET_JWT_SUBJECT or urlparse(meeting.server_url).hostname or "*"
    payload = {
        "aud": settings.MEET_JWT_AUDIENCE,
        "iss": settings.MEET_JWT_APP_ID,
        "sub": subject,
        "room": meeting.room_key,
        "nbf": int((now - timedelta(seconds=15)).timestamp()),
        "exp": int((now + timedelta(minutes=settings.MEET_JWT_TTL_MINUTES)).timestamp()),
        "context": {
            "user": {
                "id": str(user.id),
                "name": _display_name(user),
                "email": user.email,
                "avatar": user.photo_url or "",
                "moderator": moderator,
            },
            "features": {
                "recording": bool(meeting.recording_enabled),
                "livestreaming": False,
                "screen-sharing": True,
            },
        },
    }
    return jwt.encode(payload, settings.MEET_JWT_SECRET, algorithm="HS256")


def _add_member(
    db: Session,
    meeting: Meeting,
    user_id,
    *,
    role: str = "participant",
) -> MeetingMember:
    existing = _member(db, meeting, user_id)
    if existing is not None:
        if role in {"host", "cohost"} and existing.role == "participant":
            existing.role = role
        return existing
    row = MeetingMember(meeting_id=meeting.id, user_id=user_id, role=role)
    db.add(row)
    return row


def _scope_user_ids(db: Session, meeting: Meeting) -> set:
    if meeting.scope_type == "club":
        return {
            row.id
            for row in db.query(User.id).filter(
                User.is_active.is_(True),
                User.status.in_({"active", "alumni"}),
            ).all()
        }
    if meeting.scope_type == "pole" and meeting.scope_id:
        return {
            row.user_id
            for row in db.query(PoleMember.user_id).filter(
                PoleMember.pole_id == meeting.scope_id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
            ).all()
        }
    if meeting.scope_type == "project" and meeting.scope_id:
        return {
            row.user_id
            for row in db.query(ProjectMember.user_id).filter(
                ProjectMember.project_id == meeting.scope_id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
            ).all()
        }
    return set()


def _notify(
    db: Session,
    meeting: Meeting,
    user_ids,
    *,
    notification_type: str,
    title: str,
    message: str,
) -> None:
    recipients = [user_id for user_id in dict.fromkeys(user_ids) if user_id != meeting.created_by]
    if not recipients:
        return
    create_notifications(
        db,
        user_ids=recipients,
        title=title,
        message=message,
        notification_type=notification_type,
        related_type="meeting",
        related_id=meeting.id,
    )


@router.get("", response_model=list[MeetingRead])
def list_meetings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    rows = (
        db.query(Meeting)
        .order_by(Meeting.created_at.desc())
        .limit(300)
        .all()
    )
    visible = [row for row in rows if _can_access(db, row, current_user)]
    return [_meeting_payload(db, row, current_user) for row in visible[:100]]


@router.post("", response_model=MeetingRead, status_code=status.HTTP_201_CREATED)
def create_meeting(
    payload: MeetingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.scope_type != "custom" and not user_has_any_role(
        db, current_user.id, ENACCHEF_ROLES
    ):
        raise HTTPException(
            status_code=403,
            detail="Les réunions club/pôle/projet sont réservées aux responsables",
        )

    meeting = Meeting(
        room_key=f"enactspace-{uuid4().hex}",
        title=payload.title.strip(),
        description=payload.description.strip() if payload.description else None,
        scope_type=payload.scope_type,
        scope_id=payload.scope_id,
        server_url=_server_url(),
        scheduled_start=payload.scheduled_start,
        scheduled_end=payload.scheduled_end,
        created_by=current_user.id,
        start_with_audio_muted=payload.start_with_audio_muted,
        start_with_video_muted=payload.start_with_video_muted,
        lobby_enabled=payload.lobby_enabled,
        recording_enabled=settings.MEET_RECORDING_ENABLED,
    )
    db.add(meeting)
    db.flush()
    _add_member(db, meeting, current_user.id, role="host")

    scope_ids = _scope_user_ids(db, meeting)
    explicit_ids = set(payload.invite_user_ids)
    candidate_ids = (scope_ids | explicit_ids) - {current_user.id}
    valid_users = {
        row.id
        for row in db.query(User.id).filter(
            User.id.in_(candidate_ids),
            User.is_active.is_(True),
            User.status.in_({"active", "alumni"}),
        ).all()
    } if candidate_ids else set()
    for user_id in valid_users:
        _add_member(db, meeting, user_id)

    _notify(
        db,
        meeting,
        valid_users,
        notification_type="meeting_invitation",
        title=f"Invitation · {meeting.title}",
        message="Une réunion EnactMeet vous a été proposée. Ouvrez EnactSpace pour consulter les détails et rejoindre la salle.",
    )
    db.commit()
    db.refresh(meeting)
    return _meeting_payload(db, meeting, current_user)


@router.get("/{meeting_id}", response_model=MeetingRead)
def get_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_access(db, meeting, current_user)
    return _meeting_payload(db, meeting, current_user)


@router.patch("/{meeting_id}", response_model=MeetingRead)
def update_meeting(
    meeting_id: str,
    payload: MeetingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_manage(db, meeting, current_user)
    if meeting.status in {"ended", "cancelled"}:
        raise HTTPException(status_code=409, detail="Cette réunion est clôturée")
    changes = payload.model_dump(exclude_unset=True)
    for key, value in changes.items():
        if key in {"title", "description"} and isinstance(value, str):
            value = value.strip()
        setattr(meeting, key, value)
    if meeting.scheduled_end is not None and meeting.scheduled_start is None:
        raise HTTPException(
            status_code=400,
            detail="Le début est obligatoire lorsqu’une fin est définie",
        )
    if (
        meeting.scheduled_start is not None
        and meeting.scheduled_end is not None
        and meeting.scheduled_end <= meeting.scheduled_start
    ):
        raise HTTPException(status_code=400, detail="Planning de réunion invalide")
    meeting.updated_at = utc_now()
    recipient_ids = [
        row.user_id
        for row in db.query(MeetingMember.user_id).filter(
            MeetingMember.meeting_id == meeting.id
        ).all()
    ]
    _notify(
        db,
        meeting,
        recipient_ids,
        notification_type="meeting_updated",
        title=f"Réunion mise à jour · {meeting.title}",
        message="Les informations de cette réunion EnactMeet ont été modifiées.",
    )
    db.commit()
    db.refresh(meeting)
    return _meeting_payload(db, meeting, current_user)


@router.post("/{meeting_id}/invite", response_model=list[MeetingMemberRead])
def invite_members(
    meeting_id: str,
    payload: MeetingInviteRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_manage(db, meeting, current_user)
    if meeting.status in {"ended", "cancelled"}:
        raise HTTPException(status_code=409, detail="Cette réunion est clôturée")
    users = db.query(User).filter(
        User.id.in_(set(payload.user_ids)),
        User.is_active.is_(True),
        User.status.in_({"active", "alumni"}),
    ).all()
    for user in users:
        _add_member(db, meeting, user.id, role=payload.role)
    _notify(
        db,
        meeting,
        [user.id for user in users],
        notification_type="meeting_invitation",
        title=f"Invitation · {meeting.title}",
        message="Vous avez été ajouté à une réunion EnactMeet. Ouvrez EnactSpace pour rejoindre la salle.",
    )
    db.commit()
    return _member_payloads(db, meeting)


def _member_payloads(db: Session, meeting: Meeting) -> list[MeetingMemberRead]:
    rows = (
        db.query(MeetingMember, User)
        .join(User, User.id == MeetingMember.user_id)
        .filter(MeetingMember.meeting_id == meeting.id)
        .order_by(
            User.last_name.asc(),
            User.first_name.asc(),
            User.email.asc(),
        )
        .all()
    )
    return [
        MeetingMemberRead(
            user_id=user.id,
            display_name=_display_name(user),
            first_name=user.first_name,
            last_name=user.last_name,
            role=member.role,
            joined_at=member.joined_at,
            left_at=member.left_at,
        )
        for member, user in rows
    ]


@router.get("/{meeting_id}/members", response_model=list[MeetingMemberRead])
def list_meeting_members(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_access(db, meeting, current_user)
    return _member_payloads(db, meeting)


@router.post("/{meeting_id}/join", response_model=MeetingJoinRead)
def join_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_access(db, meeting, current_user)
    if meeting.status in {"ended", "cancelled"}:
        raise HTTPException(status_code=409, detail="Cette réunion est terminée")

    moderator = _can_manage(db, meeting, current_user)
    now = utc_now()
    if meeting.status == "scheduled" and not moderator:
        if meeting.scheduled_start is None:
            raise HTTPException(
                status_code=409,
                detail="L’hôte doit démarrer cette réunion avant les participants",
            )
        opens_at = meeting.scheduled_start - timedelta(minutes=15)
        if now < opens_at:
            raise HTTPException(
                status_code=409,
                detail="La salle ouvre 15 minutes avant l’horaire prévu",
            )

    _add_member(db, meeting, current_user.id)
    db.commit()
    return MeetingJoinRead(
        meeting_id=meeting.id,
        room_key=meeting.room_key,
        server_url=meeting.server_url,
        jwt=_make_jitsi_token(meeting, current_user, moderator=moderator),
        display_name=_display_name(current_user),
        email=current_user.email,
        avatar_url=current_user.photo_url,
        moderator=moderator,
        start_with_audio_muted=meeting.start_with_audio_muted,
        start_with_video_muted=meeting.start_with_video_muted,
        lobby_enabled=meeting.lobby_enabled,
        recording_enabled=meeting.recording_enabled,
    )


@router.post("/{meeting_id}/entered")
def enter_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_access(db, meeting, current_user)
    if meeting.status in {"ended", "cancelled"}:
        raise HTTPException(status_code=409, detail="Cette réunion est terminée")

    member = _add_member(db, meeting, current_user.id)
    now = utc_now()
    if member.joined_at is None:
        member.joined_at = now
    member.left_at = None
    member.last_seen_at = now

    moderator = _can_manage(db, meeting, current_user)
    became_live = meeting.status == "scheduled" and moderator
    if became_live:
        meeting.status = "live"
        meeting.started_at = meeting.started_at or now
        meeting.updated_at = now
        recipient_ids = [
            row.user_id
            for row in db.query(MeetingMember.user_id).filter(
                MeetingMember.meeting_id == meeting.id,
                MeetingMember.user_id != current_user.id,
            ).all()
        ]
        _notify(
            db,
            meeting,
            recipient_ids,
            notification_type="meeting_started",
            title=f"En direct · {meeting.title}",
            message="La réunion EnactMeet vient de démarrer. Vous pouvez la rejoindre depuis EnactSpace.",
        )

    db.commit()
    return {"ok": True, "status": meeting.status, "started_at": meeting.started_at}


@router.post("/{meeting_id}/leave")
def leave_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_access(db, meeting, current_user)
    member = _member(db, meeting, current_user.id)
    if member is not None and member.joined_at is not None:
        member.left_at = utc_now()
        member.last_seen_at = member.left_at
        db.commit()
    return {"ok": True}


@router.post("/{meeting_id}/end", response_model=MeetingRead)
def end_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_manage(db, meeting, current_user)
    if meeting.status != "live":
        raise HTTPException(
            status_code=409,
            detail="Seule une réunion en direct peut être terminée.",
        )
    now = utc_now()
    meeting.status = "ended"
    meeting.ended_at = now
    meeting.updated_at = now
    db.query(MeetingMember).filter(
        MeetingMember.meeting_id == meeting.id,
        MeetingMember.joined_at.is_not(None),
        MeetingMember.left_at.is_(None),
    ).update({MeetingMember.left_at: now, MeetingMember.last_seen_at: now})
    recipient_ids = [
        row.user_id
        for row in db.query(MeetingMember.user_id).filter(
            MeetingMember.meeting_id == meeting.id
        ).all()
    ]
    _notify(
        db,
        meeting,
        recipient_ids,
        notification_type="meeting_ended",
        title=f"Réunion terminée · {meeting.title}",
        message="Cette réunion EnactMeet est maintenant terminée.",
    )
    db.commit()
    db.refresh(meeting)
    return _meeting_payload(db, meeting, current_user)


@router.post("/{meeting_id}/cancel", response_model=MeetingRead)
def cancel_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    _require_manage(db, meeting, current_user)
    if meeting.status == "ended":
        raise HTTPException(status_code=409, detail="Réunion déjà terminée")
    if meeting.status == "cancelled":
        raise HTTPException(status_code=409, detail="Réunion déjà annulée")
    if meeting.status == "live":
        raise HTTPException(
            status_code=409,
            detail="La réunion est en direct : utilisez Terminer.",
        )
    meeting.status = "cancelled"
    meeting.ended_at = utc_now()
    meeting.updated_at = meeting.ended_at
    recipient_ids = [
        row.user_id
        for row in db.query(MeetingMember.user_id).filter(
            MeetingMember.meeting_id == meeting.id
        ).all()
    ]
    _notify(
        db,
        meeting,
        recipient_ids,
        notification_type="meeting_cancelled",
        title=f"Réunion annulée · {meeting.title}",
        message="Cette réunion EnactMeet a été annulée.",
    )
    db.commit()
    db.refresh(meeting)
    return _meeting_payload(db, meeting, current_user)

@router.delete("/{meeting_id}")
def delete_meeting(
    meeting_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    meeting = _meeting_or_404(db, meeting_id)
    if not _can_delete(db, meeting, current_user):
        raise HTTPException(status_code=403, detail="Suppression de la réunion non autorisée")
    if meeting.status == "live":
        raise HTTPException(
            status_code=409,
            detail="Terminez la réunion en direct avant de la supprimer.",
        )

    recipient_ids = [
        row.user_id
        for row in db.query(MeetingMember.user_id).filter(
            MeetingMember.meeting_id == meeting.id,
            MeetingMember.user_id != current_user.id,
        ).all()
    ]
    if meeting.status == "scheduled" and recipient_ids:
        create_notifications(
            db,
            user_ids=recipient_ids,
            title=f"Réunion supprimée · {meeting.title}",
            message="Cette réunion EnactMeet a été supprimée par son organisateur.",
            notification_type="meeting_deleted",
        )
    db.query(Notification).filter(
        Notification.related_type == "meeting",
        Notification.related_id == meeting.id,
    ).delete(synchronize_session=False)
    db.query(MeetingMember).filter(
        MeetingMember.meeting_id == meeting.id
    ).delete(synchronize_session=False)
    db.delete(meeting)
    db.commit()
    return {"ok": True}
