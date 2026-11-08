import unittest

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

import app.models.base  # noqa: F401
from app.db.database import Base
from app.models.recruitment import Application, RecruitmentCampaign
from app.services.recruitment_application_metadata import DISCOVERY_CHANNELS, discovery_answer
from app.services.recruitment_statistics import campaign_statistics, discovery_label


class RecruitmentStatisticsTests(unittest.TestCase):
    def test_explicit_other_channel_is_kept_even_when_its_detail_mentions_a_channel(self):
        self.assertEqual(discovery_label(discovery_answer('other', 'Un atelier vu sur Instagram')), 'Autre')
        self.assertEqual(discovery_label('Un atelier vu sur Instagram'), DISCOVERY_CHANNELS['social_media'])

    def test_study_years_follow_the_esp_curriculum_and_preserve_totals(self):
        engine = create_engine('sqlite://')
        self.addCleanup(engine.dispose)
        Base.metadata.create_all(engine)
        levels = (
            'DUT1', 'Licence 1', 'DST1',
            'DUT2', 'Licence2',
            'Licence 3', 'DIC1', 'DIT1', 'DESCAF1',
            'Master 1', 'DIC2', 'DIT2', 'DESCAF2', ' dic 2 ',
            'Master2', 'DIC3', 'DESCFAF3',
            'DST2', 'Ancien parcours', None,
        )
        with Session(engine) as db:
            campaign = RecruitmentCampaign(title='Campagne fictive')
            db.add(campaign)
            db.flush()
            db.add_all(
                Application(
                    campaign_id=campaign.id, first_name='Candidat', last_name='Fictif',
                    email=f'candidate{index}@example.org', study_level=level,
                )
                for index, level in enumerate(levels)
            )
            db.commit()
            statistics = campaign_statistics(db, campaign.id)

        self.assertEqual(statistics['total'], 20)
        self.assertEqual(
            [(item['label'], item['count'], item['percentage'])
             for item in statistics['breakdowns']['study_year']],
            [('1re année', 3, 15.0), ('2e année', 2, 10.0), ('3e année', 4, 20.0),
             ('4e année', 5, 25.0), ('5e année', 3, 15.0),
             ('Année à préciser', 2, 10.0), ('Non renseigné', 1, 5.0)],
        )
        by_level = {row['label']: row['count'] for row in statistics['breakdowns']['study_level']}
        self.assertEqual(sum(by_level.values()), 20)
        self.assertEqual(by_level['DIC2'], 2)
        self.assertEqual(by_level['DESCAF3'], 1)
        self.assertEqual(by_level['DST2'], 1)
