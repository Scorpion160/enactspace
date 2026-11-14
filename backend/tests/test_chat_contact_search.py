"""Contact directory query must match all terms without an exact full-name substring."""
from types import SimpleNamespace
from uuid import uuid4

from sqlalchemy.dialects import postgresql

from app.api.routes.chat import list_chat_contacts


class _CapturedQuery:
    def __init__(self):
        self.conditions = []

    def filter(self, *conditions):
        self.conditions.extend(conditions)
        return self

    def distinct(self):
        return self

    def order_by(self, *columns):
        return self

    def limit(self, count):
        assert count == 80
        return self

    def all(self):
        return []


class _FakeDb:
    def __init__(self):
        self.query_obj = _CapturedQuery()

    def query(self, model):
        return self.query_obj


def _where(search):
    db = _FakeDb()
    assert list_chat_contacts(db=db, current_user=SimpleNamespace(id=uuid4()),
                              search=search, scope_type=None, scope_id=None) == []
    return ' '.join(str(expr.compile(dialect=postgresql.dialect(),
                 compile_kwargs={'literal_binds': True})) for expr in db.query_obj.conditions)


def test_search_matches_full_names_with_order_independent_terms():
    sql = _where('Dupont Alice')
    assert 'AND' in sql
    assert '%Dupont%' in sql and '%Alice%' in sql
    assert sql.count('first_name') >= 2
    assert sql.count('last_name') >= 2


def test_search_escapes_user_supplied_wildcard():
    sql = _where('Fat% _T')
    assert '\\%' in sql and '\\_' in sql


def test_empty_contact_search_has_only_visibility_filter():
    assert 'LIKE' not in _where('    ')
