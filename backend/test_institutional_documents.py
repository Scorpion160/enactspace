import os
import unittest
from datetime import date

os.environ.setdefault("DATABASE_URL", "sqlite:///institutional-documents-import.db")
os.environ.setdefault("SECRET_KEY", "unit-test-institutional-documents-secret")

from fastapi import HTTPException
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.database import Base
import app.models.base  # noqa: F401
from app.api.routes.institutional_documents import _role_user_ids
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.role import Role, UserRole
from app.models.season import Season
from app.models.user import User
from app.services.institutional_document_service import (
    INSTITUTIONAL_SLOGAN,
    INSTITUTIONAL_TEMPLATES,
    allocate_official_reference,
    can_create_request,
    can_start_template,
    can_submit_request,
    get_template_rule,
    is_veille_pole,
    next_status_after_sg_validation,
    next_status_after_submit,
    validate_payload,
    validate_request_scope,
)


class InstitutionalDocumentWorkflowTests(unittest.TestCase):
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
        self.project = Project(name="Projet Test", status="etude")
        self.db.add_all([self.season, self.veille, self.tech, self.project])
        self.db.flush()

        self.veille_lead = self._user("veille.lead@example.com")
        self.veille_member = self._user("veille.member@example.com")
        self.other_lead = self._user("other.lead@example.com")
        self.sg = self._user("sg@example.com")
        self.tl = self._user("tl@example.com")
        self.admin = self._user("admin@example.com")

        self._role(self.sg, "secretaire_generale")
        self._role(self.tl, "team_leader")
        self._role(self.admin, "administrateur")

        self.db.add_all(
            [
                PoleMember(
                    pole_id=self.veille.id,
                    user_id=self.veille_lead.id,
                    position="chef_pole",
                    is_active=True,
                ),
                PoleMember(
                    pole_id=self.veille.id,
                    user_id=self.veille_member.id,
                    position="membre",
                    is_active=True,
                ),
                PoleMember(
                    pole_id=self.tech.id,
                    user_id=self.other_lead.id,
                    position="chef_pole",
                    is_active=True,
                ),
                ProjectMember(
                    project_id=self.project.id,
                    user_id=self.other_lead.id,
                    position="chef_projet",
                    is_active=True,
                ),
            ]
        )
        self.db.commit()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def _user(self, email):
        user = User(
            first_name="Test",
            last_name="User",
            email=email,
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

    def _request(self, template_code, author, *, pole_id=None, project_id=None):
        rule = get_template_rule(template_code)
        item = InstitutionalDocumentRequest(
            template_code=template_code,
            template_version=rule.version,
            status="draft",
            payload_json={},
            requested_by=author.id,
            pole_id=pole_id,
            project_id=project_id,
            season_id=self.season.id,
        )
        self.db.add(item)
        self.db.flush()
        return item

    def test_registry_contains_exactly_the_eight_v1_templates(self):
        self.assertEqual(len(INSTITUTIONAL_TEMPLATES), 8)
        self.assertEqual(
            INSTITUTIONAL_SLOGAN,
            "Empowering our society is our priority",
        )
        self.assertIn("notification_renvoi", INSTITUTIONAL_TEMPLATES)
        self.assertIn("autorisation_parentale_voyage", INSTITUTIONAL_TEMPLATES)

    def test_veille_detection_uses_pole_identity(self):
        self.assertTrue(is_veille_pole(self.veille))
        self.assertFalse(is_veille_pole(self.tech))

    def test_only_veille_lead_can_create_renvoi_notification(self):
        rule = get_template_rule("notification_renvoi")
        self.assertTrue(can_start_template(self.db, self.veille_lead, rule))
        self.assertTrue(
            can_create_request(
                self.db,
                self.veille_lead,
                rule,
                pole_id=self.veille.id,
            )
        )
        self.assertFalse(
            can_create_request(
                self.db,
                self.veille_member,
                rule,
                pole_id=self.veille.id,
            )
        )
        self.assertFalse(
            can_create_request(
                self.db,
                self.other_lead,
                rule,
                pole_id=self.tech.id,
            )
        )
        self.assertFalse(
            can_create_request(self.db, self.sg, rule, pole_id=self.veille.id)
        )
        self.assertFalse(
            can_create_request(self.db, self.tl, rule, pole_id=self.veille.id)
        )
        self.assertFalse(
            can_create_request(self.db, self.admin, rule, pole_id=self.veille.id)
        )

    def test_renvoi_scope_must_be_veille(self):
        rule = get_template_rule("notification_renvoi")
        validate_request_scope(self.db, rule, pole_id=self.veille.id)
        with self.assertRaises(HTTPException):
            validate_request_scope(self.db, rule, pole_id=self.tech.id)

    def test_only_veille_lead_can_submit_renvoi_notification(self):
        item = self._request(
            "notification_renvoi",
            self.veille_lead,
            pole_id=self.veille.id,
        )
        self.assertTrue(can_submit_request(self.db, self.veille_lead, item))
        self.assertFalse(can_submit_request(self.db, self.sg, item))
        self.assertFalse(can_submit_request(self.db, self.tl, item))
        self.assertFalse(can_submit_request(self.db, self.admin, item))

    def test_regular_pole_member_can_draft_but_only_lead_can_submit_pv(self):
        rule = get_template_rule("pv_pole")
        self.assertTrue(
            can_create_request(
                self.db,
                self.veille_member,
                rule,
                pole_id=self.veille.id,
            )
        )
        item = self._request(
            "pv_pole",
            self.veille_member,
            pole_id=self.veille.id,
        )
        self.assertFalse(can_submit_request(self.db, self.veille_member, item))
        self.assertTrue(can_submit_request(self.db, self.veille_lead, item))

    def test_renvoi_follows_sg_then_tl_control(self):
        item = self._request(
            "notification_renvoi",
            self.veille_lead,
            pole_id=self.veille.id,
        )
        self.assertEqual(
            next_status_after_submit(self.db, item),
            "pending_sg_validation",
        )
        item.sg_validated_by = self.sg.id
        self.assertEqual(
            next_status_after_sg_validation(self.db, item),
            "pending_approval",
        )

    def test_sg_authored_external_letter_goes_directly_to_tl_approval(self):
        item = self._request("demande_bus", self.sg)
        self.assertEqual(
            next_status_after_submit(self.db, item),
            "pending_approval",
        )

    def test_tl_authored_external_letter_requires_sg_review_but_not_self_approval(self):
        item = self._request("demande_bus", self.tl)
        self.assertEqual(
            next_status_after_submit(self.db, item),
            "pending_sg_validation",
        )
        self.assertEqual(
            next_status_after_sg_validation(self.db, item),
            "validated",
        )

    def test_required_form_fields_are_checked_at_submission(self):
        rule = get_template_rule("demande_bus")
        with self.assertRaises(HTTPException) as context:
            validate_payload(rule, {"recipient_organization": "ESP"})
        detail = context.exception.detail
        self.assertIn("trip_purpose", detail["missing_fields"])
        self.assertIn("passenger_count", detail["missing_fields"])

    def test_official_references_increment_by_template_and_season(self):
        first = self._request(
            "pv_pole",
            self.veille_member,
            pole_id=self.veille.id,
        )
        second = self._request(
            "pv_pole",
            self.veille_member,
            pole_id=self.veille.id,
        )
        first.status = "validated"
        second.status = "validated"
        self.assertEqual(
            allocate_official_reference(self.db, first),
            "EESP/PV-POLE/2026-2027/001",
        )
        self.assertEqual(
            allocate_official_reference(self.db, second),
            "EESP/PV-POLE/2026-2027/002",
        )

    def test_role_notification_recipients_respect_role_and_exclusions(self):
        sg_ids = _role_user_ids(self.db, "secretaire_generale")
        self.assertEqual(sg_ids, [self.sg.id])
        self.assertEqual(
            _role_user_ids(
                self.db,
                "secretaire_generale",
                exclude={self.sg.id},
            ),
            [],
        )
        self.assertEqual(
            _role_user_ids(self.db, "team_leader"),
            [self.tl.id],
        )


if __name__ == "__main__":
    unittest.main()
