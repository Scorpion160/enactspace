"""Focused EnactMeet regressions."""
import os
import secrets
import unittest
import uuid

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException
import jwt as token_jwt
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.routes import meetings
from app.db.database import Base
from app.models.meeting import MeetingMember
from app.models.notification import Notification
from app.models.role import Role, UserRole
from app.models.user import User
from app.schemas.meeting import MeetingCreate, MeetingInviteRequest, MeetingUpdate


class MeetingTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.host = self._user("host")
        self.guest = self._user("guest")
        self.outsider = self._user("outsider")
        self.db.commit()

    def _user(self, prefix: str) -> User:
        user = User(
            first_name=prefix.title(),
            last_name="Meet",
            email=f"{prefix}-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def _grant(self, user: User, role_name: str) -> None:
        role = self.db.query(Role).filter(Role.name == role_name).first()
        if role is None:
            role = Role(name=role_name)
            self.db.add(role)
            self.db.flush()
        self.db.add(UserRole(user_id=user.id, role_id=role.id))
        self.db.flush()

    def _create(self):
        return meetings.create_meeting(
            MeetingCreate(
                title="Réunion produit",
                scope_type="custom",
                invite_user_ids=[self.guest.id],
            ),
            self.db,
            self.host,
        )

    def test_custom_meeting_invite_and_join_access(self):
        created = self._create()
        self.assertTrue(created.room_key.startswith("enactspace-"))
        self.assertEqual(created.invited_count, 2)
        invitation = self.db.query(Notification).filter(
            Notification.user_id == self.guest.id,
            Notification.type == "meeting_invitation",
            Notification.related_id == created.id,
        ).one()
        self.assertIn("Réunion produit", invitation.title)

        guest_view = meetings.get_meeting(
            str(created.id), self.db, self.guest
        )
        self.assertEqual(guest_view.id, created.id)
        with self.assertRaises(HTTPException) as raised:
            meetings.get_meeting(str(created.id), self.db, self.outsider)
        self.assertEqual(raised.exception.status_code, 403)
        self._grant(self.outsider, "chef_projet")
        with self.assertRaises(HTTPException) as manage_denied:
            meetings.update_meeting(
                str(created.id),
                MeetingUpdate(title="Tentative externe"),
                self.db,
                self.outsider,
            )
        self.assertEqual(manage_denied.exception.status_code, 403)

        self._grant(self.outsider, "team_leader")
        global_view = meetings.get_meeting(str(created.id), self.db, self.outsider)
        self.assertTrue(global_view.can_manage)
        self.assertTrue(global_view.can_delete)

        member = self.db.query(MeetingMember).filter(
            MeetingMember.meeting_id == created.id,
            MeetingMember.user_id == self.guest.id,
        ).one()
        self.assertIsNone(member.joined_at)
        with self.assertRaises(HTTPException) as waiting:
            meetings.join_meeting(str(created.id), self.db, self.guest)
        self.assertEqual(waiting.exception.status_code, 409)

        host_join = meetings.join_meeting(str(created.id), self.db, self.host)
        self.assertTrue(host_join.moderator)
        meetings.enter_meeting(str(created.id), self.db, self.host)
        started_notice = self.db.query(Notification).filter(
            Notification.user_id == self.guest.id,
            Notification.type == "meeting_started",
            Notification.related_id == created.id,
        ).one()
        self.assertIn("En direct", started_notice.title)

        join = meetings.join_meeting(str(created.id), self.db, self.guest)
        self.assertEqual(join.room_key, created.room_key)
        self.assertFalse(join.moderator)
        self.assertIsNone(join.jwt)
        self.db.refresh(member)
        self.assertIsNone(member.joined_at)
        meetings.enter_meeting(str(created.id), self.db, self.guest)
        self.db.refresh(member)
        self.assertIsNotNone(member.joined_at)

        meetings.leave_meeting(str(created.id), self.db, self.guest)
        self.db.refresh(member)
        self.assertIsNotNone(member.left_at)
        self.assertEqual(member.last_seen_at, member.left_at)

    def test_host_is_moderator_and_can_end_meeting(self):
        created = self._create()
        join = meetings.join_meeting(str(created.id), self.db, self.host)
        self.assertTrue(join.moderator)
        with self.assertRaises(HTTPException) as not_live:
            meetings.end_meeting(str(created.id), self.db, self.host)
        self.assertEqual(not_live.exception.status_code, 409)

        meetings.enter_meeting(str(created.id), self.db, self.host)
        ended = meetings.end_meeting(str(created.id), self.db, self.host)
        self.assertEqual(ended.status, "ended")
        self.assertIsNotNone(ended.ended_at)
        with self.assertRaises(HTTPException) as raised:
            meetings.join_meeting(str(created.id), self.db, self.guest)
        self.assertEqual(raised.exception.status_code, 409)
        with self.assertRaises(HTTPException) as update_closed:
            meetings.update_meeting(
                str(created.id),
                MeetingUpdate(title="Après clôture"),
                self.db,
                self.host,
            )
        self.assertEqual(update_closed.exception.status_code, 409)
        with self.assertRaises(HTTPException) as invite_closed:
            meetings.invite_members(
                str(created.id),
                MeetingInviteRequest(user_ids=[self.outsider.id]),
                self.db,
                self.host,
            )
        self.assertEqual(invite_closed.exception.status_code, 409)

    def test_cohost_can_manage_and_is_jitsi_moderator(self):
        created = self._create()
        meetings.invite_members(
            str(created.id),
            MeetingInviteRequest(user_ids=[self.guest.id], role="cohost"),
            self.db,
            self.host,
        )
        guest_view = meetings.get_meeting(str(created.id), self.db, self.guest)
        self.assertTrue(guest_view.can_manage)
        self.assertFalse(guest_view.can_delete)
        self.assertEqual(guest_view.current_user_role, "cohost")

        join = meetings.join_meeting(str(created.id), self.db, self.guest)
        self.assertTrue(join.moderator)

        with self.assertRaises(HTTPException) as delete_denied:
            meetings.delete_meeting(str(created.id), self.db, self.guest)
        self.assertEqual(delete_denied.exception.status_code, 403)

    def test_creator_can_delete_scheduled_meeting(self):
        created = self._create()
        host_view = meetings.get_meeting(str(created.id), self.db, self.host)
        self.assertTrue(host_view.can_delete)

        result = meetings.delete_meeting(str(created.id), self.db, self.host)
        self.assertTrue(result["ok"])
        self.assertEqual(
            self.db.query(MeetingMember).filter(
                MeetingMember.meeting_id == created.id
            ).count(),
            0,
        )
        self.assertEqual(
            self.db.query(Notification).filter(
                Notification.related_id == created.id
            ).count(),
            0,
        )
        deletion_notice = self.db.query(Notification).filter(
            Notification.user_id == self.guest.id,
            Notification.type == "meeting_deleted",
        ).one()
        self.assertIsNone(deletion_notice.related_id)
        with self.assertRaises(HTTPException) as missing:
            meetings.get_meeting(str(created.id), self.db, self.host)
        self.assertEqual(missing.exception.status_code, 404)

    def test_live_meeting_must_be_ended_before_cancel_or_delete(self):
        created = self._create()
        meetings.enter_meeting(str(created.id), self.db, self.host)

        with self.assertRaises(HTTPException) as cancel_denied:
            meetings.cancel_meeting(str(created.id), self.db, self.host)
        self.assertEqual(cancel_denied.exception.status_code, 409)

        with self.assertRaises(HTTPException) as delete_denied:
            meetings.delete_meeting(str(created.id), self.db, self.host)
        self.assertEqual(delete_denied.exception.status_code, 409)

        meetings.end_meeting(str(created.id), self.db, self.host)
        self.assertTrue(
            meetings.delete_meeting(str(created.id), self.db, self.host)["ok"]
        )

    def test_club_meeting_requires_responsibility_role(self):
        with self.assertRaises(HTTPException) as raised:
            meetings.create_meeting(
                MeetingCreate(title="Club", scope_type="club"),
                self.db,
                self.host,
            )
        self.assertEqual(raised.exception.status_code, 403)

        self._grant(self.host, "team_leader")
        created = meetings.create_meeting(
            MeetingCreate(title="Club autorisé", scope_type="club"),
            self.db,
            self.host,
        )
        self.assertEqual(created.invited_count, 3)
        outsider_view = meetings.get_meeting(
            str(created.id), self.db, self.outsider
        )
        self.assertEqual(outsider_view.id, created.id)
        invited = self.db.query(Notification).filter(
            Notification.related_id == created.id,
            Notification.type == "meeting_invitation",
        ).count()
        self.assertEqual(invited, 2)

    def test_join_issues_room_scoped_signed_jwt_when_configured(self):
        created = self._create()
        previous = (
            meetings.settings.MEET_JWT_APP_ID,
            meetings.settings.MEET_JWT_SECRET,
            meetings.settings.MEET_JWT_SUBJECT,
        )
        try:
            meetings.settings.MEET_JWT_APP_ID = "enactspace-test"
            meetings.settings.MEET_JWT_SECRET = secrets.token_urlsafe(48)
            meetings.settings.MEET_JWT_SUBJECT = "meet.example.test"
            join = meetings.join_meeting(str(created.id), self.db, self.host)
            self.assertIsNotNone(join.jwt)
            claims = token_jwt.decode(
                join.jwt,
                meetings.settings.MEET_JWT_SECRET,
                algorithms=["HS256"],
                audience=meetings.settings.MEET_JWT_AUDIENCE,
            )
            self.assertEqual(claims["room"], created.room_key)
            self.assertEqual(claims["context"]["user"]["id"], str(self.host.id))
            self.assertTrue(claims["context"]["user"]["moderator"])
        finally:
            (
                meetings.settings.MEET_JWT_APP_ID,
                meetings.settings.MEET_JWT_SECRET,
                meetings.settings.MEET_JWT_SUBJECT,
            ) = previous


if __name__ == "__main__":
    unittest.main()
