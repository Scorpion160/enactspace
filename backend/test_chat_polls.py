"""Focused durable chat poll regressions."""

import os
import unittest
import uuid
from datetime import timedelta

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", "chat-polls-test-secret")
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.routes import chat, files
from app.core.time import utc_now
from app.db.database import Base
from app.models.chat import ChatParticipant, ChatPollOption, ChatPollVote, ChatThread
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.chat import ChatMessageCreate, ChatPollCreate, ChatPollVoteCreate


class ChatPollTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine, autoflush=False)
        self.db = self.Session()
        self.user = User(
            first_name="Poll",
            last_name="Member",
            email=f"poll-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(self.user)
        self.db.flush()
        self.thread = ChatThread(title="Poll test", created_by=self.user.id)
        self.db.add(self.thread)
        self.db.flush()
        self.db.add(ChatParticipant(
            thread_id=self.thread.id,
            user_id=self.user.id,
            participant_role="member",
        ))
        self.db.commit()

    def tearDown(self):
        self.db.close()
        Base.metadata.drop_all(self.engine)
        self.engine.dispose()

    def _create_poll(
        self,
        *,
        allows_multiple=False,
        closes_at=None,
        client_message_id=None,
    ):
        return chat.create_poll(
            str(self.thread.id),
            ChatPollCreate(
                question="Quel choix ?",
                options=["Option A", "Option B", "Option C"],
                allows_multiple=allows_multiple,
                closes_at=closes_at,
                client_message_id=client_message_id,
            ),
            self.db,
            self.user,
        )
    def test_content_only_sticker_is_a_valid_chat_message(self):
        message = chat.send_message(
            str(self.thread.id),
            ChatMessageCreate(
                content="🚀",
                message_type="sticker",
                sticker_pack="enactspace_emoji_v1",
            ),
            self.db,
            self.user,
        )
        self.assertEqual(message["message_type"], "sticker")
        self.assertEqual(message["content"], "🚀")
        self.assertEqual(message["sticker_pack"], "enactspace_emoji_v1")
        self.assertIsNone(message["attachment_url"])

    def test_chat_media_is_readable_by_participant_but_not_outsider(self):
        recipient = User(
            first_name="Chat",
            last_name="Recipient",
            email=f"recipient-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        outsider = User(
            first_name="Chat",
            last_name="Outsider",
            email=f"outsider-{uuid.uuid4().hex}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add_all([recipient, outsider])
        self.db.flush()
        self.db.add(
            ChatParticipant(
                thread_id=self.thread.id,
                user_id=recipient.id,
                participant_role="member",
            )
        )
        stored_file = StoredFile(
            original_filename="voice.m4a",
            stored_filename="voice.m4a",
            mime_type="audio/mp4",
            file_size=128,
            extension="m4a",
            storage_path="chat/voice.m4a",
            storage_scope="chat",
            uploaded_by_id=self.user.id,
            visibility="participants",
            entity_type="chat_thread",
            entity_id=self.thread.id,
            is_temporary=True,
        )
        self.db.add(stored_file)
        self.db.commit()

        files.ensure_file_access(self.db, stored_file, recipient)
        with self.assertRaises(HTTPException) as raised:
            files.ensure_file_access(self.db, stored_file, outsider)
        self.assertEqual(raised.exception.status_code, 403)

    def test_create_poll_exposes_ordered_options(self):
        message = self._create_poll()
        self.assertEqual(message["message_type"], "poll")
        self.assertIsNotNone(message["poll"])
        self.assertEqual(message["poll"].question, "Quel choix ?")
        self.assertEqual(
            [option.label for option in message["poll"].options],
            ["Option A", "Option B", "Option C"],
        )

    def test_client_message_id_is_idempotent(self):
        first = self._create_poll(client_message_id="offline-poll-1")
        second = self._create_poll(client_message_id="offline-poll-1")
        self.assertEqual(first["id"], second["id"])
        self.assertEqual(
            self.db.query(chat.ChatPoll).count(),
            1,
        )

    def test_duplicate_options_are_rejected(self):
        with self.assertRaises(HTTPException) as raised:
            chat.create_poll(
                str(self.thread.id),
                ChatPollCreate(question="Q", options=["Oui", " oui "]),
                self.db,
                self.user,
            )
        self.assertEqual(raised.exception.status_code, 400)
    def test_single_choice_rejects_multiple_options(self):
        message = self._create_poll()
        option_ids = [option.id for option in message["poll"].options[:2]]
        with self.assertRaises(HTTPException) as raised:
            chat.vote_poll(
                str(self.thread.id),
                str(message["poll"].id),
                ChatPollVoteCreate(option_ids=option_ids),
                self.db,
                self.user,
            )
        self.assertEqual(raised.exception.status_code, 400)

    def test_single_choice_vote_can_be_replaced_and_cleared(self):
        message = self._create_poll()
        first_id = message["poll"].options[0].id
        second_id = message["poll"].options[1].id
        result = chat.vote_poll(
            str(self.thread.id), str(message["poll"].id),
            ChatPollVoteCreate(option_ids=[first_id]), self.db, self.user,
        )
        self.assertEqual(result.total_votes, 1)
        result = chat.vote_poll(
            str(self.thread.id), str(message["poll"].id),
            ChatPollVoteCreate(option_ids=[second_id]), self.db, self.user,
        )
        self.assertEqual(result.total_votes, 1)
        self.assertEqual(self.db.query(ChatPollVote).count(), 1)
        cleared = chat.clear_poll_vote(
            str(self.thread.id), str(message["poll"].id), self.db, self.user,
        )
        self.assertEqual(cleared.total_votes, 0)
        self.assertEqual(self.db.query(ChatPollVote).count(), 0)

    def test_multiple_choice_counts_votes_and_voters(self):
        message = self._create_poll(allows_multiple=True)
        selected = [option.id for option in message["poll"].options[:2]]
        result = chat.vote_poll(
            str(self.thread.id), str(message["poll"].id),
            ChatPollVoteCreate(option_ids=selected), self.db, self.user,
        )
        self.assertEqual(result.total_votes, 2)
        self.assertEqual(result.total_voters, 1)
        self.assertEqual(
            sum(1 for option in result.options if option.current_user_voted),
            2,
        )

    def test_foreign_option_is_rejected(self):
        first = self._create_poll()
        second = self._create_poll(client_message_id="second-poll")
        foreign_id = second["poll"].options[0].id
        with self.assertRaises(HTTPException) as raised:
            chat.vote_poll(
                str(self.thread.id), str(first["poll"].id),
                ChatPollVoteCreate(option_ids=[foreign_id]), self.db, self.user,
            )
        self.assertEqual(raised.exception.status_code, 400)
    def test_closed_poll_rejects_vote(self):
        message = self._create_poll(closes_at=utc_now() + timedelta(minutes=5))
        poll = self.db.get(chat.ChatPoll, message["poll"].id)
        poll.closes_at = utc_now() - timedelta(seconds=1)
        self.db.commit()
        with self.assertRaises(HTTPException) as raised:
            chat.vote_poll(
                str(self.thread.id), str(message["poll"].id),
                ChatPollVoteCreate(option_ids=[message["poll"].options[0].id]),
                self.db, self.user,
            )
        self.assertEqual(raised.exception.status_code, 409)


if __name__ == "__main__":
    unittest.main()
