import ast
from pathlib import Path
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
            content = Column(String)
            message_type = Column(String, default="text")
            created_at = Column(Integer)
        self.Message = Message
        self.engine = create_engine('sqlite://')
        Base.metadata.create_all(self.engine)
        self.db = Session(self.engine)
        self.db.add_all([
            Message(id=1, thread_id='a', content='Photo', message_type='image', created_at=1),
            Message(id=2, thread_id='a', content='https://example.org', created_at=2),
            Message(id=3, thread_id='b', content='https://private.org', created_at=3),
            Message(id=4, thread_id='a', content='ordinary text', created_at=4),
            Message(id=6, thread_id='a', content='GIF', message_type='sticker', created_at=0),
            Message(id=5, thread_id='a', content='deleted', message_type='image', deleted_at=1, created_at=5),
        ])
        self.db.commit()
        self.checks = []
        self.listing = function('list_shared_messages', {
            'ChatMessage': Message, 'or_': or_, 'MEDIA_MESSAGE_TYPES': {'image', 'video', 'audio', 'document', 'sticker'},
            'get_participant_or_404': lambda db, thread, user: self.checks.append((thread, user)),
            'serialize_message': lambda message, **kwargs: message.id,
        })
    def test_query_references_only_columns_present_in_actual_model(self):
        backend = Path(__file__).resolve().parents[1]
        model_tree = ast.parse((backend / 'app/models/chat.py').read_text())
        model = next(node for node in model_tree.body if isinstance(node, ast.ClassDef) and node.name == 'ChatMessage')
        fields = {node.target.id for node in model.body if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name)}
        route_tree = ast.parse((backend / 'app/api/routes/chat.py').read_text())
        route = next(node for node in route_tree.body if isinstance(node, ast.FunctionDef) and node.name == 'list_shared_messages')
        references = {node.attr for node in ast.walk(route) if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name) and node.value.id == 'ChatMessage'}
        self.assertTrue(references <= fields, references - fields)

    def tearDown(self):
        self.db.close(); self.engine.dispose()
    def test_only_current_thread_visible_and_non_deleted_shared_items_paginate(self):
        user = SimpleNamespace(id=8)
        self.assertEqual(self.listing('a', self.db, user, 1, 0), [2])
        self.assertEqual(self.listing('a', self.db, user, 1, 1), [1])
        self.assertEqual(self.listing('a', self.db, user, 1, 2), [6])
        self.assertEqual(self.checks, [('a', 8)] * 3)
    def test_membership_failure_prevents_returning_any_content(self):
        def denied(*args): raise PermissionError()
        listing = function('list_shared_messages', {
            'ChatMessage': self.Message, 'or_': or_, 'MEDIA_MESSAGE_TYPES': {'image', 'video', 'audio', 'document', 'sticker'},
            'get_participant_or_404': denied,
            'serialize_message': lambda message, **kwargs: message.id,
        })
        with self.assertRaises(PermissionError):
            listing('a', self.db, SimpleNamespace(id=9), 100, 0)

if __name__ == '__main__': unittest.main()
