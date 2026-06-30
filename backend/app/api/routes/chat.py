import json
from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.db.database import get_db
from app.models.chat import (
    ChatThread,
    ChatParticipant,
    ChatMessage,
    ChatMessageReaction,
)
from app.models.stored_file import StoredFile
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.chat import (
    ChatContactRead,
    ChatThreadCreate,
    ChatThreadRead,
    ChatUnreadCountRead,
    ChatParticipantRead,
    ChatMessageCreate,
    ChatMessageRead,
    ChatUploadCreate,
    ChatUploadRead,
    ChatParticipantsUpdate,
    ChatParticipantRoleUpdate,
    ChatMessageReactionCreate,
    ChatMessageReactionRead,
)
from app.services.notification_service import notify_user, notify_users
from app.services.file_storage_service import store_base64


router = APIRouter(prefix="/chat", tags=["Chat"])

VALID_THREAD_TYPES = {"direct", "group", "club", "pole", "project", "enacchef"}
VALID_MESSAGE_TYPES = {"text", "image", "video", "audio", "document", "sticker"}
MEDIA_MESSAGE_TYPES = VALID_MESSAGE_TYPES - {"text"}
VALID_REACTION_TYPES = {"👍", "❤️", "😂", "😮", "😢", "🙏"}
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


def message_reactions_summary(db: Session, message_id) -> dict[str, int]:
    rows = db.query(
        ChatMessageReaction.reaction_type,
        func.count(ChatMessageReaction.id),
    ).filter(
        ChatMessageReaction.message_id == message_id,
    ).group_by(ChatMessageReaction.reaction_type).all()

    return {reaction_type: int(count or 0) for reaction_type, count in rows}


def current_user_reaction(db: Session, message_id, user_id) -> str | None:
    reaction = db.query(ChatMessageReaction).filter(
        ChatMessageReaction.message_id == message_id,
        ChatMessageReaction.user_id == user_id,
    ).first()

    return reaction.reaction_type if reaction else None


def serialize_message(
    message: ChatMessage,
    db: Session | None = None,
    current_user_id=None,
) -> dict:
    payload = parse_message_payload(message)
    reactions_summary = (
        message_reactions_summary(db, message.id)
        if db is not None
        else {}
    )

    return {
        "id": message.id,
        "thread_id": message.thread_id,
        "author_id": message.author_id,
        "content": payload.get("content") or "",
        "message_type": message.message_type,
        "created_at": message.created_at,
        "edited_at": message.edited_at,
        "deleted_at": message.deleted_at,
        "attachment_file_id": payload.get("attachment_file_id"),
        "attachment_url": payload.get("attachment_url"),
        "attachment_name": payload.get("attachment_name"),
        "attachment_mime_type": payload.get("attachment_mime_type"),
        "attachment_size_bytes": payload.get("attachment_size_bytes"),
        "duration_seconds": payload.get("duration_seconds"),
        "thumbnail_url": payload.get("thumbnail_url"),
        "sticker_pack": payload.get("sticker_pack"),
        "reactions_count": sum(reactions_summary.values()),
        "reactions_summary": reactions_summary,
        "current_user_reaction": current_user_reaction(
            db,
            message.id,
            current_user_id,
        )
        if db is not None and current_user_id is not None
        else None,
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
        "attachment_file_id": str(payload.attachment_file_id)
        if payload.attachment_file_id
        else None,
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


def user_display_name(user: User | None) -> str:
    if not user:
        return "Membre"

    name = " ".join(
        part for part in [user.first_name, user.last_name] if part and part.strip()
    ).strip()
    return name or user.email


def thread_notification_name(thread: ChatThread | None) -> str:
    if not thread:
        return "Conversation"
    return thread.title or "Discussion privee"


def attach_file_to_thread(
    db: Session,
    *,
    file_id,
    thread_id,
    current_user: User,
) -> StoredFile | None:
    if not file_id:
        return None

    stored_file = db.query(StoredFile).filter(StoredFile.id == file_id).first()
    if not stored_file:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Fichier de message introuvable",
        )
    if stored_file.uploaded_by_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez pas envoyer ce fichier.",
        )

    stored_file.entity_type = "chat_thread"
    stored_file.entity_id = thread_id
    stored_file.visibility = "participants"
    stored_file.updated_at = datetime.utcnow()
    return stored_file


