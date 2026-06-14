import json
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.db.database import get_db
from app.models.chat import ChatThread, ChatParticipant, ChatMessage
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.chat import (
    ChatContactRead,
    ChatThreadCreate,
    ChatThreadRead,
    ChatParticipantRead,
    ChatMessageCreate,
    ChatMessageRead,
)


router = APIRouter(prefix="/chat", tags=["Chat"])

VALID_THREAD_TYPES = {"direct", "group", "club", "pole", "project", "enacchef"}
VALID_MESSAGE_TYPES = {"text", "image", "video", "audio", "document", "sticker"}
MEDIA_MESSAGE_TYPES = VALID_MESSAGE_TYPES - {"text"}
ENACCHEF_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
    "financier",
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
    "faculty_advisor",
}

MESSAGE_TYPE_LABELS = {
    "image": "Photo",
    "video": "Vidéo",
    "audio": "Audio",
    "document": "Document",
    "sticker": "Sticker",
}


def parse_message_payload(message: ChatMessage) -> dict:
    if message.message_type == "text":
        return {"content": message.content}

    try:
        payload = json.loads(message.content)
    except (TypeError, json.JSONDecodeError):
        payload = {"content": message.content}

    if not isinstance(payload, dict):
        return {"content": str(message.content)}

    return payload


def serialize_message(message: ChatMessage) -> dict:
    payload = parse_message_payload(message)

    return {
        "id": message.id,
        "thread_id": message.thread_id,
        "author_id": message.author_id,
        "content": payload.get("content") or "",
        "message_type": message.message_type,
        "created_at": message.created_at,
        "edited_at": message.edited_at,
        "deleted_at": message.deleted_at,
        "attachment_url": payload.get("attachment_url"),
        "attachment_name": payload.get("attachment_name"),
        "attachment_mime_type": payload.get("attachment_mime_type"),
        "attachment_size_bytes": payload.get("attachment_size_bytes"),
        "duration_seconds": payload.get("duration_seconds"),
        "thumbnail_url": payload.get("thumbnail_url"),
        "sticker_pack": payload.get("sticker_pack"),
    }


def message_preview(message: ChatMessage) -> str:
    if message.message_type == "text":
        return message.content

    payload = parse_message_payload(message)
    label = MESSAGE_TYPE_LABELS.get(message.message_type, "Média")
    name = payload.get("attachment_name") or payload.get("content")

    return f"{label} · {name}" if name else label


def build_message_content(payload: ChatMessageCreate) -> str:
    content = payload.content.strip()

    if payload.message_type in MEDIA_MESSAGE_TYPES and not content:
        content = MESSAGE_TYPE_LABELS.get(payload.message_type, "Média")

    if payload.message_type == "text":
        return content

    media_payload = {
        "content": content,
        "attachment_url": payload.attachment_url.strip()
        if payload.attachment_url
        else None,
        "attachment_name": payload.attachment_name.strip()
        if payload.attachment_name
        else None,
        "attachment_mime_type": payload.attachment_mime_type.strip()
        if payload.attachment_mime_type
        else None,
        "attachment_size_bytes": payload.attachment_size_bytes,
        "duration_seconds": payload.duration_seconds,
        "thumbnail_url": payload.thumbnail_url.strip() if payload.thumbnail_url else None,
        "sticker_pack": payload.sticker_pack.strip() if payload.sticker_pack else None,
    }

    return json.dumps(
        {key: value for key, value in media_payload.items() if value is not None},
        ensure_ascii=False,
    )


def get_participant_or_404(
    db: Session,
    thread_id: str,
    user_id,
) -> ChatParticipant:
    participant = db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread_id,
        ChatParticipant.user_id == user_id,
    ).first()

    if not participant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable",
        )

    return participant


def build_thread_read(db: Session, thread: ChatThread, user_id) -> ChatThreadRead:
    participant = db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread.id,
        ChatParticipant.user_id == user_id,
    ).first()

    participants_count = db.query(func.count(ChatParticipant.id)).filter(
        ChatParticipant.thread_id == thread.id,
    ).scalar() or 0

    unread_query = db.query(func.count(ChatMessage.id)).filter(
        ChatMessage.thread_id == thread.id,
        ChatMessage.author_id != user_id,
        ChatMessage.deleted_at.is_(None),
    )

    if participant and participant.last_read_at:
        unread_query = unread_query.filter(
            ChatMessage.created_at > participant.last_read_at,
        )

    unread_count = unread_query.scalar() or 0

    last_message = db.query(ChatMessage).filter(
        ChatMessage.thread_id == thread.id,
        ChatMessage.deleted_at.is_(None),
    ).order_by(ChatMessage.created_at.desc()).first()

    return ChatThreadRead(
        id=thread.id,
        title=thread.title,
        thread_type=thread.thread_type,
        scope_type=thread.scope_type,
        scope_id=thread.scope_id,
        created_by=thread.created_by,
        created_at=thread.created_at,
        updated_at=thread.updated_at,
        participants_count=int(participants_count),
        unread_count=int(unread_count),
        last_message=message_preview(last_message) if last_message else None,
        last_message_at=last_message.created_at if last_message else None,
    )


def scope_participant_ids(db: Session, payload: ChatThreadCreate) -> set:
    if payload.thread_type == "enacchef" or payload.scope_type == "enacchef":
        rows = (
            db.query(UserRole.user_id)
            .join(Role, Role.id == UserRole.role_id)
            .filter(Role.name.in_(ENACCHEF_ROLES))
            .all()
        )
        return {row[0] for row in rows}

    if payload.thread_type == "pole" or payload.scope_type == "pole":
        if not payload.scope_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Choisissez un pôle pour cette conversation",
            )

        rows = db.query(PoleMember.user_id).filter(
            PoleMember.pole_id == payload.scope_id,
            PoleMember.is_active.is_(True),
        ).all()
        return {row[0] for row in rows}

    if payload.thread_type == "project" or payload.scope_type == "project":
        if not payload.scope_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Choisissez un projet pour cette conversation",
            )

        rows = db.query(ProjectMember.user_id).filter(
            ProjectMember.project_id == payload.scope_id,
            ProjectMember.is_active.is_(True),
        ).all()
        return {row[0] for row in rows}

    return set()


