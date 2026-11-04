"""Check the additive schema and the open-pair constraint at revision 0034."""
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, inspect
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.alumni import IndividualMentorship
from app.models.user import User


class IndividualMentorshipMigrationTests(unittest.TestCase):
    def test_existing_revision_upgrade_and_open_pair_constraint(self):
        with TemporaryDirectory() as directory:
            url = f"sqlite:///{Path(directory) / 'mentorship.sqlite3'}"
            config = Config("alembic.ini")
            engine = create_engine(url)
            self.addCleanup(engine.dispose)
            with patch.object(settings, "DATABASE_URL", url):
                command.upgrade(config, "20261031_0033")
                # The historical bootstrap uses current metadata. Reproduce a deployed 0033.
                with engine.begin() as connection:
                    IndividualMentorship.__table__.drop(connection, checkfirst=True)
                command.upgrade(config, "20261104_0034")
                self.assertTrue(inspect(engine).has_table("individual_mentorships"))
                with Session(engine) as db:
                    first = User(first_name="First", last_name="Test", email="one@example.test", password_hash="unused")
                    second = User(first_name="Second", last_name="Test", email="two@example.test", password_hash="unused")
                    db.add_all([first, second])
                    db.flush()
                    ids = {"mentor_id": first.id, "mentee_id": second.id}
                    row = IndividualMentorship(**ids, objective="Initial request")
                    db.add(row)
                    db.commit()
                    db.add(IndividualMentorship(**ids, objective="Duplicate"))
                    with self.assertRaises(IntegrityError):
                        db.commit()
                    db.rollback()
                    row.status = "completed"
                    db.add(IndividualMentorship(**ids, objective="New request"))
                    db.commit()
                    self.assertEqual(db.query(IndividualMentorship).count(), 2)
                with self.assertRaisesRegex(RuntimeError, "existing individual mentorships"):
                    command.downgrade(config, "20261031_0033")
