import unittest

from pydantic import ValidationError

from app.api.routes import academy, recruitment
from app.schemas.recruitment import (
    RecruitmentCampaignCreate,
    RecruitmentCampaignPublicRead,
    RecruitmentCommunicationAction,
    RecruitmentInterviewQuestion,
    RecruitmentPosition,
)


class RecruitmentPreparationTests(unittest.TestCase):
    def test_campaign_preparation_is_structured_and_profiles_are_cleaned(self):
        payload = RecruitmentCampaignCreate(
            title="Campagne 2026",
            target_headcount=20,
            positions=[
                {"title": "  Responsable terrain  ", "headcount": 2},
            ],
            target_profiles=["  Technique  ", " ", "Gestion"],
            communication_actions=[
                {"action": "  Publication de lancement  ", "channel": " Instagram "},
            ],
            interview_questions=[
                {"question": "  Pourquoi Enactus ?  ", "category": " Motivation "},
            ],
        )
        self.assertEqual(payload.positions[0].title, "Responsable terrain")
        self.assertEqual(payload.positions[0].headcount, 2)
        self.assertEqual(payload.target_profiles, ["Technique", "Gestion"])
        self.assertEqual(payload.communication_actions[0].action, "Publication de lancement")
        self.assertEqual(payload.communication_actions[0].channel, "Instagram")
        self.assertEqual(payload.interview_questions[0].question, "Pourquoi Enactus ?")
        self.assertEqual(payload.interview_questions[0].category, "Motivation")

    def test_position_headcount_must_be_positive(self):
        with self.assertRaises(ValidationError):
            RecruitmentPosition(title="Membre terrain", headcount=0)
        with self.assertRaises(ValidationError):
            RecruitmentCampaignCreate(title="Campagne", target_headcount=0)

    def test_structured_required_text_rejects_whitespace_only(self):
        invalid_factories = (
            lambda: RecruitmentPosition(title="   "),
            lambda: RecruitmentCommunicationAction(action="   "),
            lambda: RecruitmentInterviewQuestion(question="   "),
        )
        for factory in invalid_factories:
            with self.subTest(factory=factory):
                with self.assertRaises(ValidationError):
                    factory()

    def test_public_campaign_schema_does_not_expose_internal_preparation(self):
        internal_fields = {
            "target_headcount",
            "positions",
            "target_profiles",
            "communication_actions",
            "interview_questions",
        }
        self.assertTrue(
            internal_fields.isdisjoint(RecruitmentCampaignPublicRead.model_fields)
        )

    def test_academy_new_member_path_is_the_enacteur_path(self):
        path = academy.ROLE_BASED_PATHS["enacteur"]
        self.assertEqual(path["id"], "new-enacteur")
        self.assertEqual(path["title"], "Nouveau Enacteur")
        self.assertTrue(path["course_ids"])

    def test_member_onboarding_payload_points_to_existing_product_surfaces(self):
        payload = recruitment.member_onboarding_payload()
        self.assertEqual(payload["academy_path_id"], "new-enacteur")
        routes = {item["route"] for item in payload["checklist"]}
        self.assertEqual(
            routes,
            {"/help", "/academy", "/poles", "/members", "/documents", "/projects"},
        )


if __name__ == "__main__":
    unittest.main()