def serialize_participant(participant: ChatParticipant) -> dict:
    user = participant.user
    return {
        "id": participant.id,
        "thread_id": participant.thread_id,
        "user_id": participant.user_id,
        "first_name": user.first_name if user else None,
        "last_name": user.last_name if user else None,
        "email": user.email if user else None,
        "status": user.status if user else None,
        "photo_url": user.photo_url if user else None,
        "participant_role": participant.participant_role,
        "joined_at": participant.joined_at,
        "last_read_at": participant.last_read_at,
    }


def participant_preview(participant: ChatParticipant) -> dict:
    user = participant.user
    return {
        "user_id": participant.user_id,
        "first_name": user.first_name if user else "",
        "last_name": user.last_name if user else "",
        "email": user.email if user else "",
        "status": user.status if user else "",
        "photo_url": user.photo_url if user else None,
        "participant_role": participant.participant_role,
        "last_read_at": participant.last_read_at,
    }


def require_thread_admin(participant: ChatParticipant):
    if participant.participant_role not in {"owner", "admin"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Action réservée aux administrateurs du groupe",
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

    participants = db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread.id,
    ).order_by(ChatParticipant.joined_at.asc()).limit(6).all()

    other_participants = [
        item for item in participants if str(item.user_id) != str(user_id)
    ]
    display_title = thread.title
    avatar_url = None

    if not display_title and thread.thread_type == "direct" and other_participants:
        other_user = other_participants[0].user
        display_title = user_display_name(other_user)
        avatar_url = other_user.photo_url

    if not display_title:
        names = [
            user_display_name(item.user)
            for item in other_participants[:3]
            if item.user is not None
        ]
        display_title = ", ".join(names) if names else "Conversation"

    return ChatThreadRead(
        id=thread.id,
        title=thread.title,
        display_title=display_title,
        avatar_url=avatar_url,
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
        current_user_role=participant.participant_role if participant else "member",
        participants_preview=[
            participant_preview(item) for item in participants
        ],
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


@router.post("/uploads", response_model=ChatUploadRead)
def upload_chat_media(
    payload: ChatUploadCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.message_type not in MEDIA_MESSAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de media invalide",
        )

    thread_id = payload.thread_id
    if thread_id:
        get_participant_or_404(db, str(thread_id), current_user.id)

    stored_file = store_base64(
        db,
        data_base64=payload.data_base64,
        original_filename=payload.file_name,
        uploaded_by=current_user,
        mime_type=payload.content_type,
        storage_scope="chat",
        visibility="participants" if thread_id else "private",
        entity_type="chat_thread" if thread_id else None,
        entity_id=thread_id,
        is_temporary=True,
    )
    db.commit()
    db.refresh(stored_file)

    return ChatUploadRead(
        file_id=stored_file.id,
        url=f"/api/files/{stored_file.id}/download",
        file_name=stored_file.original_filename,
        content_type=stored_file.mime_type,
        size_bytes=stored_file.file_size,
        message_type=payload.message_type,
    )

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

    if payload.thread_type != "direct" and not (payload.title or "").strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Donnez un nom à cette conversation",
        )

    if payload.thread_type == "direct":
        existing_threads = db.query(ChatThread).join(
            ChatParticipant,
            ChatParticipant.thread_id == ChatThread.id,
        ).filter(
            ChatThread.thread_type == "direct",
            ChatParticipant.user_id.in_(participant_ids),
        ).group_by(ChatThread.id).having(
            func.count(ChatParticipant.id) == 2,
        ).all()

        for existing_thread in existing_threads:
            existing_participants = {
                item[0]
                for item in db.query(ChatParticipant.user_id).filter(
                    ChatParticipant.thread_id == existing_thread.id,
                ).all()
            }
            if existing_participants == participant_ids:
                return build_thread_read(db, existing_thread, current_user.id)

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
        title=None if payload.thread_type == "direct" else payload.title.strip(),
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

    recipient_ids = [user_id for user_id in participant_ids if user_id != current_user.id]
    if recipient_ids:
        creator_name = user_display_name(current_user)
        notify_users(
            db,
            user_ids=recipient_ids,
            title="Nouvelle conversation",
            message=f"{creator_name} vous a ajoute a {thread_notification_name(thread)}.",
            notification_type="chat_thread_created",
            related_type="chat_thread",
            related_id=thread.id,
            dedupe=True,
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


@router.get("/unread-count", response_model=ChatUnreadCountRead)
def get_chat_unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    participants = db.query(ChatParticipant).filter(
        ChatParticipant.user_id == current_user.id,
    ).all()

    total = 0
    for participant in participants:
        query = db.query(func.count(ChatMessage.id)).filter(
            ChatMessage.thread_id == participant.thread_id,
            ChatMessage.author_id != current_user.id,
            ChatMessage.deleted_at.is_(None),
        )
        if participant.last_read_at:
            query = query.filter(ChatMessage.created_at > participant.last_read_at)
        total += int(query.scalar() or 0)

    return ChatUnreadCountRead(unread_count=total)


@router.get("/threads/{thread_id}/participants", response_model=list[ChatParticipantRead])
def list_thread_participants(
    thread_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    participants = db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread_id,
    ).order_by(ChatParticipant.joined_at.asc()).all()

    return [serialize_participant(participant) for participant in participants]


@router.post("/threads/{thread_id}/participants", response_model=list[ChatParticipantRead])
def add_thread_participants(
    thread_id: str,
    payload: ChatParticipantsUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_participant = get_participant_or_404(db, thread_id, current_user.id)
    require_thread_admin(current_participant)

    if not payload.user_ids:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ajoutez au moins un membre",
        )

    existing_ids = {
        item[0]
        for item in db.query(ChatParticipant.user_id).filter(
            ChatParticipant.thread_id == thread_id,
        ).all()
    }

    active_users = db.query(User).filter(
        User.id.in_(payload.user_ids),
        User.is_active.is_(True),
        User.status.in_(["active", "alumni"]),
    ).all()

    added_user_ids = []
    for user in active_users:
        if user.id in existing_ids:
            continue
        db.add(
            ChatParticipant(
                thread_id=UUID(thread_id),
                user_id=user.id,
                participant_role="member",
            )
        )
        added_user_ids.append(user.id)

    thread = db.query(ChatThread).filter(ChatThread.id == thread_id).first()
    if thread:
        thread.updated_at = datetime.utcnow()
    if added_user_ids:
        actor_name = user_display_name(current_user)
        notify_users(
            db,
            user_ids=added_user_ids,
            title="Ajoute a une conversation",
            message=f"{actor_name} vous a ajoute a {thread_notification_name(thread)}.",
            notification_type="chat_participant_added",
            related_type="chat_thread",
            related_id=UUID(thread_id),
            dedupe=True,
        )

    db.commit()

    participants = db.query(ChatParticipant).filter(
        ChatParticipant.thread_id == thread_id,
    ).order_by(ChatParticipant.joined_at.asc()).all()
    return [serialize_participant(participant) for participant in participants]


@router.patch(
    "/threads/{thread_id}/participants/{user_id}/role",
    response_model=ChatParticipantRead,
)
def update_thread_participant_role(
    thread_id: str,
    user_id: UUID,
    payload: ChatParticipantRoleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_participant = get_participant_or_404(db, thread_id, current_user.id)
    require_thread_admin(current_participant)

    if payload.participant_role not in {"admin", "member"}:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Rôle de participant invalide",
        )

    target = get_participant_or_404(db, thread_id, user_id)
    if target.participant_role == "owner":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le propriétaire du groupe ne peut pas être modifié",
        )

    target.participant_role = payload.participant_role
    db.commit()
    db.refresh(target)
    return serialize_participant(target)


