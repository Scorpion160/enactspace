from types import SimpleNamespace
import unittest
from test_chat_thread_notifications import function
from sqlalchemy import create_engine, Column, Integer, String, or_
from sqlalchemy.orm import declarative_base, Session

class SharedContentTests(unittest.TestCase):
    def setUp(self):
        Base = declarative_base()
        class Message(Base):
            __tablename__ = 'shared_messages'
            id = Column(Integer, primary_key=True)
            thread_id = Column(String)
            deleted_at = Column(Integer)
            attachment_url = Column(String)
            content = Column(String)
            created_at = Column(Integer)
        self.Message = Message
        self.engine = create_engine('sqlite://')
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.db.add_all([
            Message(id=1, thread_id='a', content='Photo', attachment_url='/private/1', created_at=1),
            Message(id=2, thread_id='a', content='https://example.org', created_at=2),
            Message(id=3, thread_id='b', content='https://private.org', created_at=3),
            Message(id=4, thread_id='a', content='ordinary text', created_at=4),
            Message(id=5, thread_id='a', content='deleted', attachment_url='/private/5', deleted_at=1, created_at=5),
        ])
        self.db.commit()
        self.checks = []
        self.listing = function('list_shared_messages', {
            'ChatMessage': Message, 'or_': or_,
            'get_participant_or_404': lambda db, thread, user: self.checks.append((thread, user)),
            'serialize_message': lambda message, **kwargs: message.id,
        })
    def tearDown(self):
        self.db.close(); self.engine.dispose()
    def test_only_current_thread_visible_and_non_deleted_shared_items_paginate(self):
        user = SimpleNamespace(id=8)
        self.assertEqual(self.listing('a', self.db, user, 1, 0), [2])
        self.assertEqual(self.listing('a', self.db, user, 1, 1), [1])
        self.assertEqual(self.listing('a', self.db, user, 1, 2), [])
        self.assertEqual(self.checks, [('a', 8)] * 3)
    def test_membership_failure_prevents_returning_any_content(self):
        def denied(*args): raise PermissionError()
        listing = function('list_shared_messages', {
            'ChatMessage': self.Message, 'or_': or_,
            'get_participant_or_404': denied,
            'serialize_message': lambda message, **kwargs: message.id,
        })
        with self.assertRaises(PermissionError):
            listing('a', self.db, SimpleNamespace(id=9), 100, 0)

if __name__ == '__main__': unittest.main()
