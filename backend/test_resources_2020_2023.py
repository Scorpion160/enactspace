import unittest
from app.services.club_voices import MINUTES, MEETING_HIGHLIGHTS
from app.services.project_presentations import CATALOG, get_project_presentation

class ResourceHistoryTests(unittest.TestCase):
    def test_original_six_minutes_retain_2020(self):
        original = [r for r in MINUTES if r["year"] == 2020]
        self.assertEqual(len(original), 6)
        self.assertTrue(any(r["speaker"] == "Ibrahima CISSE" for r in original))

    def test_fourteen_dated_2023_minutes_do_not_invent_quotes(self):
        rows = [r for r in MINUTES if r["year"] == 2023]
        self.assertEqual(len(rows), 14)
        self.assertEqual(len({r["spoken_on"] for r in rows}), 14)
        for row in rows:
            self.assertTrue(row["spoken_on"].startswith("2023-"))
            self.assertIsNone(row["quote"])
            self.assertIsNone(row["original_text"])
            self.assertIsNone(row["image_asset"])
            self.assertGreater(len(row["description"]), 200)
        self.assertFalse(any(r["spoken_on"] in {"2023-01-19", "2023-01-24", "2023-03-07"} for r in rows))

    def test_all_fourteen_curated_visuals_are_referenced(self):
        assets = set()
        for row in list(CATALOG) + MEETING_HIGHLIGHTS:
            assets.add(row.get("image_asset"))
            assets.update(photo["asset"] for photo in row.get("gallery", []))
        resources = {a for a in assets if a and a.startswith("assets/heritage/resources/")}
        self.assertEqual(len(resources), 14)
        self.assertTrue(all(".." not in a and a.endswith(".jpg") for a in resources))

    def test_dimbali_has_historical_period_and_no_fictitious_pdf(self):
        row = get_project_presentation("Dimbali")
        self.assertEqual(row["documents"], [])
        self.assertIn("2018", row["impact_summary"])
        self.assertIn("84", row["impact_summary"])
        self.assertIn("800", row["impact_summary"])
        self.assertTrue(row["image_asset"].startswith("assets/heritage/resources/"))
        self.assertGreaterEqual(len(row["sections"]), 4)

if __name__ == "__main__":
    unittest.main()
