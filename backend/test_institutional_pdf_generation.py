import os
import shutil
import unittest
from datetime import date, datetime

os.environ.setdefault("DATABASE_URL", "sqlite:///institutional-pdf-import.db")
os.environ.setdefault("SECRET_KEY", "unit-test-institutional-pdf-secret")

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.database import Base
import app.models.base  # noqa: F401
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.pole import Pole, PoleMember
from app.models.project import Project
from app.models.role import Role, UserRole
from app.models.season import Season
from app.models.user import User
from app.services.institutional_pdf_service import (
    RESOURCE_ROOT,
    build_data_tex,
    compile_request_pdf,
    latex_escape,
)


class InstitutionalPdfGenerationTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite:///:memory:")
        Base.metadata.create_all(self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()

        self.season = Season(
            name="2026-2027",
            start_date=date(2026, 9, 1),
            end_date=date(2027, 8, 31),
            is_current=True,
            archived=False,
        )
        self.veille = Pole(name="Pôle Veille", short_name="Veille", type="support")
        self.tech = Pole(name="Pôle IT", short_name="IT", type="support")
        self.project = Project(name="Hydro-Connect", status="pilote")
        self.db.add_all([self.season, self.veille, self.tech, self.project])
        self.db.flush()

        self.member = self._user("membre@example.com", "Awa", "Ndiaye")
        self.veille_lead = self._user("veille@example.com", "Moussa", "Diop")
        self.sg = self._user("sg@example.com", "Fatou", "Fall")
        self.tl = self._user("tl@example.com", "Cheikh", "Sarr")
        self._role(self.sg, "secretaire_generale")
        self._role(self.tl, "team_leader")
        self.db.add(
            PoleMember(
                pole_id=self.veille.id,
                user_id=self.veille_lead.id,
                position="chef_pole",
                is_active=True,
            )
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def _user(self, email, first, last):
        user = User(
            first_name=first,
            last_name=last,
            email=email,
            phone="770000000",
            department="Génie informatique",
            study_level="DIC 2",
            password_hash="not-used",
            status="active",
            email_verified=True,
            is_active=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def _role(self, user, role_name):
        role = self.db.query(Role).filter(Role.name == role_name).first()
        if role is None:
            role = Role(name=role_name)
            self.db.add(role)
            self.db.flush()
        self.db.add(UserRole(user_id=user.id, role_id=role.id))
        self.db.flush()

    def _request(self, template_code, payload, *, pole_id=None, project_id=None, requested_by=None):
        item = InstitutionalDocumentRequest(
            template_code=template_code,
            template_version="2.0",
            status="validated",
            payload_json=payload,
            requested_by=(requested_by or self.member).id,
            submitted_by=(requested_by or self.member).id,
            submitted_at=datetime.utcnow(),
            sg_validated_by=self.sg.id,
            sg_validated_at=datetime.utcnow(),
            approved_by=self.tl.id,
            approved_at=datetime.utcnow(),
            pole_id=pole_id,
            project_id=project_id,
            season_id=self.season.id,
            official_reference=f"EESP/TEST/2026-2027/{template_code[:3].upper()}",
        )
        self.db.add(item)
        self.db.flush()
        return item

    def _payloads(self):
        member_id = str(self.member.id)
        sg_id = str(self.sg.id)
        tl_id = str(self.tl.id)
        common_meeting = {
            "meeting_date": "2026-09-13",
            "start_time": "15:00",
            "end_time": "17:00",
            "location": "ESP - salle 12",
            "chairperson_id": tl_id,
            "secretary_id": sg_id,
            "participants": [member_id, sg_id, tl_id],
            "absentees": [],
            "agenda": ["Suivi des activités", "Plan d'action"],
            "discussion_points": [
                {"title": "Suivi", "details": "Avancement satisfaisant & prochain jalon."}
            ],
            "action_plan": [
                {
                    "action": "Finaliser le livrable #1",
                    "responsible": member_id,
                    "deadline": "2026-09-20",
                    "status": "À faire",
                }
            ],
        }
        return {
            "pv_pole": {
                **common_meeting,
                "reminders": "Respecter les délais\nMettre à jour les tâches",
                "decisions": [
                    {"title": "Répartition", "details": "Le plan d'action est adopté."}
                ],
                "escalations": "Besoin d'un arbitrage sur le budget",
                "miscellaneous": "Néant",
                "enactor_minute": "Empowering our society is our priority",
                "next_meeting": "2026-09-20T15:00:00",
            },
            "pv_projet": {
                **common_meeting,
                "project_phase": "Pilote",
                "deliverables": [
                    {"title": "Prototype", "details": "Version terrain terminée"}
                ],
                "kpis": [
                    {"title": "Tests réussis", "details": "8 sur 10"}
                ],
                "risks": [
                    {"title": "Approvisionnement", "details": "Délai fournisseur"}
                ],
                "needs": "Validation terrain",
                "decisions": [
                    {"title": "Déploiement", "details": "Pilote maintenu"}
                ],
                "next_review": "2026-09-27T15:00:00",
            },
            "pv_reunion_generale": {
                **common_meeting,
                "announcements": "Rentrée Enactus\nLancement Academy",
                "quorum": 42,
                "pole_updates": [
                    {"title": "Pôle IT", "details": "EnactSpace avance"}
                ],
                "project_updates": [
                    {"title": "Hydro-Connect", "details": "Prototype finalisé"}
                ],
                "votes": [
                    {"title": "Adoption du calendrier", "for": 31, "against": 2, "abstain": 3}
                ],
                "decisions": [
                    {"title": "Calendrier", "details": "Adopté à la majorité"}
                ],
                "miscellaneous": "Questions diverses traitées",
                "enactor_minute": "Merci à tous",
                "next_meeting": "2026-09-27T15:00:00",
            },
            "pv_enacchef": {
                **common_meeting,
                "strategic_topics": [
                    {"title": "Gouvernance", "details": "Arbitrage validé"}
                ],
                "governance": "Organisation de la saison",
                "pole_followup": [
                    {"title": "Pôle Veille", "details": "Suivi assiduité renforcé"}
                ],
                "project_followup": [
                    {"title": "Hydro-Connect", "details": "Phase pilote"}
                ],
                "member_cases": [
                    {"title": "Cas individuel", "details": "Suivi confidentiel"}
                ],
                "decisions": [
                    {"title": "Arbitrage", "details": "Décision actée"}
                ],
                "club_communications": "Communiquer le calendrier uniquement",
                "next_meeting": "2026-09-20T18:00:00",
            },
            "autorisation_parentale_voyage": {
                "member_id": member_id,
                "trip_type": "voyage d'immersion",
                "trip_purpose": "mission terrain",
                "destination": "Thiès",
                "departure_at": "2026-10-10T08:00:00",
                "return_at": "2026-10-11T18:00:00",
                "meeting_point": "ESP - entrée principale",
                "transport": "Bus ESP",
                "accommodation": "Centre partenaire",
                "coverage": "Transport et hébergement pris en charge",
                "supervision": "encadrement par l'équipe Enactus ESP",
                "trip_leader_id": tl_id,
                "trip_leader_phone": "770000000",
                "additional_information": "Prévoir une pièce d'identité",
            },
            "demande_rse": {
                "company": "Entreprise Exemple SA",
                "recipient_name": "Direction RSE",
                "recipient_role": "Responsable RSE",
                "recipient_address": "Dakar, Sénégal",
                "initiative": "Projet Impact",
                "context": "Accès à l'eau & résilience",
                "beneficiaries": "100 ménages",
                "territory": "Thiès",
                "objectives": ["Réduire les pertes", "Améliorer le suivi"],
                "expected_impact": "Réduire les pertes de 20%",
                "sdgs": ["ODD 6", "ODD 9"],
                "measurable_results": [
                    {"title": "Ménages équipés", "details": "100"},
                    {"title": "Pertes réduites", "details": "20%"},
                ],
                "request_description": "Appui matériel et expertise",
                "requested_value": "2 000 000 FCFA",
                "implementation_period": "Octobre 2026 - mars 2027",
                "partner_value": "Reporting d'impact trimestriel",
                "attachments": ["Note conceptuelle", "Budget"],
                "contact_name": "Fatou Fall",
                "contact_phone": "770000000",
                "contact_email": "enactus@esp.sn",
            },
            "demande_bus": {
                "recipient_organization": "École Supérieure Polytechnique",
                "recipient_name": "Cheffe des Services Administratifs",
                "trip_purpose": "immersion terrain",
                "linked_activity": "Mission Hydro-Connect",
                "departure_at": "2026-10-10T08:00:00",
                "departure_place": "ESP",
                "return_at": "2026-10-11T18:00:00",
                "return_place": "ESP",
                "passenger_count": 25,
                "requested_capacity": 30,
                "route": [
                    {"from": "ESP", "to": "Thiès", "distance_km": 70},
                    {"from": "Thiès", "to": "ESP", "distance_km": 70},
                ],
                "group_leader_id": tl_id,
                "group_leader_phone": "770000000",
                "justification": "Déplacement collectif du club",
                "observations": "Départ souhaité à 08h00",
            },
            "notification_renvoi": {
                "member_id": member_id,
                "member_role": "Membre du Pôle IT",
                "decision_date": "2026-09-12",
                "decision_body": "Pôle Veille et instances compétentes",
                "effective_date": "2026-09-13",
                "facts": "Absences répétées malgré les relances. % test \\input{evil}",
                "prior_warnings": "Deux rappels écrits",
                "procedure_history": "Situation revue lors du suivi hebdomadaire",
                "consequences": "Retrait de la liste des membres actifs",
                "return_instructions": "Restituer tout matériel appartenant au club",
                "review_process": "Réexamen possible sur présentation d'un justificatif",
            },
        }

    def test_latex_escape_neutralizes_control_characters(self):
        escaped = latex_escape(r"100% & \\input{evil}_#${}~^")
        self.assertNotIn(r"\\input{evil}", escaped)
        self.assertIn(r"\%", escaped)
        self.assertIn(r"\&", escaped)
        self.assertIn(r"\textbackslash{}", escaped)

    def test_all_eight_templates_are_packaged(self):
        expected = set(self._payloads())
        packaged = {path.stem for path in (RESOURCE_ROOT / "templates").glob("*.tex")}
        self.assertEqual(packaged, expected)

    def test_data_generation_never_injects_raw_input_command(self):
        payload = self._payloads()["notification_renvoi"]
        request = self._request(
            "notification_renvoi",
            payload,
            pole_id=self.veille.id,
            requested_by=self.veille_lead,
        )
        data_tex = build_data_tex(self.db, request)
        self.assertNotIn(r"\\input{evil}", data_tex)
        self.assertIn(r"\textbackslash{}input\{evil\}", data_tex)

    def test_structured_fields_are_rendered_without_python_repr(self):
        cases = (
            ("pv_projet", self._payloads()["pv_projet"], {"project_id": self.project.id}, self.member),
            ("pv_reunion_generale", self._payloads()["pv_reunion_generale"], {}, self.member),
            ("pv_enacchef", self._payloads()["pv_enacchef"], {}, self.member),
            ("demande_rse", self._payloads()["demande_rse"], {}, self.member),
        )
        for code, payload, kwargs, author in cases:
            with self.subTest(template=code):
                request = self._request(code, payload, requested_by=author, **kwargs)
                data_tex = build_data_tex(self.db, request)
                self.assertNotIn("[{'", data_tex)
                self.assertNotIn("'}]", data_tex)

    @unittest.skipUnless(shutil.which("pdflatex"), "pdflatex not installed")
    def test_all_eight_templates_compile_to_pdf(self):
        for code, payload in self._payloads().items():
            with self.subTest(template=code):
                kwargs = {}
                author = self.member
                if code == "pv_pole":
                    kwargs["pole_id"] = self.tech.id
                if code == "pv_projet":
                    kwargs["project_id"] = self.project.id
                if code == "notification_renvoi":
                    kwargs["pole_id"] = self.veille.id
                    author = self.veille_lead
                request = self._request(code, payload, requested_by=author, **kwargs)
                pdf = compile_request_pdf(self.db, request)
                self.assertTrue(pdf.startswith(b"%PDF-"))
                self.assertGreater(len(pdf), 1000)


if __name__ == "__main__":
    unittest.main()
