"""Focused PR-6.6 memory/heritage safety and lifecycle regressions."""

import os
import secrets
import unittest
import uuid
from datetime import date, datetime

os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("SECRET_KEY", secrets.token_urlsafe(48))
os.environ.setdefault("APP_ENV", "test")
os.environ.setdefault("AUTO_CREATE_TABLES", "false")

from fastapi import HTTPException, Request
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models.base  # noqa: F401
from app.api.deps import require_memory_curator
from app.api.routes import archives
from app.api.routes import attendance as attendance_routes
from app.api.routes import institutional_memory as memory
from app.api.routes import projects as project_routes
from app.db.database import Base
from app.models.document import Document
from app.models.archive import (
    ArchiveItem,
    ArchivedProject,
    Award,
    CompetitionRecord,
    HallOfFameEntry,
    HistoricalDocument,
    MediaArchive,
)
from app.models.attendance import AttendanceExpectedMember, AttendanceRecord, AttendanceSession
from app.models.institutional_memory import (
    CanonicalProject,
    CompetitionParticipation,
    InstitutionalEvent,
    InstitutionalFramework,
    InstitutionalGeneration,
    InstitutionalSource,
    LeadershipTerm,
    ProjectAlias,
    ProjectRelationship,
    ProjectYear,
    Territory,
)
from app.models.project import Project
from app.models.role import Role, UserRole
from app.models.stored_file import StoredFile
from app.models.user import User
from app.schemas.project import ProjectUpdate
from app.services.institutional_memory_capture import (
    capture_attendance_archive,
    capture_project_completion,
)