@router.get("/contacts", response_model=list[ChatContactRead])
def list_chat_contacts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    search: str | None = Query(default=None),
    scope_type: str | None = Query(default=None),
    scope_id: str | None = Query(default=None),
):
    query = db.query(User).filter(
        User.is_active.is_(True),
        User.status.in_(["active", "alumni"]),
    )

    if scope_type == "enacchef":
        query = query.join(UserRole, UserRole.user_id == User.id).join(
            Role,
            Role.id == UserRole.role_id,
        ).filter(Role.name.in_(ENACCHEF_ROLES))

    if scope_type == "pole" and scope_id:
        query = query.join(PoleMember, PoleMember.user_id == User.id).filter(
            PoleMember.pole_id == scope_id,
            PoleMember.is_active.is_(True),
        )

    if scope_type == "project" and scope_id:
        query = query.join(ProjectMember, ProjectMember.user_id == User.id).filter(
            ProjectMember.project_id == scope_id,
            ProjectMember.is_active.is_(True),
        )

    if search:
        like = f"%{search.strip()}%"
        query = query.filter(
            (User.first_name.ilike(like))
            | (User.last_name.ilike(like))
            | (User.email.ilike(like))
        )

    return query.distinct().order_by(User.first_name.asc(), User.last_name.asc()).limit(80).all()


@router.post("/threads", response_model=ChatThreadRead)
def create_thread(
    payload: ChatThreadCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.thread_type not in VALID_THREAD_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de conversation invalide",
        )

    participant_ids = set(payload.participant_ids) | scope_participant_ids(db, payload)
    participant_ids.add(current_user.id)

    if payload.thread_type == "direct" and len(participant_ids) != 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Une discussion privée doit contenir exactement deux personnes",
        )

    active_users_count = db.query(func.count(User.id)).filter(
        User.id.in_(participant_ids),
        User.is_active.is_(True),
        User.status.in_(["active", "alumni"]),
    ).scalar() or 0

    if active_users_count != len(participant_ids):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un participant est introuvable ou inactif",
        )

    thread = ChatThread(
        title=payload.title.strip() if payload.title else None,
        thread_type=payload.thread_type,
        scope_type=payload.scope_type,
        scope_id=payload.scope_id,
        created_by=current_user.id,
    )

    db.add(thread)
    db.flush()

    for user_id in participant_ids:
        db.add(
            ChatParticipant(
                thread_id=thread.id,
                user_id=user_id,
                participant_role="owner" if user_id == current_user.id else "member",
            )
        )

    db.commit()
    db.refresh(thread)

    return build_thread_read(db, thread, current_user.id)


@router.get("/threads", response_model=list[ChatThreadRead])
def list_threads(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    threads = db.query(ChatThread).join(
        ChatParticipant,
        ChatParticipant.thread_id == ChatThread.id,
    ).filter(
        ChatParticipant.user_id == current_user.id,
    ).order_by(ChatThread.updated_at.desc()).all()

    return [build_thread_read(db, thread, current_user.id) for thread in threads]


@router.get("/threads/{thread_id}/participants", response_model=list[ChatParticipantRead])
def list_thread_participants(
    thread_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    return db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread_id,
    ).order_by(ChatParticipant.joined_at.asc()).all()


@router.get("/threads/{thread_id}/messages", response_model=list[ChatMessageRead])
def list_messages(
    thread_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    limit: int = Query(default=80, ge=1, le=200),
):
    participant = get_participant_or_404(db, thread_id, current_user.id)

    messages = db.query(ChatMessage).filter(
        ChatMessage.thread_id == thread_id,
        ChatMessage.deleted_at.is_(None),
    ).order_by(ChatMessage.created_at.desc()).limit(limit).all()

    participant.last_read_at = datetime.utcnow()
    db.commit()

    return [serialize_message(message) for message in reversed(messages)]


@router.post("/threads/{thread_id}/messages", response_model=ChatMessageRead)
def send_message(
    thread_id: str,
    payload: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    content = payload.content.strip()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le message ne peut pas être vide",
        )

    if payload.message_type not in VALID_MESSAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de message invalide",
        )

    if payload.message_type in MEDIA_MESSAGE_TYPES and not payload.attachment_url:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ajoutez un lien de fichier pour ce message",
        )

    message = ChatMessage(
        thread_id=UUID(thread_id),
        author_id=current_user.id,
        content=build_message_content(
            payload.model_copy(update={"content": content}),
        ),
        message_type=payload.message_type,
    )

    thread = db.query(ChatThread).filter(ChatThread.id == thread_id).first()
    if thread:
        thread.updated_at = datetime.utcnow()

    participant = get_participant_or_404(db, thread_id, current_user.id)
    participant.last_read_at = datetime.utcnow()

    db.add(message)
    db.commit()
    db.refresh(message)

    return serialize_message(message)


@router.post("/threads/{thread_id}/read", response_model=ChatThreadRead)
def mark_thread_as_read(
    thread_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    participant = get_participant_or_404(db, thread_id, current_user.id)
    participant.last_read_at = datetime.utcnow()
    db.commit()

    thread = db.query(ChatThread).filter(ChatThread.id == thread_id).first()
    if not thread:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable",
        )

    return build_thread_read(db, thread, current_user.id)
