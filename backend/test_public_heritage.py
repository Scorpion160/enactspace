import unittest
import test_pr66_memory_heritage as fixtures
from app.api.routes import archives
from app.services.club_heritage import PUBLIC_HERITAGE_MEDIA, enrich_public_heritage

class PublicHeritageTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PR66MemoryHeritageTests()
        self.fixture.setUp()

    def tearDown(self):
        self.fixture.tearDown()

    def media(self, **filters):
        values = dict(search=None, year=None, media_type=None, project_id=None)
        values.update(filters)
        return archives.list_archive_media(db=self.fixture.db, current_user=self.fixture.reader, **values)["media"]

    def test_member_sees_recovered_trophies_and_official_sources(self):
        rows = self.media()
        self.assertEqual(len(rows), len(PUBLIC_HERITAGE_MEDIA))
        self.assertEqual(len({r["id"] for r in rows}), len(rows))
        self.assertTrue(all(r["verified"] and r["source_label"] for r in rows))
        trophy = next(r for r in rows if r["id"] == "trophees-national-2016")
        self.assertEqual(trophy["year"], 2016)
        self.assertEqual(trophy["image_asset"], "assets/img/prix_enactus_national_2016.png")
        self.assertTrue(all(r["source_url"].startswith("https://") for r in rows if r["source_url"]))

    def test_media_filters_keep_year_type_project_and_search(self):
        self.assertEqual(len(self.media(year=2016, media_type="photo")), 2)
        self.assertEqual([r["id"] for r in self.media(project_id="aquatus")], ["aquatus-official-photo"])
        self.assertEqual([r["id"] for r in self.media(search="uhodari")], ["trophee-uhodari-2016"])
        self.assertEqual(self.media(year=1999), [])
        self.assertEqual(self.media(project_id="private-unrelated-project"), [])

    def test_publication_enrichment_is_repeatable_and_preserves_impact(self):
        projects = [{"id":"shery","impact_summary":"Approved result"},{"id":"dimbali","impact_summary":"Approved historical result"}]
        awards = []
        competitions = [{"id":"world-cup-2022","result":"Participation"}]
        hall = []
        enrich_public_heritage(projects, awards, competitions, hall)
        enrich_public_heritage(projects, awards, competitions, hall)
        self.assertEqual(projects[0]["impact_summary"], "Approved result")
        self.assertEqual(projects[1]["impact_summary"], "Approved historical result")
        self.assertEqual(competitions[0]["result"], "Demi-finaliste")
        self.assertEqual(sum(r["id"] == "polytech-innovation-2025" for r in competitions), 1)

    def test_unattributed_gallery_images_have_no_invented_dates(self):
        images = [r for r in PUBLIC_HERITAGE_MEDIA if r["id"].startswith("official-gallery-")]
        self.assertEqual(len(images), 8)
        self.assertTrue(all(r["year"] is None and r["project_id"] is None for r in images))
        self.assertTrue(all(r["description"].strip() for r in images))

    def test_every_project_has_a_story_without_rewriting_impact(self):
        from copy import deepcopy
        projects = deepcopy(archives.INITIAL_HISTORICAL_PROJECTS)
        impact_before = {row["id"]: row["impact_summary"] for row in projects}
        enrich_public_heritage(projects, [], [], [])
        first = deepcopy(projects)
        enrich_public_heritage(projects, [], [], [])
        self.assertEqual(projects, first)
        self.assertEqual({row["id"]: row["impact_summary"] for row in projects}, impact_before)
        for row in projects:
            self.assertGreaterEqual(len(row["description"].split()), 30)
            self.assertTrue(row["story_sections"])
        cajor = next(row for row in projects if row["id"] == "cajor")
        self.assertIsNone(cajor["problem"])
        self.assertIsNone(cajor["solution"])

    def test_competition_stories_link_real_projects(self):
        ids = {row["id"] for row in archives.INITIAL_HISTORICAL_PROJECTS}
        for row in archives.INITIAL_COMPETITIONS:
            self.assertGreaterEqual(len(row["story_sections"]), 2)
            self.assertTrue(set(row["project_ids"]).issubset(ids))
        cup = next(row for row in archives.INITIAL_COMPETITIONS if row["id"] == "world-cup-2018")
        self.assertEqual(cup["project_ids"], ["dimbali", "deconaane"])
        self.assertIn("San José", cup["location"])

    def test_trophy_caption_uses_only_the_club_phototheque(self):
        trophy = next(row for row in self.media() if row["id"] == "trophees-national-2016")
        self.assertEqual(trophy["source_label"], "Photothèque Enactus ESP")
        self.assertNotIn("première version", str(self.media()))

if __name__ == "__main__":
    unittest.main()
