import unittest
from uuid import uuid4
from pydantic import ValidationError
from app.schemas.recruitment import ApplicationCreate
from app.services.recruitment_application_metadata import academic_year, discovery_answer


class ApplicationMetadataTests(unittest.TestCase):
    def payload(self, **changes):
        data = dict(campaign_id=uuid4(), first_name='Awa', last_name='Test',
                    gender='femme', email='awa@example.org', phone='+221770000000',
                    department='Génie Informatique', study_level='Master1')
        data.update(changes)
        return ApplicationCreate(**data)

    def test_years_are_consecutive_and_canonical(self):
        for year in ['2025-2026', '2023-2024']:
            self.assertEqual(self.payload(promotion_academic_year=year).class_name, year)
        for year in ['2025', 'DIC3', '2025-2027', '2025-2025', '1899-1900']:
            with self.assertRaises(ValidationError):
                self.payload(promotion_academic_year=year)
        self.assertEqual(academic_year(' 2025-2026 '), '2025-2026')

    def test_all_channels_and_other(self):
        for code in ['social_media', 'activities', 'member', 'teaching', 'poster', 'web']:
            self.assertEqual(self.payload(discovery_channel=code).known_enactus_from, discovery_answer(code))
        self.assertEqual(self.payload(discovery_channel='other', discovery_other=' Radio ').known_enactus_from, 'Autre : Radio')
        for changes in [dict(discovery_channel='unknown'), dict(discovery_channel='other'),
                        dict(discovery_channel='other', discovery_other=' '),
                        dict(discovery_channel='other', discovery_other='x' * 201),
                        dict(discovery_channel='member', discovery_other='Radio'),
                        dict(discovery_other='Radio')]:
            with self.assertRaises(ValidationError):
                self.payload(**changes)

    def test_conflicts_rejected_and_legacy_kept(self):
        with self.assertRaises(ValidationError):
            self.payload(promotion_academic_year='2025-2026', class_name='2023-2024')
        with self.assertRaises(ValidationError):
            self.payload(discovery_channel='member', known_enactus_from='Autre chose')
        old = self.payload(class_name='Ancienne classe', known_enactus_from='Un ami sur le campus')
        self.assertEqual(old.class_name, 'Ancienne classe')
        self.assertEqual(old.known_enactus_from, 'Un ami sur le campus')


if __name__ == '__main__':
    unittest.main()
