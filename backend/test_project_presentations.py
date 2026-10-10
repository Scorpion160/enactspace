import unittest
from copy import deepcopy
from datetime import datetime
from uuid import uuid4

from app.services.project_presentations import (
    CATALOG, get_project_presentation, enrich_project_archive, enrich_project_archives,
)
from app.schemas.project import ProjectRead


class ProjectPresentationTests(unittest.TestCase):
    def test_accented_and_historical_names_resolve_exactly(self):
        for name in ("Mën Nañ", "Men Nan", "MËN NAÑ", "meune-nagn"):
            self.assertEqual(get_project_presentation(name)["id"], "meune-nagn")
        self.assertEqual(get_project_presentation("  AQUATUS  ")["id"], "aquatus")
        self.assertEqual(get_project_presentation("Terrassen")["id"], "terrasen")

    def test_unrelated_project_is_never_matched_by_substring(self):
        for name in (None, "", "Aquatus bis", "Autre projet", "SHERY partenaire"):
            self.assertIsNone(get_project_presentation(name))

    def test_returns_detached_values(self):
        value = get_project_presentation("Aquatus")
        value["documents"].clear()
        value["sections"][0]["body"] = "modified"
        self.assertEqual(len(get_project_presentation("Aquatus")["documents"]), 1)
        self.assertNotEqual(get_project_presentation("Aquatus")["sections"][0]["body"], "modified")

    def test_archive_enrichment_is_repeatable(self):
        rows = [{"name": row["name"], "id": row["id"]} for row in CATALOG]
        enrich_project_archives(rows)
        once = deepcopy(rows)
        enrich_project_archives(rows)
        self.assertEqual(rows, once)
        self.assertEqual([r["reference_documents"][0]["pages"] for r in rows if r["reference_documents"]], [28, 10, 9, 26])

    def test_persisted_editorial_fields_remain_owned_by_the_curator(self):
        row = {"name": "Aquatus", "description": "Travail actuel",
               "impact_summary": "Bilan approuvé", "document_ids": ["own-document"]}
        enrich_project_archive(row)
        self.assertEqual(row["description"], "Travail actuel")
        self.assertEqual(row["impact_summary"], "Bilan approuvé")
        self.assertEqual(row["document_ids"], ["own-document"])
        self.assertEqual(row["presentation"]["id"], "aquatus")

    def test_existing_project_response_adds_presentation_without_changing_fields(self):
        row = dict(id=uuid4(),season_id=None,name="Terrasen",description="Texte actuel",
                   problem_statement="Besoin actuel",solution="Solution actuelle",
                   objectives="Objectifs actuels",expected_impact=None,budget_estimated=300,
                   status="prototype",started_at=None,ended_at=None,created_at=datetime.now())
        original=deepcopy(row)
        model=ProjectRead.model_validate(row)
        value=model.model_dump()
        self.assertEqual(row, original)
        self.assertEqual(value["description"], "Texte actuel")
        self.assertEqual(value["budget_estimated"],300)
        self.assertEqual(value["status"],"prototype")
        self.assertEqual(value["presentation"]["id"],"terrasen")

    def test_unknown_project_serializes_without_a_presentation(self):
        row=dict(id=uuid4(),season_id=None,name="Projet nouveau",description=None,
                 problem_statement=None,solution=None,objectives=None,expected_impact=None,
                 budget_estimated=0,status="idee",started_at=None,ended_at=None,created_at=datetime.now())
        self.assertIsNone(ProjectRead.model_validate(row).model_dump()["presentation"])

    def test_documents_stay_in_the_bundled_catalog(self):
        expected={"assets/documents/aquatus-synthese.pdf", "assets/documents/shery-presentation.pdf",
                  "assets/documents/men-nan-presentation.pdf", "assets/documents/terrasen-world-cup.pdf"}
        self.assertEqual({d["asset"] for p in CATALOG for d in p["documents"]},expected)
        self.assertEqual(len(CATALOG),5)

    def test_local_balances_keep_their_periods_and_no_new_global_total(self):
        terrasen=get_project_presentation("Terrasen")
        self.assertIn("août 2025",terrasen["impact_summary"])
        self.assertIn("provisoire",terrasen["impact_summary"])
        self.assertIn("1 416 250",terrasen["impact_summary"])
        self.assertNotIn("impacted_lives",terrasen)
        aquatus=get_project_presentation("Aquatus")
        self.assertIn("objectifs à mesurer",aquatus["impact_summary"])

if __name__ == "__main__":
    unittest.main()
