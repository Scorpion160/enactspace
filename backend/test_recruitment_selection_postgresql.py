"""Selection permissions and concurrent lot publication on isolated PostgreSQL schemas."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from types import SimpleNamespace
from unittest.mock import patch
import uuid

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import Session

import test_veille as fixture
import test_recruitment_selection as selection_fixture
from test_recruitment_jury_postgresql import test_url
from app.core.config import settings
from app.models.email_delivery import EmailDelivery
from app.models.recruitment import ApplicationScreeningAssignment
from app.schemas.recruitment import ApplicationCreate
from app.models.user import User
from app.services.recruitment_selection import AssignmentSettings, SelectionPublication


class RecruitmentSelectionPostgreSQLTests(selection_fixture.RecruitmentSelectionTests):
    def setUp(self):
        url = test_url()
        self.admin = create_engine(url)
        self.schema = 'recruitment_selection_' + uuid.uuid4().hex
        with self.admin.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + self.schema))
        engine = create_engine(url)

        @event.listens_for(engine, 'connect')
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO ' + self.schema)
            connection.commit()

        with patch.object(fixture, 'create_engine', return_value=engine), patch.object(
            fixture, 'event', SimpleNamespace(listens_for=lambda *_: lambda fn: fn)
        ):
            super().setUp()

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            with self.admin.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + self.schema + ' CASCADE'))
            self.admin.dispose()

    def endpoint(self, suffix):
        # Included routers may be represented lazily by FastAPI on the app.
        # Resolve against the declaring router to exercise the actual handler.
        return next(route.endpoint for route in selection_fixture.recruitment_routes.router.routes
                    if getattr(route, 'path', '').endswith(suffix))

    def test_parallel_assignment_requests_preserve_distinct_balanced_allocations(self):
        campaign, applications, _ = self.prepare(count=3)
        assign = self.endpoint('/selection/assign')
        barrier = Barrier(2)
        actor_id = self.users['sg'].id

        def run():
            with Session(self.engine) as db:
                actor = db.get(User, actor_id)
                barrier.wait(10)
                return assign(campaign_id=campaign.id, payload=AssignmentSettings(), db=db, user=actor)

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: run(), range(2)))
        self.assertEqual(sorted(result['created'] for result in results), [0, 6])
        self.assertEqual(self.db.query(ApplicationScreeningAssignment).count(), 6)

    def test_parallel_new_submissions_allocate_distinct_balanced_reviews_immediately(self):
        campaign, _, _ = self.prepare(count=0)
        body = self.application_payload(campaign)
        barrier = Barrier(2)

        def submit(index):
            payload = ApplicationCreate.model_validate(dict(body, email=f"concurrent-arrival-{index}@example.org"))
            with Session(self.engine) as db:
                barrier.wait(10)
                return selection_fixture.recruitment_routes.create_application(payload, db)

        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(submit, range(2)))
        assignments = self.db.query(ApplicationScreeningAssignment).all()
        self.assertEqual(len(assignments), 4)
        for application in results:
            self.assertEqual(len({row.reviewer_id for row in assignments if str(row.application_id) == str(application['id'])}), 2)
        loads = self.assign(campaign)['loads']
        self.assertEqual(sorted(row['assigned_count'] for row in loads), [1, 1, 2])

    def test_parallel_publications_create_one_result_and_one_mail_per_candidate(self):
        campaign, applications, _ = self.prepare(count=2)
        self.complete_screening(campaign, applications)
        for application, decision in zip(applications, ('shortlisted', 'not_shortlisted')):
            self.post(f"/applications/{application['id']}/selection-decision", {
                'stage': 'screening', 'decision': decision,
            })
        self.db.refresh(campaign)
        campaign.is_active = False
        self.db.commit()
        report = self.report(campaign)
        publish = self.endpoint('/selection/publish')
        payload = SelectionPublication(stage='screening', revision=report['revision'])
        barrier = Barrier(2)
        actor_id = self.users['sg'].id

        def run():
            with Session(self.engine) as db:
                actor = db.get(User, actor_id)
                barrier.wait(10)
                return publish(campaign_id=campaign.id, payload=payload, db=db, user=actor)

        with patch.object(settings, 'EMAIL_ENABLED', True), patch.object(settings, 'SMTP_HOST', 'smtp.example.test'):
            with ThreadPoolExecutor(max_workers=2) as executor:
                results = list(executor.map(lambda _: run(), range(2)))
        self.assertEqual(sorted(result['already_published'] for result in results), [False, True])
        self.assertEqual(self.db.query(EmailDelivery).filter(
            EmailDelivery.dedupe_key.like('recruitment-results:%')
        ).count(), 2)
