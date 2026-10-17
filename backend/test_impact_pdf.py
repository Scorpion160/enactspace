"""Focused tests for the official Impact PDF renderer."""

import shutil
import unittest

from app.services.impact_pdf_service import build_impact_summary_pdf


@unittest.skipUnless(shutil.which("pdflatex"), "pdflatex is required")
class ImpactPdfTests(unittest.TestCase):
    def test_pdf_is_valid_and_escapes_untrusted_text(self):
        report = {
            "title": "Synthese Impact Enactus ESP",
            "generated_at": "2026-09-30T18:30:00Z",
            "global_summary": {
                "active_projects": 1,
                "direct_beneficiaries": 20,
                "indirect_beneficiaries": 50,
                "reach": 70,
                "lives_impacted": 20,
                "jobs_created": 2,
                "revenue": 1000,
                "surplus": 100,
                "validated_evidence": 2,
                "touched_sdgs": [7, 12],
            },
            "projects": [
                {
                    "project_name": "Projet 100% solaire & durable_ESP",
                    "summary": "Energie propre #ESP",
                    "key_indicators": {
                        "direct": 20,
                        "indirect": 50,
                        "reach": 70,
                        "jobs_created": 2,
                        "revenue": 1000,
                        "surplus": 100,
                        "evidence": 3,
                        "verified_evidence": 2,
                    },
                    "claims": [],
                    "sdgs": ["ODD 7"],
                    "methodology": "Comptage terrain",
                    "projection": None,
                    "improvement_points": [],
                }
            ],
        }
        pdf = build_impact_summary_pdf(report)
        self.assertTrue(pdf.startswith(b"%PDF-"))
        self.assertGreater(len(pdf), 1000)


if __name__ == "__main__":
    unittest.main()
