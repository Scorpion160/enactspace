import asyncio
from uuid import UUID

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sqlalchemy import func

from app.core.security import decode_access_token
from app.db.database import SessionLocal
from app.models.chat import ChatMessage, ChatParticipant
from app.models.notification import Notification
from app.models.user import User


router = APIRouter(prefix="/realtime", tags=["Temps reel"])
_connections: dict[str, set[WebSocket]] = {}


def _authenticated_user(db, token: str) -> User | None:
    user_id = decode_access_token(token)
    if not user_id:
        return None

    try:
        parsed_id = UUID(user_id)
    except ValueError:
        return None

    return (
        db.query(User)
        .filter(
            User.id == parsed_id,
            User.is_active.is_(True),
            User.status.in_(("active", "alumni")),
        )
        .first()
    )


def _snapshot(db, user_id) -> dict:
    latest_notification = (
        db.query(Notification.id)
        .filter(Notification.user_id == user_id)
        .order_by(Notification.created_at.desc())
        .first()
    )
    unread_count = (
        db.query(func.count(Notification.id))
        .filter(
            Notification.user_id == user_id,
            Notification.is_read.is_(False),
        )
        .scalar()
        or 0
    )
    latest_message = (
        db.query(ChatMessage.id, ChatMessage.thread_id)
        .join(
            ChatParticipant,
            ChatParticipant.thread_id == ChatMessage.thread_id,
        )
        .filter(
            ChatParticipant.user_id == user_id,
            ChatMessage.deleted_at.is_(None),
        )
        .order_by(ChatMessage.created_at.desc())
        .first()
    )

    return {
        "notification_id": (
            str(latest_notification[0]) if latest_notification else None
        ),
        "unread_count": int(unread_count),
        "message_id": str(latest_message[0]) if latest_message else None,
        "thread_id": str(latest_message[1]) if latest_message else None,
    }


def _register_connection(user_id, websocket: WebSocket) -> bool:
    connections = _connections.setdefault(str(user_id), set())
    was_offline = not connections
    connections.add(websocket)
    return was_offline


def _unregister_connection(user_id, websocket: WebSocket) -> bool:
    connections = _connections.get(str(user_id))
    if not connections:
        return False
    connections.discard(websocket)
    if not connections:
        _connections.pop(str(user_id), None)
        return True
    return False


async def _broadcast_to_users(user_ids: list[str], event: dict) -> None:
    for user_id in user_ids:
        for connection in list(_connections.get(user_id, set())):
            try:
                await connection.send_json(event)
            except RuntimeError:
                _unregister_connection(user_id, connection)


async def _broadcast_presence(user_id, is_online: bool) -> None:
    await _broadcast_to_users(
        list(_connections),
        {
            "type": "presence",
            "user_id": str(user_id),
            "is_online": is_online,
        },
    )


async def _broadcast_read(db, user: User, payload: dict) -> None:
    thread_id = payload.get("thread_id")
    if not thread_id:
        return

    try:
        parsed_thread_id = UUID(str(thread_id))
    except ValueError:
        return

    db.expire_all()
    participant = (
        db.query(ChatParticipant)
        .filter(
            ChatParticipant.thread_id == parsed_thread_id,
            ChatParticipant.user_id == user.id,
        )
        .first()
    )
    if not participant:
        return

    recipient_ids = [
        str(row[0])
        for row in db.query(ChatParticipant.user_id)
        .filter(
            ChatParticipant.thread_id == parsed_thread_id,
            ChatParticipant.user_id != user.id,
        )
        .all()
    ]
    await _broadcast_to_users(
        recipient_ids,
        {
            "type": "read",
            "thread_id": str(parsed_thread_id),
            "user_id": str(user.id),
            "read_at": (
                participant.last_read_at.isoformat()
                if participant.last_read_at
                else None
            ),
        },
    )


async def _broadcast_typing(db, user: User, payload: dict) -> None:
    thread_id = payload.get("thread_id")
    if not thread_id:
        return

    try:
        parsed_thread_id = UUID(str(thread_id))
    except ValueError:
        return

    is_participant = (
        db.query(ChatParticipant.id)
        .filter(
            ChatParticipant.thread_id == parsed_thread_id,
            ChatParticipant.user_id == user.id,
        )
        .first()
    )
    if not is_participant:
        return

    recipient_ids = [
        str(row[0])
        for row in db.query(ChatParticipant.user_id)
        .filter(
            ChatParticipant.thread_id == parsed_thread_id,
            ChatParticipant.user_id != user.id,
        )
        .all()
    ]
    event = {
        "type": "typing",
        "thread_id": str(parsed_thread_id),
        "user_id": str(user.id),
        "display_name": f"{user.first_name} {user.last_name}".strip(),
        "is_typing": payload.get("is_typing") is True,
    }

    await _broadcast_to_users(recipient_ids, event)


@router.websocket("/ws")
async def realtime_events(websocket: WebSocket):
    db = SessionLocal()
    user = None
    try:
        await websocket.accept()
        try:
            auth_message = await asyncio.wait_for(
                websocket.receive_json(),
                timeout=5,
            )
        except (asyncio.TimeoutError, ValueError):
            await websocket.close(code=4401, reason="Authentification requise")
            return

        token = auth_message.get("token") if isinstance(auth_message, dict) else None
        user = _authenticated_user(db, token)
        if user is None:
            await websocket.close(code=4401, reason="Authentification requise")
            return

        became_online = _register_connection(user.id, websocket)
        previous = _snapshot(db, user.id)
        await websocket.send_json(
            {
                "type": "connected",
                "unread_count": previous["unread_count"],
                "online_user_ids": list(_connections),
            }
        )
        if became_online:
            await _broadcast_presence(user.id, True)

        while True:
            try:
                payload = await asyncio.wait_for(
                    websocket.receive_json(),
                    timeout=2,
                )
                if isinstance(payload, dict) and payload.get("type") == "typing":
                    await _broadcast_typing(db, user, payload)
                if isinstance(payload, dict) and payload.get("type") == "read":
                    await _broadcast_read(db, user, payload)
            except asyncio.TimeoutError:
                pass

            db.expire_all()
            current = _snapshot(db, user.id)

            if (
                current["notification_id"] != previous["notification_id"]
                or current["unread_count"] != previous["unread_count"]
            ):
                await websocket.send_json(
                    {
                        "type": "notification",
                        "notification_id": current["notification_id"],
                        "unread_count": current["unread_count"],
                    }
                )

            if current["message_id"] != previous["message_id"]:
                await websocket.send_json(
                    {
                        "type": "chat",
                        "message_id": current["message_id"],
                        "thread_id": current["thread_id"],
                    }
                )

            previous = current
    except (WebSocketDisconnect, RuntimeError):
        pass
    finally:
        if user is not None:
            became_offline = _unregister_connection(user.id, websocket)
            if became_offline:
                await _broadcast_presence(user.id, False)
        db.close()
