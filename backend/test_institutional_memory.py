"""PR-2D normalized institutional-memory domain regressions."""

import os
import secrets
import unittest
import uuid
from datetime import date

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException
from pydantic import ValidationError
from sqlalchemy import create_engine
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import (
    get_current_active_validated_user,
    require_memory_curator,
)
from app.api.routes import archives
from app.api.routes import institutional_memory as memory
from app.db.database import Base
from app.models.archive import Award, CompetitionRecord
from app.models.audit import AuditLog
from app.models.institutional_memory import (
    CanonicalProject,
    InstitutionalEvent,
    InstitutionalGeneration,
    InstitutionalSource,
    LeadershipTerm,
    ProjectAlias,
    ProjectRelationship,
    ProjectYear,
)
from app.models.role import Role, UserRole
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.institutional_memory import (
    AwardMemoryCreate,
    CanonicalProjectCreate,
    CompetitionRecordMemoryCreate,
    InstitutionalEventCreate,
    InstitutionalGenerationCreate,
    InstitutionalSourceCreate,
    LeadershipTermCreate,
    MemoryValidationRequest,
    ProjectAliasCreate,
    ProjectRelationshipCreate,
    ProjectYearCreate,
)


class InstitutionalMemoryTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            poolclass=StaticPool,
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(self.engine)
        self.db = sessionmaker(bind=self.engine, autoflush=False)()
        self.user = User(
            first_name="Memory",
            last_name="Editor",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(self.user)
        self.db.flush()

    def tearDown(self):
        self.db.rollback()
        self.db.close()
        self.engine.dispose()

    def source(self, **values):
        defaults = {
            "source_type": "institutional_document",
            "title": "Compte rendu historique",
            "source_label": "CR-2017",
        }
        defaults.update(values)
        return memory.create_source(
            InstitutionalSourceCreate(**defaults),
            db=self.db,
            current_user=self.user,
        )

    def project(self, name="Projet historique", slug=None, **values):
        return memory.create_canonical_project(
            CanonicalProjectCreate(
                canonical_name=name,
                slug=slug or f"project-{uuid.uuid4().hex}",
                **values,
            ),
            db=self.db,
            current_user=self.user,
        )

    def member(self, label="Member"):
        user = User(
            first_name=label,
            last_name="Reader",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(user)
        self.db.flush()
        return user

    def curator(self, role_name="secretaire_generale"):
        user = self.member("Curator")
        role = Role(name=role_name)
        self.db.add(role)
        self.db.flush()
        self.db.add(UserRole(user_id=user.id, role_id=role.id))
        self.db.commit()
        return user

    def test_year_domain_has_no_new_season_class_or_field(self):
        import app.models.institutional_memory as domain

        self.assertFalse(hasattr(domain, "ProjectSeason"))
        self.assertFalse(hasattr(domain, "InstitutionalSeason"))
        for model in (
            InstitutionalGeneration,
            LeadershipTerm,
            ProjectYear,
            ProjectRelationship,
            InstitutionalEvent,
        ):
            self.assertNotIn("season_id", model.__table__.columns)

    def test_year_only_event_does_not_fabricate_an_exact_date(self):
        event = memory.create_event(
            InstitutionalEventCreate(
                title="Création documentée",
                event_type="creation",
                year=2017,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.assertEqual(event.year, 2017)
        self.assertIsNone(event.event_date)
        self.assertIsNone(event.end_date)
        with self.assertRaises(ValidationError):
            InstitutionalEventCreate(
                title="Date incohérente",
                event_type="creation",
                year=2017,
                event_date=date(2018, 1, 1),
            )

    def test_overview_reports_only_persisted_counts_and_unknown_year_bounds(self):
        overview = memory.memory_overview(db=self.db, current_user=self.user)

        self.assertEqual(overview["known_generations"], 0)
        self.assertEqual(overview["known_projects"], 0)
        self.assertEqual(overview["known_events"], 0)
        self.assertEqual(overview["known_awards"], 0)
        self.assertEqual(overview["known_territories"], 0)
        self.assertIsNone(overview["earliest_year"])
        self.assertIsNone(overview["latest_year"])

    def test_generation_and_term_year_ranges_are_validated(self):
        with self.assertRaises(ValidationError):
            InstitutionalGenerationCreate(
                name="Génération invalide",
                start_year=2020,
                end_year=2019,
            )
        with self.assertRaises(ValidationError):
            LeadershipTermCreate(
                display_name="Personne historique",
                role_label="Responsable",
                start_year=2020,
                end_year=2019,
            )

    def test_historical_term_accepts_name_without_user_and_does_not_mutate_rbac(self):
        role = Role(name="enacteur")
        self.db.add(role)
        self.db.flush()
        assignment = UserRole(user_id=self.user.id, role_id=role.id)
        self.db.add(assignment)
        self.db.commit()
        before = self.db.query(UserRole).count()

        term = memory.create_leadership_term(
            LeadershipTermCreate(
                display_name="Ancienne responsable",
                role_label="Secrétaire générale",
                start_year=2017,
                end_year=2018,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.assertIsNone(term.user_id)
        self.assertEqual(term.display_name, "Ancienne responsable")
        self.assertEqual(self.db.query(UserRole).count(), before)
        self.assertEqual(self.db.get(UserRole, assignment.id).role_id, role.id)

    def test_alias_is_case_insensitively_unique_and_maps_to_one_project(self):
        first = self.project("Projet A")
        second = self.project("Projet B")
        alias = memory.create_project_alias(
            ProjectAliasCreate(canonical_project_id=first.id, alias="EcoTerra"),
            db=self.db,
            current_user=self.user,
        )

        self.assertEqual(alias.canonical_project_id, first.id)
        with self.assertRaises(HTTPException) as failure:
            memory.create_project_alias(
                ProjectAliasCreate(canonical_project_id=second.id, alias="ecoterra"),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 409)
        self.assertEqual(self.db.query(ProjectAlias).count(), 1)

    def test_project_year_is_unique_and_unknown_fields_remain_null(self):
        project = self.project()
        project_year = memory.create_project_year(
            ProjectYearCreate(canonical_project_id=project.id, year=2019),
            db=self.db,
            current_user=self.user,
        )

        self.assertIsNone(project_year.display_name)
        self.assertIsNone(project_year.problem_summary)
        self.assertIsNone(project_year.solution_summary)
        self.assertIsNone(project_year.territory_id)
        with self.assertRaises(HTTPException) as failure:
            memory.create_project_year(
                ProjectYearCreate(canonical_project_id=project.id, year=2019),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 409)

    def test_project_relationship_rejects_self_and_supports_an_evolution_chain(self):
        first = self.project("Projet A")
        second = self.project("Projet B")
        third = self.project("Projet C")
        with self.assertRaises(ValidationError):
            ProjectRelationshipCreate(
                source_project_id=first.id,
                target_project_id=first.id,
                relationship_type="continued_as",
            )

        first_link = memory.create_project_relationship(
            ProjectRelationshipCreate(
                source_project_id=first.id,
                target_project_id=second.id,
                relationship_type="continued_as",
                year=2020,
            ),
            db=self.db,
            current_user=self.user,
        )
        second_link = memory.create_project_relationship(
            ProjectRelationshipCreate(
                source_project_id=second.id,
                target_project_id=third.id,
                relationship_type="merged_into",
                year=2022,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.assertEqual(first_link.target_project_id, second_link.source_project_id)
        self.assertEqual(self.db.query(ProjectRelationship).count(), 2)

    def test_source_attachment_remains_reported_until_explicit_validation(self):
        source = self.source()
        event = memory.create_event(
            InstitutionalEventCreate(
                title="Étape historique",
                event_type="organizational_milestone",
                year=2018,
                source_id=source.id,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.assertEqual(source.validation_status, "HISTORICAL_REPORTED")
        self.assertEqual(event.validation_status, "HISTORICAL_REPORTED")
        validated = memory.validate_memory_entity(
            "events", str(event.id), db=self.db, current_user=self.user
        )
        self.assertEqual(validated.validation_status, "VERIFIED")
        self.assertEqual(validated.validated_by_id, self.user.id)
        self.assertIsNotNone(validated.validated_at)

    def test_validation_requires_structured_provenance(self):
        event = memory.create_event(
            InstitutionalEventCreate(
                title="Fait sans source",
                event_type="project_milestone",
                year=2021,
            ),
            db=self.db,
            current_user=self.user,
        )

        with self.assertRaises(HTTPException) as failure:
            memory.validate_memory_entity(
                "events", str(event.id), db=self.db, current_user=self.user
            )
        self.assertEqual(failure.exception.status_code, 400)
        self.assertEqual(event.validation_status, "HISTORICAL_REPORTED")

    def test_foreign_private_file_cannot_be_attached_without_access(self):
        owner = User(
            first_name="File",
            last_name="Owner",
            email=f"{secrets.token_hex(12)}@example.test",
            password_hash="not-used",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(owner)
        self.db.flush()
        stored_file = StoredFile(
            original_filename="private.pdf",
            stored_filename="opaque.pdf",
            file_size=1,
            storage_path="private/opaque.pdf",
            uploaded_by_id=owner.id,
            visibility="private",
        )
        self.db.add(stored_file)
        self.db.commit()

        with self.assertRaises(HTTPException) as failure:
            memory.create_source(
                InstitutionalSourceCreate(
                    source_type="file",
                    title="Source privée étrangère",
                    file_id=stored_file.id,
                ),
                db=self.db,
                current_user=self.user,
            )
        self.assertEqual(failure.exception.status_code, 403)
        self.assertEqual(self.db.query(InstitutionalSource).count(), 0)

    def test_private_source_visibility_attachment_and_curator_access(self):
        private_source = self.source(
            title="Source privée",
            source_label="PRIVATE-REF",
            visibility="private",
        )
        ordinary = self.member()
        curator = self.curator()
        memory.validate_memory_entity(
            "sources", str(private_source.id), db=self.db, current_user=curator
        )

        creator_rows = memory.list_sources(db=self.db, current_user=self.user)
        ordinary_rows = memory.list_sources(db=self.db, current_user=ordinary)
        curator_rows = memory.list_sources(db=self.db, current_user=curator)

        self.assertEqual(creator_rows, [])
        self.assertEqual(ordinary_rows, [])
        self.assertEqual([row.id for row in curator_rows], [private_source.id])
        with self.assertRaises(HTTPException):
            memory.get_memory_entity(
                "sources",
                str(private_source.id),
                db=self.db,
                current_user=self.user,
            )
        with self.assertRaises(HTTPException) as hidden:
            memory.get_memory_entity(
                "sources",
                str(private_source.id),
                db=self.db,
                current_user=ordinary,
            )
        self.assertEqual(hidden.exception.status_code, 404)
        self.assertEqual(
            memory.get_memory_entity(
                "sources",
                str(private_source.id),
                review=True,
                db=self.db,
                current_user=curator,
            ).id,
            private_source.id,
        )

        with self.assertRaises(HTTPException) as forbidden_reference:
            memory.create_event(
                InstitutionalEventCreate(
                    title="Référence interdite",
                    event_type="other",
                    year=2020,
                    source_id=private_source.id,
                ),
                db=self.db,
                current_user=ordinary,
            )
        self.assertEqual(forbidden_reference.exception.status_code, 400)

        curated_event = memory.create_event(
            InstitutionalEventCreate(
                title="Référence autorisée",
                event_type="other",
                year=2020,
                source_id=private_source.id,
            ),
            db=self.db,
            current_user=curator,
        )
        self.assertEqual(curated_event.validation_status, "HISTORICAL_REPORTED")
        memory.validate_memory_entity(
            "events", str(curated_event.id), db=self.db, current_user=curator
        )
        self.assertEqual(curated_event.validation_status, "VERIFIED")

    def test_private_event_visibility_and_overview_have_no_side_channel(self):
        ordinary = self.member()
        curator = self.curator("team_leader")
        internal_event = memory.create_event(
            InstitutionalEventCreate(
                title="Événement interne",
                event_type="other",
                year=2020,
            ),
            db=self.db,
            current_user=self.user,
        )
        private_event = memory.create_event(
            InstitutionalEventCreate(
                title="Événement privé extrême",
                event_type="other",
                year=1000,
                visibility="private",
            ),
            db=self.db,
            current_user=self.user,
        )
        internal_event.validation_status = "VERIFIED"
        private_event.validation_status = "VERIFIED"
        self.db.commit()

        self.assertEqual(
            {row.id for row in memory.list_events(db=self.db, current_user=self.user)},
            {internal_event.id},
        )
        self.assertEqual(
            [row.id for row in memory.list_events(db=self.db, current_user=ordinary)],
            [internal_event.id],
        )
        self.assertEqual(
            {row.id for row in memory.list_events(db=self.db, current_user=curator)},
            {internal_event.id, private_event.id},
        )
        with self.assertRaises(HTTPException) as hidden:
            memory.get_memory_entity(
                "events",
                str(private_event.id),
                db=self.db,
                current_user=ordinary,
            )
        self.assertEqual(hidden.exception.status_code, 404)

        ordinary_overview = memory.memory_overview(
            db=self.db, current_user=ordinary
        )
        creator_overview = memory.memory_overview(
            db=self.db, current_user=self.user
        )
        self.assertEqual(ordinary_overview["known_events"], 1)
        self.assertEqual(ordinary_overview["earliest_year"], 2020)
        self.assertEqual(ordinary_overview["latest_year"], 2020)
        self.assertEqual(creator_overview["known_events"], 1)
        self.assertEqual(creator_overview["earliest_year"], 2020)

    def test_final_validation_states_are_immutable_and_do_not_reaudit(self):
        source = self.source()
        verified = memory.create_event(
            InstitutionalEventCreate(
                title="Fait validé",
                event_type="other",
                year=2020,
                source_id=source.id,
            ),
            db=self.db,
            current_user=self.user,
        )
        rejected = memory.create_event(
            InstitutionalEventCreate(
                title="Fait rejeté",
                event_type="other",
                year=2021,
                source_id=source.id,
            ),
            db=self.db,
            current_user=self.user,
        )
        memory.validate_memory_entity(
            "events", str(verified.id), db=self.db, current_user=self.user
        )
        memory.reject_memory_entity(
            "events",
            str(rejected.id),
            MemoryValidationRequest(reason="Source insuffisante"),
            db=self.db,
            current_user=self.user,
        )
        superseded = InstitutionalEvent(
            title="Fait remplacé",
            event_type="other",
            year=2019,
            source_id=source.id,
            validation_status="SUPERSEDED",
            created_by_id=self.user.id,
        )
        self.db.add(superseded)
        self.db.commit()

        verified_metadata = (
            verified.validated_by_id,
            verified.validated_at,
            verified.updated_at,
        )
        rejected_metadata = (
            rejected.validated_by_id,
            rejected.validated_at,
            rejected.updated_at,
        )
        audit_count = self.db.query(AuditLog).count()

        actions = (
            lambda: memory.validate_memory_entity(
                "events", str(verified.id), db=self.db, current_user=self.user
            ),
            lambda: memory.reject_memory_entity(
                "events",
                str(verified.id),
                MemoryValidationRequest(reason="Action interdite"),
                db=self.db,
                current_user=self.user,
            ),
            lambda: memory.reject_memory_entity(
                "events",
                str(rejected.id),
                MemoryValidationRequest(reason="Action répétée"),
                db=self.db,
                current_user=self.user,
            ),
            lambda: memory.reject_memory_entity(
                "events",
                str(rejected.id),
                MemoryValidationRequest(),
                db=self.db,
                current_user=self.user,
            ),
            lambda: memory.validate_memory_entity(
                "events", str(rejected.id), db=self.db, current_user=self.user
            ),
            lambda: memory.validate_memory_entity(
                "events", str(superseded.id), db=self.db, current_user=self.user
            ),
            lambda: memory.reject_memory_entity(
                "events",
                str(superseded.id),
                MemoryValidationRequest(reason="Action interdite"),
                db=self.db,
                current_user=self.user,
            ),
        )
        for action in actions:
            with self.assertRaises(HTTPException) as failure:
                action()
            self.assertEqual(failure.exception.status_code, 409)

        self.db.refresh(verified)
        self.db.refresh(rejected)
        self.assertEqual(
            (
                verified.validated_by_id,
                verified.validated_at,
                verified.updated_at,
            ),
            verified_metadata,
        )
        self.assertEqual(
            (
                rejected.validated_by_id,
                rejected.validated_at,
                rejected.updated_at,
            ),
            rejected_metadata,
        )
        self.assertEqual(self.db.query(AuditLog).count(), audit_count)

    def test_static_archive_data_stays_compatible_and_not_normalized_verified(self):
        curator = self.curator()
        archive_awards = archives.list_awards(
            search=None,
            year=None,
            featured=None,
            include_static=True,
            db=self.db,
            current_user=curator,
        )["awards"]
        archive_competitions = archives.list_competitions(
            search=None,
            year=None,
            featured=None,
            include_static=True,
            db=self.db,
            current_user=curator,
        )["competitions"]

        self.assertGreater(len(archive_awards), 0)
        self.assertGreater(len(archive_competitions), 0)
        self.assertTrue(all(row["legacy"] and not row["verified"] for row in archive_awards))
        self.assertTrue(
            all(row["legacy"] and not row["verified"] for row in archive_competitions)
        )
        self.assertEqual(
            memory.list_awards(
                year=None,
                project=None,
                validation_status=None,
                db=self.db,
                current_user=self.user,
            ),
            [],
        )
        self.assertEqual(
            memory.list_competitions(
                year=None,
                territory=None,
                validation_status=None,
                db=self.db,
                current_user=self.user,
            ),
            [],
        )

    def test_persisted_competition_and_award_reuse_archive_models(self):
        source = self.source()
        project = self.project()
        competition = memory.create_competition(
            CompetitionRecordMemoryCreate(
                name="Concours national",
                year=2024,
                source_id=source.id,
            ),
            db=self.db,
            current_user=self.user,
        )
        award = memory.create_award(
            AwardMemoryCreate(
                title="Prix innovation",
                year=2024,
                competition_record_id=competition.id,
                canonical_project_id=project.id,
                source_id=source.id,
            ),
            db=self.db,
            current_user=self.user,
        )

        self.assertIsInstance(competition, CompetitionRecord)
        self.assertIsInstance(award, Award)
        self.assertEqual(award.competition_record_id, competition.id)
        self.assertEqual(award.canonical_project_id, project.id)
        self.assertEqual(award.validation_status, "HISTORICAL_REPORTED")

    def test_database_constraints_reject_invalid_direct_writes(self):
        project = self.project()
        self.db.add(ProjectYear(canonical_project_id=project.id, year=2020))
        self.db.commit()
        self.db.add(ProjectYear(canonical_project_id=project.id, year=2020))
        with self.assertRaises(IntegrityError):
            self.db.flush()
        self.db.rollback()

        self.db.add(
            ProjectRelationship(
                source_project_id=project.id,
                target_project_id=project.id,
                relationship_type="continued_as",
            )
        )
        with self.assertRaises(IntegrityError):
            self.db.flush()

    def test_memory_routes_keep_authenticated_read_and_controlled_write_rbac(self):
        for route in memory.router.routes:
            methods = getattr(route, "methods", set())
            dependencies = {dependency.call for dependency in route.dependant.dependencies}
            if route.path.endswith("/validate") or route.path.endswith("/reject"):
                self.assertIn(require_memory_curator, dependencies)
            elif "POST" in methods or "PATCH" in methods:
                self.assertIn(require_memory_curator, dependencies)
            elif "GET" in methods:
                self.assertIn(get_current_active_validated_user, dependencies)


if __name__ == "__main__":
    unittest.main()
