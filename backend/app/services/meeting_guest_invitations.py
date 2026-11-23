"""Secure email invitations for external EnactMeet participants.

Guests receive no EnactSpace account or access to club resources. The emailed
link is a revocable opaque bearer token; each access yields a short-lived Jitsi
participant JWT tied to exactly one meeting room.
"""
from datetime import timedelta
from hashlib import sha256
import re
import secrets
from types import SimpleNamespace
from urllib.parse import quote, urlsplit
from uuid import UUID

from fastapi import Depends, HTTPException, Request
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, field_validator
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import get_db
from app.models.email_delivery import EmailDelivery
from app.models.meeting import Meeting, MeetingGuestInvitation
from app.models.user import User
from app.services.audit_service import create_audit_log
from app.services.email_delivery_service import enqueue_email_delivery


class GuestInvitationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    email: str = Field(min_length=5, max_length=320)
    display_name: str | None = Field(default=None, max_length=160)

    @field_validator("email")
    @classmethod
    def email_is_valid(cls, value: str) -> str:
        normalized = value.strip().casefold()
        if not re.fullmatch(r"[^@\s<>;,]+@[^@\s<>;,]+\.[^@\s<>;,]+", normalized):
            raise ValueError("Adresse e-mail externe invalide.")
        return normalized

    @field_validator("display_name")
    @classmethod
    def name_is_valid(cls, value: str | None) -> str | None:
        if value is None:
            return None
        if any(ord(ch) < 32 for ch in value):
            raise ValueError("Nom de l'invité invalide.")
        name = value.strip()
        if not name:
            raise ValueError("Nom de l'invité invalide.")
        return name


def _guest_active(guest: MeetingGuestInvitation, now=None) -> bool:
    now = now or utc_now()
    return guest.revoked_at is None and guest.expires_at > now


def _public_guest_link(request: Request, token: str) -> str:
    """Canonical API origin avoids email links derived from untrusted Host headers."""
    configured = (settings.PUBLIC_API_BASE_URL or "").strip().rstrip("/")
    if not configured:
        if settings.APP_ENV == "production":
            raise HTTPException(503, "Configure PUBLIC_API_BASE_URL pour inviter des externes.")
        link = str(request.url_for("meeting_external_guest_join", token=token))
    else:
        root = configured[:-4] if configured.endswith("/api") else configured
        parsed = urlsplit(root)
        if (parsed.scheme not in {"https", "http"} or not parsed.hostname
                or parsed.username or parsed.password or parsed.query or parsed.fragment):
            raise HTTPException(503, "URL publique de l'API invalide.")
        link = f"{root}/api/meetings/guests/join/{token}"
    if settings.APP_ENV == "production" and urlsplit(link).scheme != "https":
        raise HTTPException(503, "Les invitations externes nécessitent HTTPS.")
    return link


def _guest_expiration(meeting: Meeting):
    now = utc_now()
    end = meeting.scheduled_end or meeting.scheduled_start
    expiration = max(now + timedelta(hours=12), (end + timedelta(days=1)) if end else now + timedelta(days=7))
    if expiration > now + timedelta(days=90):
        raise HTTPException(422, "Programme la réunion à moins de 90 jours pour inviter des externes.")
    return expiration