class PR66MemoryHeritageTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine(
            "sqlite://",
            poolclass=StaticPool,
            connect_args={"check_same_thread": False},
        )
        Base.metadata.create_all(self.engine)
        self.db = sessionmaker(bind=self.engine, autoflush=False)()
        self.reader = self._user("Reader")
        self.curator = self._user("Curator", "secretaire_generale")
        self.broad_manager = self._user("Finance", "financier")
        self.db.commit()

    def tearDown(self):
        self.db.rollback()
        self.db.close()
        self.engine.dispose()

    def _user(self, label, role_name=None):
        user = User(
            first_name=label,
            last_name="PR66",
            email=f"{secrets.token_hex(8)}@example.test",
            password_hash="unused",
            status="active",
            is_active=True,
            email_verified=True,
        )
        self.db.add(user)
        self.db.flush()
        if role_name:
            role = self.db.query(Role).filter(Role.name == role_name).first()
            if role is None:
                role = Role(name=role_name)
                self.db.add(role)
                self.db.flush()
            self.db.add(UserRole(user_id=user.id, role_id=role.id))
        return user

    def _source(self, *, visibility="internal", validation_status="VERIFIED"):
        source = InstitutionalSource(
            source_type="minutes",
            title=f"Source {secrets.token_hex(4)}",
            source_label="PV institutionnel",
            visibility=visibility,
            validation_status=validation_status,
            created_by_id=self.curator.id,
        )
        self.db.add(source)
        self.db.flush()
        return source

    def _event(self, title, year, *, source=None, status="VERIFIED", visibility="internal"):
        event = InstitutionalEvent(
            title=title,
            event_type="milestone",
            year=year,
            description=f"Resume {title}",
            source_id=source.id if source else None,
            validation_status=status,
            visibility=visibility,
            created_by_id=self.curator.id,
            origin="manual",
        )
        self.db.add(event)
        self.db.flush()
        return event

    def _timeline(self, *, cursor=None, limit=25, review=False, search=None):
        return memory.list_timeline(
            start_year=None,
            end_year=None,
            resource_type=None,
            project_id=None,
            pole_id=None,
            member_id=None,
            event_id=None,
            validation_status=None,
            search=search,
            review=review,
            limit=limit,
            cursor=cursor,
            db=self.db,
            current_user=self.reader,
        )

    def test_curator_rbac_excludes_broad_enacchef_roles(self):
        self.assertIs(require_memory_curator(db=self.db, current_user=self.curator), self.curator)
        with self.assertRaises(HTTPException) as failure:
            require_memory_curator(db=self.db, current_user=self.broad_manager)
        self.assertEqual(failure.exception.status_code, 403)

    def test_default_read_is_verified_and_private_source_propagates(self):
        public_source = self._source()
        private_source = self._source(visibility="private")
        verified = self._event("Visible", 2023, source=public_source)
        self._event("Draft", 2024, source=public_source, status="UNDER_REVIEW")
        self._event("Private provenance", 2025, source=private_source)
        self.db.commit()

        rows = memory.list_events(db=self.db, current_user=self.reader)
        self.assertEqual([row.id for row in rows], [verified.id])
        overview = memory.memory_overview(db=self.db, current_user=self.reader)
        self.assertEqual(overview["known_events"], 1)
        self.assertEqual((overview["earliest_year"], overview["latest_year"]), (2023, 2023))

        review_rows = memory.list_events(
            review=True,
            db=self.db,
            current_user=self.curator,
        )
        self.assertEqual(len(review_rows), 3)
        with self.assertRaises(HTTPException):
            memory.list_events(review=True, db=self.db, current_user=self.reader)

    def test_timeline_source_capabilities_never_externalize_protected_files(self):
        stored_file = StoredFile(
            original_filename="source.pdf",
            stored_filename="source.pdf",
            storage_path="memory/source.pdf",
            mime_type="application/pdf",
            file_size=12,
            storage_scope="archive",
            visibility="private",
            uploaded_by_id=self.reader.id,
            is_temporary=False,
        )
        document = Document(
            title="Document autorisé",
            file_url="/api/files/document-source/preview",
            status="validated",
            visibility="internal",
            uploaded_by=self.curator.id,
        )
        self.db.add_all([stored_file, document])
        self.db.flush()
        file_source = self._source()
        file_source.file_id = stored_file.id
        document_source = self._source()
        document_source.document_id = document.id
        external_source = self._source()
        external_source.external_url = "https://example.test/institutional-source"
        self.db.commit()

        file_payload = memory._timeline_source_payload(
            self.db,
            self.reader,
            str(file_source.id),
            review=False,
        )
        document_payload = memory._timeline_source_payload(
            self.db,
            self.reader,
            str(document_source.id),
            review=False,
        )
        external_payload = memory._timeline_source_payload(
            self.db,
            self.reader,
            str(external_source.id),
            review=False,
        )

        self.assertEqual(file_payload["label"], "PV institutionnel")
        self.assertIsNone(file_payload["capability"])
        self.assertEqual(
            document_payload["capability"],
            {"type": "document", "url": f"/api/documents/{document.id}"},
        )
        self.assertEqual(
            external_payload["capability"],
            {
                "type": "external_url",
                "url": "https://example.test/institutional-source",
            },
        )
        for payload in (document_payload, external_payload):
            capability_url = payload["capability"]["url"].lower()
            self.assertNotIn("?", capability_url)
            self.assertNotIn("token", capability_url)
            self.assertNotIn("bearer", capability_url)

    def test_private_source_propagates_to_every_normalized_fact_family(self):
        private_source = self._source(visibility="private")
        project_a = CanonicalProject(
            canonical_name="Projet A",
            slug=f"projet-a-{secrets.token_hex(3)}",
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        project_b = CanonicalProject(
            canonical_name="Projet B",
            slug=f"projet-b-{secrets.token_hex(3)}",
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        territory = Territory(
            name="Territoire privé",
            place_type="locality",
            country="Sénégal",
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        generation = InstitutionalGeneration(
            name="Génération privée",
            start_year=2020,
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        self.db.add_all([project_a, project_b, territory, generation])
        self.db.flush()
        competition = CompetitionRecord(
            name="Compétition privée",
            year=2024,
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        facts = [
            project_a,
            project_b,
            territory,
            generation,
            LeadershipTerm(
                display_name="Responsable historique",
                role_label="Présidence",
                start_year=2021,
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
            ProjectAlias(
                canonical_project_id=project_a.id,
                alias=f"Alias {secrets.token_hex(3)}",
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
            ProjectYear(
                canonical_project_id=project_a.id,
                year=2022,
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
            ProjectRelationship(
                source_project_id=project_a.id,
                target_project_id=project_b.id,
                relationship_type="continued_as",
                year=2023,
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
            InstitutionalEvent(
                title="Événement privé par provenance",
                event_type="milestone",
                year=2024,
                source_id=private_source.id,
                validation_status="VERIFIED",
                visibility="internal",
            ),
            InstitutionalFramework(
                name="Cadre privé",
                framework_type="method",
                version_label="v1",
                effective_from_year=2024,
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
            competition,
            Award(
                title="Prix privé",
                year=2024,
                source_id=private_source.id,
                validation_status="VERIFIED",
            ),
        ]
        self.db.add_all(facts[4:])
        self.db.flush()
        participation = CompetitionParticipation(
            competition_record_id=competition.id,
            participant_scope="organization",
            source_id=private_source.id,
            validation_status="VERIFIED",
        )
        self.db.add(participation)
        self.db.commit()
        facts.append(participation)

        self.assertEqual(
            memory._visible_memory_query(
                self.db,
                InstitutionalSource,
                self.reader,
            )
            .filter(InstitutionalSource.id == private_source.id)
            .count(),
            0,
        )
        for fact in facts:
            with self.subTest(model=type(fact).__name__):
                self.assertEqual(
                    memory._visible_memory_query(
                        self.db,
                        type(fact),
                        self.reader,
                    )
                    .filter(type(fact).id == fact.id)
                    .count(),
                    0,
                )
                self.assertEqual(
                    memory._visible_memory_query(
                        self.db,
                        type(fact),
                        self.curator,
                    )
                    .filter(type(fact).id == fact.id)
                    .count(),
                    1,
                )

    def test_timeline_keyset_search_and_private_truth(self):
        source = self._source()
        private_source = self._source(visibility="private")
        expected = [self._event(f"Etape {year}", year, source=source) for year in range(2020, 2026)]
        self._event("Invisible", 2030, source=private_source)
        self.db.commit()

        seen = []
        cursor = None
        while True:
            page = self._timeline(cursor=cursor, limit=2)
            seen.extend(item["id"] for item in page["items"])
            cursor = page["next_cursor"]
            if cursor is None:
                break
        self.assertEqual(len(seen), 6)
        self.assertEqual(len(set(seen)), 6)
        self.assertNotIn(str(self.db.query(InstitutionalEvent).filter_by(title="Invisible").one().id), seen)
        self.assertEqual(
            {str(item.id) for item in expected},
            set(seen),
        )
        searched = self._timeline(search="Etape 2024")
        self.assertEqual([item["title"] for item in searched["items"]], ["Etape 2024"])

    def test_timeline_traverses_over_one_thousand_mixed_rows(self):
        rows = []
        for index in range(501):
            year = 2000 + (index % 26)
            rows.append(
                InstitutionalEvent(
                    title=f"Événement {index:04d}",
                    event_type="milestone",
                    event_date=date(year, (index % 12) + 1, (index % 27) + 1)
                    if index % 2
                    else None,
                    year=year,
                    visibility="internal",
                    validation_status="VERIFIED",
                    origin="manual",
                )
            )
        for index in range(500):
            rows.append(
                InstitutionalFramework(
                    name=f"Cadre {index:04d}",
                    framework_type="method",
                    version_label="v1",
                    effective_from_year=2000 + (index % 26),
                    validation_status="VERIFIED",
                )
            )
        self.db.add_all(rows)
        self.db.commit()

        seen = []
        cursor = None
        while True:
            page = self._timeline(cursor=cursor, limit=100)
            seen.extend(
                (item["resource_type"], item["id"])
                for item in page["items"]
            )
            cursor = page["next_cursor"]
            if cursor is None:
                break
        self.assertEqual(len(seen), 1001)
        self.assertEqual(len(set(seen)), 1001)
        self.assertEqual({resource_type for resource_type, _ in seen}, {"institutional_event", "framework"})

    def test_timeline_detail_hides_private_truth_and_marks_removed_origin(self):
        private_source = self._source(visibility="private")
        hidden = self._event("Repère privé", 2024, source=private_source)
        removed_id = uuid.uuid4()
        historical = InstitutionalEvent(
            title="Projet historique supprimé",
            event_type="project_completed",
            year=2025,
            visibility="internal",
            validation_status="VERIFIED",
            origin="operational",
            capture_key=f"project:{removed_id}:termine",
            source_entity_type="project",
            source_entity_id=removed_id,
            source_entity_version="termine",
            captured_at=datetime.utcnow(),
        )
        self.db.add(historical)
        self.db.commit()

        with self.assertRaises(HTTPException):
            memory.get_timeline_detail(
                "institutional_event",
                str(hidden.id),
                db=self.db,
                current_user=self.reader,
            )
        curator_detail = memory.get_timeline_detail(
            "institutional_event",
            str(hidden.id),
            review=True,
            db=self.db,
            current_user=self.curator,
        )
        self.assertEqual(curator_detail["title"], "Repère privé")

        detail = memory.get_timeline_detail(
            "institutional_event",
            str(historical.id),
            db=self.db,
            current_user=self.reader,
        )
        self.assertEqual(detail["title"], "Projet historique supprimé")
        self.assertTrue(
            any(
                related["label"] == "Element source indisponible"
                and not related["available"]
                for related in detail["related_entities"]
            )
        )

    def test_operational_captures_are_idempotent_and_whitelisted(self):
        project = Project(name="Projet Memoire", description="Description publique", status="termine")
        self.db.add(project)
        session = AttendanceSession(
            title="Reunion generale",
            session_type="general_meeting",
            scope_type="club",
            status="archived",
            is_closed=True,
            scheduled_at=datetime(2026, 9, 10, 18, 0),
            notes="NOTE PRIVEE INTERDITE",
        )
        self.db.add(session)
        self.db.flush()
        self.db.add(AttendanceExpectedMember(session_id=session.id, user_id=self.reader.id))
        self.db.add(
            AttendanceRecord(
                session_id=session.id,
                user_id=self.reader.id,
                status="present",
                justification="JUSTIFICATION INTERDITE",
                penalty_amount=999,
            )
        )
        self.db.flush()

        first_project = capture_project_completion(self.db, project, actor_id=self.curator.id)
        second_project = capture_project_completion(self.db, project, actor_id=self.curator.id)
        first_attendance = capture_attendance_archive(self.db, session, actor_id=self.curator.id)
        second_attendance = capture_attendance_archive(self.db, session, actor_id=self.curator.id)
        self.db.commit()

        self.assertEqual(first_project.id, second_project.id)
        self.assertEqual(first_attendance.id, second_attendance.id)
        self.assertEqual(self.db.query(InstitutionalEvent).count(), 2)
        self.assertEqual(first_attendance.visibility, "private")
        self.assertNotIn("JUSTIFICATION", first_attendance.description)
        self.assertNotIn("999", first_attendance.description)
        self.assertNotIn(str(self.reader.id), first_attendance.description)

    def test_operational_routes_capture_only_real_terminal_transitions(self):
        request = Request(
            {
                "type": "http",
                "method": "PATCH",
                "path": "/test",
                "headers": [],
                "client": ("testclient", 1234),
            }
        )
        project = Project(
            name="Projet route",
            description="Description institutionnelle",
            status="deploiement",
        )
        attendance_session = AttendanceSession(
            title="Seance route",
            session_type="general_meeting",
            scope_type="club",
            status="closed",
            is_closed=True,
            scheduled_at=datetime(2026, 9, 10, 18, 0),
            created_by=self.curator.id,
        )
        self.db.add_all([project, attendance_session])
        self.db.commit()

        project_routes.update_project(
            str(project.id),
            ProjectUpdate(status="termine"),
            request,
            db=self.db,
            current_user=self.curator,
        )
        project_routes.update_project(
            str(project.id),
            ProjectUpdate(status="termine"),
            request,
            db=self.db,
            current_user=self.curator,
        )
        attendance_routes.archive_attendance_session(
            str(attendance_session.id),
            request,
            db=self.db,
            current_user=self.curator,
        )
        attendance_routes.archive_attendance_session(
            str(attendance_session.id),
            request,
            db=self.db,
            current_user=self.curator,
        )

        captures = self.db.query(InstitutionalEvent).order_by(InstitutionalEvent.capture_key).all()
        self.assertEqual(len(captures), 2)
        self.assertEqual(
            {capture.capture_key for capture in captures},
            {
                f"attendance_session:{attendance_session.id}:archived",
                f"project:{project.id}:termine",
            },
        )

    def test_legacy_parent_finality_visibility_and_file_capability(self):
        parent = ArchiveItem(
            title="Archive privee",
            category="Autre",
            visibility="privé",
            status="validated",
            is_public=False,
            created_by_id=self.curator.id,
        )
        self.db.add(parent)
        self.db.flush()
        award = Award(
            archive_item_id=parent.id,
            title="Prix final",
            year=2025,
            validation_status="VERIFIED",
            created_by_id=self.curator.id,
        )
        competition = CompetitionRecord(
            archive_item_id=parent.id,
            name="Compétition finale",
            year=2025,
            validation_status="REJECTED",
            created_by_id=self.curator.id,
        )
        historical_project = ArchivedProject(
            archive_item_id=parent.id,
            name="Projet enfant",
        )
        media = MediaArchive(
            archive_item_id=parent.id,
            title="Média enfant",
            media_type="image",
        )
        document = HistoricalDocument(
            archive_item_id=parent.id,
            title="Document enfant",
            document_type="Document officiel",
        )
        hall_entry = HallOfFameEntry(
            archive_item_id=parent.id,
            title="Hall enfant",
            entry_type="Moment fort",
        )
        stored_file = StoredFile(
            original_filename="preuve.pdf",
            stored_filename="preuve.pdf",
            storage_path="archive/preuve.pdf",
            mime_type="application/pdf",
            file_size=12,
            storage_scope="temporary",
            visibility="private",
            uploaded_by_id=self.curator.id,
            is_temporary=True,
        )
        children = [
            historical_project,
            award,
            competition,
            media,
            document,
            hall_entry,
        ]
        self.db.add_all([*children, stored_file])
        self.db.commit()

        listings = [
            archives.list_historical_projects(
                search=None,
                year=None,
                status_filter=None,
                include_static=False,
                db=self.db,
                current_user=self.reader,
            )["projects"],
            archives.list_awards(
                search=None,
                year=None,
                featured=None,
                include_static=False,
                db=self.db,
                current_user=self.reader,
            )["awards"],
            archives.list_competitions(
                search=None,
                year=None,
                featured=None,
                include_static=False,
                db=self.db,
                current_user=self.reader,
            )["competitions"],
            archives.list_archive_media(
                search=None,
                year=None,
                media_type=None,
                project_id=None,
                db=self.db,
                current_user=self.reader,
            )["media"],
            archives.list_historical_documents(
                search=None,
                year=None,
                document_type=None,
                visibility=None,
                db=self.db,
                current_user=self.reader,
            )["documents"],
            archives.list_hall_of_fame(
                year=None,
                entry_type=None,
                featured=None,
                include_static=False,
                db=self.db,
                current_user=self.reader,
            )["items"],
        ]
        self.assertTrue(all(listing == [] for listing in listings))
        for child in children:
            with self.subTest(child=type(child).__name__):
                self.assertFalse(
                    archives._can_view_legacy_child(self.db, self.reader, child)
                )
                with self.assertRaises(HTTPException) as hidden:
                    archives._require_visible_legacy_child(
                        self.db,
                        self.reader,
                        child,
                        "Enfant",
                    )
                self.assertEqual(hidden.exception.status_code, 404)

        for shared in (award, competition):
            with self.assertRaises(HTTPException) as failure:
                archives._ensure_legacy_child_editable(self.db, shared)
            self.assertEqual(failure.exception.status_code, 409)

        archives._mark_file_as_archive(self.db, stored_file.id)
        self.assertEqual(stored_file.visibility, "private")
        payload = archives._file_payload(self.db, self.reader, stored_file)
        self.assertFalse(payload["accessible"])
        self.assertIsNone(payload["preview_url"])

    def test_parentless_legacy_document_visibility_fails_closed(self):
        alumni = self._user("Alumni", "alumni")
        alumni.status = "alumni"
        private_document = HistoricalDocument(
            title="Document privé sans parent",
            document_type="Document officiel",
            visibility="privé",
        )
        internal_document = HistoricalDocument(
            title="Document interne sans parent",
            document_type="Document officiel",
            visibility="interne",
        )
        alumni_document = HistoricalDocument(
            title="Document Alumni sans parent",
            document_type="Document officiel",
            visibility="alumni",
        )
        enacchefs_document = HistoricalDocument(
            title="Document Enacchefs sans parent",
            document_type="Document officiel",
            visibility="enacchefs",
        )
        unknown_document = HistoricalDocument(
            title="Document inconnu sans parent",
            document_type="Document officiel",
            visibility="inconnue",
        )
        parent = ArchiveItem(
            title="Parent interne final",
            category="Document officiel",
            visibility="interne",
            status="validated",
            is_public=False,
            created_by_id=self.curator.id,
        )
        self.db.add(parent)
        self.db.flush()
        parented_document = HistoricalDocument(
            archive_item_id=parent.id,
            title="Document enfant privé",
            document_type="Document officiel",
            visibility="privé",
        )
        restrictive_file = StoredFile(
            original_filename="restreint.pdf",
            stored_filename="restreint.pdf",
            storage_path="archive/restreint.pdf",
            mime_type="application/pdf",
            file_size=12,
            storage_scope="archive",
            visibility="private",
            uploaded_by_id=self.curator.id,
            is_temporary=False,
        )
        self.db.add(restrictive_file)
        self.db.flush()
        internal_document.file_id = restrictive_file.id
        unaffected_children = [
            ArchivedProject(name="Projet sans visibilité propre"),
            Award(title="Prix vérifié", validation_status="VERIFIED"),
            CompetitionRecord(name="Compétition vérifiée", validation_status="VERIFIED"),
            MediaArchive(title="Média sans visibilité propre", media_type="image"),
            HallOfFameEntry(title="Hall sans visibilité propre", entry_type="Moment fort"),
        ]
        self.db.add_all(
            [
                private_document,
                internal_document,
                alumni_document,
                enacchefs_document,
                unknown_document,
                parented_document,
                *unaffected_children,
            ]
        )
        self.db.commit()

        self.assertFalse(
            archives._can_view_legacy_child(self.db, self.reader, private_document)
        )
        self.assertFalse(
            archives._can_view_legacy_child(self.db, alumni, private_document)
        )
        self.assertTrue(
            archives._can_view_legacy_child(self.db, self.curator, private_document)
        )
        self.assertTrue(
            archives._can_view_legacy_child(self.db, self.reader, internal_document)
        )
        self.assertTrue(
            archives._can_view_legacy_child(self.db, alumni, internal_document)
        )
        self.assertFalse(
            archives._can_view_legacy_child(self.db, self.reader, alumni_document)
        )
        self.assertTrue(
            archives._can_view_legacy_child(self.db, alumni, alumni_document)
        )
        self.assertFalse(
            archives._can_view_legacy_child(
                self.db,
                self.broad_manager,
                enacchefs_document,
            )
        )
        self.assertTrue(
            archives._can_view_legacy_child(
                self.db,
                self.curator,
                enacchefs_document,
            )
        )
        self.assertFalse(
            archives._can_view_legacy_child(self.db, self.reader, unknown_document)
        )
        self.assertFalse(
            archives._can_view_parentless_legacy_visibility(self.db, self.reader, None)
        )
        self.assertTrue(
            archives._can_view_legacy_child(self.db, self.reader, parented_document)
        )
        file_payload = archives._historical_document_payload(
            self.db,
            self.reader,
            internal_document,
        )["file"]
        self.assertFalse(file_payload["accessible"])
        self.assertIsNone(file_payload["preview_url"])
        for child in unaffected_children:
            with self.subTest(child=type(child).__name__):
                self.assertTrue(
                    archives._can_view_legacy_child(self.db, self.reader, child)
                )

    def test_static_legacy_is_curator_only_and_tagged(self):
        with self.assertRaises(HTTPException):
            archives.list_awards(
                search=None,
                year=None,
                featured=None,
                include_static=True,
                db=self.db,
                current_user=self.reader,
            )
        result = archives.list_awards(
            search=None,
            year=None,
            featured=None,
            include_static=True,
            db=self.db,
            current_user=self.curator,
        )
        self.assertTrue(result["awards"])
        self.assertTrue(all(item["legacy"] and not item["verified"] for item in result["awards"]))


if __name__ == "__main__":
    unittest.main()
