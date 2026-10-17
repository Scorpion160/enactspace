import ast
from pathlib import Path
from types import SimpleNamespace
import unittest

try:
    from sqlalchemy import create_engine, Column, Integer, String, or_, exists
    from sqlalchemy.orm import declarative_base, Session
except ImportError:
    Session = None

SOURCE = Path(__file__).resolve().parents[1] / 'app/api/routes/chat.py'

def function(name, namespace):
    node = next(n for n in ast.parse(SOURCE.read_text(encoding='utf-8')).body
                if isinstance(n, ast.FunctionDef) and n.name == name)
    node.decorator_list = []
    for argument in node.args.args + node.args.kwonlyargs:
        argument.annotation = None
    node.returns = None
    node.args.defaults = []
    module = ast.Module(body=[node], type_ignores=[])
    exec(compile(module, str(SOURCE), 'exec'), namespace)
    return namespace[name]

class ThreadNotificationTests(unittest.TestCase):
    def setUp(self):
        self.calls = []
        self.notify = function('notify_group_membership', {
            'notify_users': lambda db, **kw: self.calls.append(kw),
            'user_display_name': lambda user: user.name,
            'thread_notification_name': lambda thread: thread.title,
        })

    def test_empty_private_thread_does_not_notify(self):
        self.notify(None, SimpleNamespace(thread_type='direct'), [2],
                    SimpleNamespace(name='Sady'), 'chat_thread_created')
        self.assertEqual(self.calls, [])

    def test_group_addition_identifies_actor_and_group(self):
        for event in ('chat_thread_created', 'chat_participant_added'):
            self.notify(None, SimpleNamespace(thread_type='group', id=4, title='Projet Dimbali'),
                        [2], SimpleNamespace(name='Sady'), event)
        self.assertEqual(len(self.calls), 2)
        for call in self.calls:
            self.assertIn('Sady vous a ajouté', call['message'])
            self.assertIn('Projet Dimbali', call['message'])
            self.assertEqual(call['user_ids'], [2])

    @unittest.skipIf(Session is None, 'SQLAlchemy unavailable in this Python environment')
    def test_groups_visible_immediately_and_direct_only_after_message(self):
        Base = declarative_base()
        class Thread(Base):
            __tablename__ = 'threads'
            id = Column(Integer, primary_key=True)
            thread_type = Column(String)
            created_by = Column(Integer)
            updated_at = Column(Integer)
        class Participant(Base):
            __tablename__ = 'participants'
            id = Column(Integer, primary_key=True)
            thread_id = Column(Integer)
            user_id = Column(Integer)
        class Message(Base):
            __tablename__ = 'messages'
            id = Column(Integer, primary_key=True)
            thread_id = Column(Integer)
        engine = create_engine('sqlite://')
        Base.metadata.create_all(engine)
        with Session(engine) as db:
            db.add_all([Thread(id=1, thread_type='direct', created_by=1, updated_at=1),
                        Thread(id=2, thread_type='group', created_by=1, updated_at=2),
                        Participant(id=1, thread_id=1, user_id=1),
                        Participant(id=2, thread_id=1, user_id=2),
                        Participant(id=3, thread_id=2, user_id=2)])
            db.commit()
            listing = function('list_threads', dict(ChatThread=Thread,
                ChatParticipant=Participant, ChatMessage=Message, or_=or_, exists=exists,
                build_thread_read=lambda db, thread, viewer: thread.id))
            self.assertEqual(listing(db, SimpleNamespace(id=2)), [2])
            self.assertEqual(listing(db, SimpleNamespace(id=1)), [1])
            db.add(Message(id=1, thread_id=1)); db.commit()
            self.assertEqual(listing(db, SimpleNamespace(id=2)), [2, 1])

if __name__ == '__main__':
    unittest.main()