def register_guest_meeting_routes(router):
    # Defer import to avoid a circular dependency while meetings.py registers routes.
    from app.api.routes.meetings import (
        _make_jitsi_token, _meeting_or_404, _require_manage, _require_regular_meeting,
    )

    @router.get("/guests/join/{token}", name="meeting_external_guest_join")
    def join_external_guest(token: str, db: Session = Depends(get_db)):
        """Opening an invited email link redirects directly to Jitsi, no login."""
        if len(token) < 40 or len(token) > 128 or not re.fullmatch(r"[a-zA-Z0-9_-]+", token):
            raise HTTPException(404, "Invitation introuvable ou expirée.")
        token_hash = sha256(token.encode("ascii")).hexdigest()
        guest = db.query(MeetingGuestInvitation).filter(
            MeetingGuestInvitation.token_hash == token_hash,
        ).first()
        if guest is None or not _guest_active(guest):
            raise HTTPException(404, "Invitation introuvable, révoquée ou expirée.")
        meeting = db.get(Meeting, guest.meeting_id)
        if meeting is None or meeting.status in {"ended", "cancelled"}:
            raise HTTPException(410, "Cette réunion est terminée.")
        if meeting.status != "live":
            raise HTTPException(409, "La salle sera accessible lorsque l'organisateur aura démarré la réunion.")
        if not meeting.lobby_enabled:
            raise HTTPException(409, "L'accueil des invités externes n'est pas activé.")
        invited = SimpleNamespace(
            id=f"guest:{guest.id}", first_name=guest.display_name, last_name="",
            email=guest.email, photo_url=None,
        )
        # The link itself can remain usable until revoked/expired; JWTs cannot.
        jwt_token = _make_jitsi_token(
            meeting, invited, moderator=False,
            expires_at=min(guest.expires_at, utc_now() + timedelta(minutes=60)),
        )
        if not jwt_token:
            raise HTTPException(503, "Authentification EnactMeet indisponible.")
        dest = (f"{meeting.server_url.rstrip('/')}/{quote(meeting.room_key, safe='')}"
                f"?jwt={quote(jwt_token, safe='')}")
        return RedirectResponse(
            dest,
            status_code=303,
            headers={
                "Cache-Control": "no-store, private",
                "Referrer-Policy": "no-referrer",
                "X-Robots-Tag": "noindex, nofollow",
            },
        )

    @router.get("/{meeting_id}/guests")
    def list_external_guests(
        meeting_id: str,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_active_validated_user),
    ):
        meeting = _meeting_or_404(db, meeting_id)
        _require_manage(db, meeting, current_user)
        _require_regular_meeting(db, meeting)
        rows = db.query(MeetingGuestInvitation).filter(
            MeetingGuestInvitation.meeting_id == meeting.id,
        ).order_by(MeetingGuestInvitation.created_at.desc()).limit(150).all()
        deliveries = {
            row.id: row for row in db.query(EmailDelivery).filter(
                EmailDelivery.id.in_([
                    g.email_delivery_id for g in rows if g.email_delivery_id is not None
                ])
            ).all()
        } if rows else {}
        return [{
            "id": str(guest.id),
            "email": guest.email,
            "display_name": guest.display_name,
            "active": _guest_active(guest) and meeting.status not in {"ended", "cancelled"},
            "expires_at": guest.expires_at.isoformat() + "Z",
            "revoked_at": guest.revoked_at.isoformat() + "Z" if guest.revoked_at else None,
            "email_status": (
                deliveries[guest.email_delivery_id].status
                if guest.email_delivery_id in deliveries else "unknown"
            ),
        } for guest in rows]

    @router.post("/{meeting_id}/guests", status_code=201)
    def invite_external_guest(
        meeting_id: str, payload: GuestInvitationRequest, request: Request,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_active_validated_user),
    ):
        meeting = _meeting_or_404(db, meeting_id)
        _require_manage(db, meeting, current_user)
        _require_regular_meeting(db, meeting)
        if meeting.status in {"ended", "cancelled"}:
            raise HTTPException(409, "Cette réunion est clôturée.")
        # Serialize invitations for this room: duplicate active emails cannot race.
        db.query(Meeting).filter(Meeting.id == meeting.id).with_for_update().one()
        if (not settings.MEET_REQUIRE_JWT or not settings.MEET_JWT_SECRET):
            raise HTTPException(503, "EnactMeet privé doit être configuré avec JWT.")
        if (not settings.email_enabled or not settings.SMTP_HOST
                or settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT):
            raise HTTPException(503, "L'envoi institutionnel n'est pas disponible.")
        if settings.NOTIFICATION_EMAIL_FROM.strip().casefold() != "enactus@esp.sn":
            raise HTTPException(503, "L'expéditeur institutionnel n'est pas configuré.")
        now = utc_now()
        active_invitation = db.query(MeetingGuestInvitation.id).filter(
            MeetingGuestInvitation.meeting_id == meeting.id,
            MeetingGuestInvitation.email == payload.email,
            MeetingGuestInvitation.revoked_at.is_(None),
            MeetingGuestInvitation.expires_at > now,
        ).first()
        if active_invitation:
            raise HTTPException(409, "Une invitation active existe déjà pour cette adresse. Révoque-la avant de réinviter.")
        expires_at = _guest_expiration(meeting)
        raw_token = secrets.token_urlsafe(32)
        link = _public_guest_link(request, raw_token)
        name = payload.display_name or payload.email.split("@", 1)[0]
        row = MeetingGuestInvitation(
            meeting_id=meeting.id, invited_by=current_user.id,
            email=payload.email, display_name=name,
            token_hash=sha256(raw_token.encode("ascii")).hexdigest(),
            expires_at=expires_at, created_at=now,
        )
        db.add(row)
        db.flush()
        date_text = meeting.scheduled_start.strftime("%d/%m/%Y à %H:%M") if meeting.scheduled_start else "à confirmer par l'organisateur"
        safe_title = " ".join(meeting.title.splitlines()).strip()
        body = (
            f"Bonjour {name},\n\n"
            f"Tu es invité(e) à participer à une réunion EnactMeet : {safe_title}.\n"
            f"Date et heure : {date_text} (heure de Dakar).\n\n"
            f"Lien personnel pour rejoindre la réunion : {link}\n\n"
            "Ouvre le lien après le démarrage de la réunion. Aucun compte EnactSpace n'est nécessaire. "
            "Un organisateur devra t'admettre depuis la salle d'attente. "
            "Ce lien est personnel ; ne le transfère pas.\n\n"
            "L'équipe Enactus ESP"
        )
        email = enqueue_email_delivery(
            db, recipient_email=payload.email,
            subject=f"Enactus ESP — Invitation EnactMeet : {safe_title}",
            text_body=body, dedupe_key=f"meeting:guest:{row.id}",
        )
        if email is None:
            raise HTTPException(503, "Impossible de préparer l'e-mail d'invitation.")
        db.flush()
        row.email_delivery_id = email.id
        # External invitations require lobby admission; never create open guest rooms.
        if not meeting.lobby_enabled:
            meeting.lobby_enabled = True
            meeting.updated_at = now
        create_audit_log(
            db, "meeting_guest_invited", current_user.id, "meeting", meeting.id,
            new_value={"guest_id": str(row.id), "email": payload.email,
                       "expires_at": expires_at.isoformat(),
                       "email_delivery_id": str(email.id)},
        )
        db.commit()
        return {"id": str(row.id), "email": row.email, "display_name": row.display_name,
                "email_status": email.status, "expires_at": expires_at.isoformat() + "Z",
                "lobby_enabled": True}

    @router.delete("/{meeting_id}/guests/{guest_id}")
    def revoke_external_guest(
        meeting_id: str, guest_id: UUID,
        db: Session = Depends(get_db),
        current_user: User = Depends(get_current_active_validated_user),
    ):
        meeting = _meeting_or_404(db, meeting_id)
        _require_manage(db, meeting, current_user)
        _require_regular_meeting(db, meeting)
        guest = db.query(MeetingGuestInvitation).filter(
            MeetingGuestInvitation.id == guest_id,
            MeetingGuestInvitation.meeting_id == meeting.id,
        ).first()
        if guest is None:
            raise HTTPException(404, "Invitation introuvable.")
        if guest.revoked_at is None:
            guest.revoked_at = utc_now()
            if guest.email_delivery_id is not None:
                delivery = db.get(EmailDelivery, guest.email_delivery_id)
                if delivery is not None and delivery.status in {"pending", "retry"}:
                    delivery.status = "cancelled"
                    delivery.processing_started_at = None
            create_audit_log(
                db, "meeting_guest_revoked", current_user.id, "meeting", meeting.id,
                new_value={"guest_id": str(guest.id), "email": guest.email},
            )
            db.commit()
        return {"revoked": True}