@router.delete("/threads/{thread_id}/participants/{user_id}")
def remove_thread_participant(
    thread_id: str,
    user_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_participant = get_participant_or_404(db, thread_id, current_user.id)
    is_self = str(current_user.id) == str(user_id)

    if not is_self:
        require_thread_admin(current_participant)

    target = get_participant_or_404(db, thread_id, user_id)
    if target.participant_role == "owner" and not is_self:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le propriétaire ne peut pas être retiré",
        )

    db.delete(target)
    db.commit()
    return {"ok": True}


@router.delete("/threads/{thread_id}")
def delete_thread(
    thread_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    current_participant = get_participant_or_404(db, thread_id, current_user.id)
    require_thread_admin(current_participant)

    thread = db.query(ChatThread).filter(ChatThread.id == thread_id).first()
    if not thread:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation introuvable",
        )

    db.delete(thread)
    db.commit()
    return {"ok": True}


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

    return [
        serialize_message(message, db=db, current_user_id=current_user.id)
        for message in reversed(messages)
    ]


@router.post("/threads/{thread_id}/messages", response_model=ChatMessageRead)
def send_message(
    thread_id: str,
    payload: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    content = payload.content.strip()

    if payload.message_type not in VALID_MESSAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Type de message invalide",
        )

    if payload.message_type == "text" and not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le message ne peut pas être vide",
        )

    if (
        payload.message_type in MEDIA_MESSAGE_TYPES
        and not payload.attachment_url
        and not payload.attachment_file_id
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ajoutez un lien de fichier pour ce message",
        )

    stored_file = attach_file_to_thread(
        db,
        file_id=payload.attachment_file_id,
        thread_id=UUID(thread_id),
        current_user=current_user,
    )
    if stored_file and not payload.attachment_url:
        payload = payload.model_copy(
            update={"attachment_url": f"/api/files/{stored_file.id}/download"}
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
    recipient_ids = [
        row[0]
        for row in db.query(ChatParticipant.user_id).filter(
            ChatParticipant.thread_id == thread_id,
            ChatParticipant.user_id != current_user.id,
        ).all()
    ]
    if recipient_ids:
        sender_name = user_display_name(current_user)
        notify_users(
            db,
            user_ids=recipient_ids,
            title=f"Nouveau message de {sender_name}",
            message=message_preview(message),
            notification_type="chat_message",
            related_type="chat_thread",
            related_id=message.thread_id,
        )

    db.commit()
    db.refresh(message)

    return serialize_message(message, db=db, current_user_id=current_user.id)


@router.post(
    "/threads/{thread_id}/messages/{message_id}/reaction",
    response_model=ChatMessageReactionRead,
)
def upsert_message_reaction(
    thread_id: str,
    message_id: str,
    payload: ChatMessageReactionCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    reaction_type = payload.reaction_type.strip()
    if reaction_type not in VALID_REACTION_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Réaction invalide",
        )

    message = db.query(ChatMessage).filter(
        ChatMessage.id == message_id,
        ChatMessage.thread_id == thread_id,
        ChatMessage.deleted_at.is_(None),
    ).first()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message introuvable",
        )

    reaction = db.query(ChatMessageReaction).filter(
        ChatMessageReaction.message_id == message.id,
        ChatMessageReaction.user_id == current_user.id,
    ).first()

    created_reaction = reaction is None
    if reaction:
        reaction.reaction_type = reaction_type
        reaction.created_at = datetime.utcnow()
    else:
        reaction = ChatMessageReaction(
            message_id=message.id,
            user_id=current_user.id,
            reaction_type=reaction_type,
        )
        db.add(reaction)

    if created_reaction and message.author_id != current_user.id:
        notify_user(
            db,
            user_id=message.author_id,
            title=f"{user_display_name(current_user)} a reagi a votre message",
            message=reaction_type,
            notification_type="chat_reaction",
            related_type="chat_thread",
            related_id=message.thread_id,
            dedupe=True,
        )

    db.commit()
    db.refresh(reaction)
    return reaction


@router.get(
    "/threads/{thread_id}/messages/{message_id}/reactions",
    response_model=list[ChatMessageReactionRead],
)
def list_message_reactions(
    thread_id: str,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    message = db.query(ChatMessage).filter(
        ChatMessage.id == message_id,
        ChatMessage.thread_id == thread_id,
        ChatMessage.deleted_at.is_(None),
    ).first()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message introuvable",
        )

    return db.query(ChatMessageReaction).filter(
        ChatMessageReaction.message_id == message.id,
    ).order_by(ChatMessageReaction.created_at.asc()).all()


@router.delete("/threads/{thread_id}/messages/{message_id}/reaction")
def delete_message_reaction(
    thread_id: str,
    message_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    get_participant_or_404(db, thread_id, current_user.id)

    message = db.query(ChatMessage).filter(
        ChatMessage.id == message_id,
        ChatMessage.thread_id == thread_id,
        ChatMessage.deleted_at.is_(None),
    ).first()
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Message introuvable",
        )

    reaction = db.query(ChatMessageReaction).filter(
        ChatMessageReaction.message_id == message.id,
        ChatMessageReaction.user_id == current_user.id,
    ).first()

    if reaction:
        db.delete(reaction)
        db.commit()

    return {"ok": True}


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
