import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.db.database import Base
import app.models.base  # noqa: F401 - register all FK targets
from app.models.archive import ArchiveItem
from app.models.institutional_memory import CanonicalProject
from app.models.impact import ImpactProject
from app.models.project import Project
from app.services.club_heritage_seed import PROJECTS, seed_club_heritage


class ClubHeritageSeedTest(unittest.TestCase):
    def test_seed_preserves_provenance_and_is_idempotent(self):
        engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(engine)
        with Session(engine) as session:
            session.add(Project(name='Dimbali', status='termine'))
            session.commit()
            first = seed_club_heritage(session)
            second = seed_club_heritage(session)
            self.assertEqual(first["archives"], len(PROJECTS))
            self.assertEqual(first["memory"], len(PROJECTS))
            self.assertEqual(first["impact"], 1)
            record = session.query(ImpactProject).one()
            self.assertEqual(record.validation_status, 'EVIDENCE_PENDING')
            self.assertIsNone(record.direct_beneficiaries)
            self.assertEqual(second, {key: 0 for key in second})
            self.assertEqual(session.query(ArchiveItem).count(), len(PROJECTS))
            dimbali = session.query(CanonicalProject).filter_by(slug="dimbali").one()
            self.assertIsNotNone(dimbali.source_id)
            aquatus = session.query(ArchiveItem).filter(
                ArchiveItem.title.like("Aquatus%")).one()
            self.assertIn("prévisionnel", aquatus.description)
            self.assertEqual(aquatus.status, "draft")


if __name__ == "__main__":
    unittest.main()
