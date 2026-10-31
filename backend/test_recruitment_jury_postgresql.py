"""Jury boundaries plus real PostgreSQL races in disposable, guarded schemas."""
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from threading import Barrier
from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import patch
import os
import uuid

from fastapi import HTTPException, Request
from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import make_url

import test_veille as fixture
import test_operational_integrity_postgresql as pg_fixture
import test_recruitment_teams as teams_fixture
from test_recruitment_jury_personality import RecruitmentJuryPersonalityTests
from app.api.routes import recruitment
from app.api.routes.recruitment_extensions import PersonalitySave, public_attempt, editable, save_answers
from app.core.time import utc_now
from app.models.recruitment import Application, ApplicationInterviewJuror, ApplicationPersonality, RecruitmentCampaign, RecruitmentJuryMember
from app.models.user import User
from app.schemas.recruitment import ApplicationInterviewSchedule
from app.services.recruitment_personality import instrument


def test_url():
    value = os.environ.get('TEST_DATABASE_URL')
    if not value:
        import unittest
        raise unittest.SkipTest('Dedicated local PostgreSQL test DB required')
    url = make_url(value)
    if url.get_backend_name() != 'postgresql' or url.host not in {'localhost', '127.0.0.1', '::1'} or not (url.database or '').startswith('enactspace_pr2b_test'):
        raise RuntimeError('Refusing a non-local or non-test database')
    return value


class RecruitmentJuryHttpPostgreSQLTests(RecruitmentJuryPersonalityTests):
    def setUp(self):
        url = test_url()
        self.admin = create_engine(url)
        self.schema = 'recruitment_jury_' + uuid.uuid4().hex
        with self.admin.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + self.schema))
        engine = create_engine(url)
        @event.listens_for(engine, 'connect')
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO ' + self.schema)
            connection.commit()
        with patch.object(fixture, 'create_engine', return_value=engine), patch.object(fixture, 'event', SimpleNamespace(listens_for=lambda *_: lambda fn: fn)):
            super().setUp()

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            with self.admin.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + self.schema + ' CASCADE'))
            self.admin.dispose()


class RecruitmentTeamsHttpPostgreSQLTests(teams_fixture.RecruitmentTeamsTests):
    def setUp(self):
        url = test_url()
        self.admin = create_engine(url)
        self.schema = 'recruitment_teams_' + uuid.uuid4().hex
        with self.admin.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + self.schema))
        engine = create_engine(url)
        @event.listens_for(engine, 'connect')
        def select_schema(connection, _):
            with connection.cursor() as cursor:
                cursor.execute('SET search_path TO ' + self.schema)
            connection.commit()
        with patch.object(fixture, 'create_engine', return_value=engine), patch.object(fixture, 'event', SimpleNamespace(listens_for=lambda *_: lambda fn: fn)):
            super().setUp()

    def tearDown(self):
        try:
            super().tearDown()
        finally:
            with self.admin.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + self.schema + ' CASCADE'))
            self.admin.dispose()


class RecruitmentJuryRacesPostgreSQLTests(TestCase):
    setUpClass = classmethod(pg_fixture.OperationalIntegrityPostgreSQLTests.setUpClass.__func__)
    tearDownClass = classmethod(pg_fixture.OperationalIntegrityPostgreSQLTests.tearDownClass.__func__)
    _user = pg_fixture.OperationalIntegrityPostgreSQLTests._user

    def _team_race(self, same_team):
        from app.models.recruitment import RecruitmentJuryTeam, RecruitmentJuryTeamMember
        staff_id = self._user(roles=('administrateur',))
        jurors = [self._user(status='alumni'), self._user(status='alumni')]
        pairs = []
        with self.Session() as db:
            campaign = RecruitmentCampaign(title='Synthetic parallel teams')
            db.add(campaign); db.flush()
            first_team = None
            for index in range(2):
                team = first_team if same_team and index else RecruitmentJuryTeam(campaign_id=campaign.id, name=f'Team {index}', name_key=f'team {index}')
                if first_team is None or not same_team:
                    member = RecruitmentJuryMember(campaign_id=campaign.id, user_id=jurors[index])
                    db.add_all([team, member]); db.flush()
                    db.add(RecruitmentJuryTeamMember(team_id=team.id, jury_member_id=member.id))
                first_team = first_team or team
                app = Application(campaign_id=campaign.id, first_name='Synthetic', last_name='Candidate', email=uuid.uuid4().hex+'@example.org', status='under_review')
                db.add(app); db.flush()
                pairs.append((app.id, team.id))
            db.commit()
        barrier = Barrier(2)
        start = (utc_now()+timedelta(days=4)).replace(hour=12, minute=0, second=0, microsecond=0)
        def schedule(pair):
            with self.Session() as db:
                actor = db.get(User, staff_id)
                barrier.wait(5)
                try:
                    recruitment.schedule_application_interview(str(pair[0]), ApplicationInterviewSchedule(
                        interview_at=start, interview_mode='online', interview_link='https://example.org/synthetic',
                        jury_team_id=pair[1], jury_team_revision=1), Request({'type':'http','headers':[]}), db, actor)
                    return 200
                except HTTPException as error:
                    db.rollback()
                    return error.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            return sorted(pool.map(schedule, pairs))

    def test_same_team_parallel_appointments_accept_exactly_one(self):
        self.assertEqual(self._team_race(True), [200,409])

    def test_two_independent_teams_can_interview_in_parallel(self):
        self.assertEqual(self._team_race(False), [200,200])

    def test_parallel_team_edits_cannot_overwrite_the_other_composition(self):
        from app.models.recruitment import RecruitmentJuryTeam, RecruitmentJuryTeamMember
        from app.services.recruitment_teams import JuryTeamSave, save_team
        staff_id, juror_id = self._user(roles=('administrateur',)), self._user(status='alumni')
        with self.Session() as db:
            campaign = RecruitmentCampaign(title='Synthetic team edits')
            db.add(campaign); db.flush()
            member = RecruitmentJuryMember(campaign_id=campaign.id, user_id=juror_id)
            team = RecruitmentJuryTeam(campaign_id=campaign.id, name='Before', name_key='before')
            db.add_all([member,team]); db.flush()
            db.add(RecruitmentJuryTeamMember(team_id=team.id,jury_member_id=member.id))
            campaign_id, team_id, member_id = campaign.id, team.id, member.id
            db.commit()
        barrier = Barrier(2)
        def edit(number):
            with self.Session() as db:
                actor = db.get(User,staff_id)
                barrier.wait(5)
                try:
                    save_team(db,campaign_id,JuryTeamSave(name=f'After {number}',member_ids=[member_id],revision=1),actor,team_id)
                    return 200
                except HTTPException as error:
                    db.rollback()
                    return error.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(edit,[1,2])),[200,409])
        with self.Session() as db:
            self.assertEqual(db.get(RecruitmentJuryTeam,team_id).revision,2)

    def test_upgrade_from_a_0031_schema_preserves_candidate_and_private_cv_reference(self):
        from alembic import command
        from alembic.config import Config
        from app.core.config import settings
        schema = 'recruitment_0031_upgrade_' + uuid.uuid4().hex
        isolated_url = make_url(self.url).update_query_dict({'options': '-csearch_path=' + schema}).render_as_string(hide_password=False)
        engine = create_engine(isolated_url)
        with self.admin_engine.begin() as connection:
            connection.execute(text('CREATE SCHEMA ' + schema))
        try:
            config = Config('alembic.ini')
            with patch.object(settings, 'DATABASE_URL', isolated_url):
                command.upgrade(config, '20261007_0031')
                with engine.begin() as connection:
                    # Remove only the extension objects in this new, owned schema.
                    # 0001 creates them from current metadata, but deployed 0031
                    # predates those models. This reconstructs that upgrade path.
                    for name in ('application_interview_teams', 'recruitment_jury_team_members', 'recruitment_jury_teams', 'application_interview_jurors', 'application_personality', 'recruitment_jury_members'):
                        connection.execute(text('DROP TABLE ' + name))
                    for name in ('campus_resident', 'interview_preferences', 'interview_availability', 'interview_end_at', 'interview_mode'):
                        connection.execute(text('ALTER TABLE applications DROP COLUMN ' + name))
                    campaign_id, application_id = str(uuid.uuid4()), str(uuid.uuid4())
                    connection.execute(text("INSERT INTO recruitment_campaigns (id, title, is_active, created_at, updated_at) VALUES (:id, 'Synthetic legacy campaign', true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"), {'id': campaign_id})
                    connection.execute(text("INSERT INTO applications (id, campaign_id, first_name, last_name, email, status, tracking_code, cv_url, created_at, updated_at) VALUES (:id, :campaign, 'Synthetic', 'Candidate', 'legacy@example.org', 'under_review', 'SYNTHETIC-TRACKING-CODE', 'private-cv-reference', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"), {'id': application_id, 'campaign': campaign_id})
                command.upgrade(config, 'head')
                with engine.connect() as connection:
                    row = connection.execute(text('SELECT id, status, tracking_code, cv_url, campus_resident FROM applications')).one()
                    self.assertEqual(str(row.id), application_id)
                    self.assertEqual((row.status, row.tracking_code, row.cv_url, row.campus_resident), ('under_review', 'SYNTHETIC-TRACKING-CODE', 'private-cv-reference', None))
                    self.assertEqual(connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one(), '20261031_0033')
        finally:
            engine.dispose()
            with self.admin_engine.begin() as connection:
                connection.execute(text('DROP SCHEMA ' + schema + ' CASCADE'))

    def test_parallel_appointments_in_different_campaigns_cannot_double_book_one_juror(self):
        staff_id = self._user(roles=('administrateur',))
        juror_id = self._user(status='alumni')
        pairs = []
        with self.Session() as db:
            for _ in range(2):
                campaign = RecruitmentCampaign(title='Fictional jury concurrency', is_active=True)
                db.add(campaign); db.flush()
                member = RecruitmentJuryMember(campaign_id=campaign.id, user_id=juror_id)
                app = Application(campaign_id=campaign.id, first_name='Synthetic', last_name='Candidate', email=str(uuid.uuid4()) + '@example.org', status='under_review')
                db.add_all([member, app]); db.flush()
                pairs.append((app.id, member.id))
            db.commit()
        when = (utc_now() + timedelta(days=2)).replace(hour=19, minute=0, second=0, microsecond=0)
        barrier = Barrier(2)
        def schedule(pair):
            with self.Session() as db:
                user = db.get(User, staff_id)
                barrier.wait(5)
                try:
                    recruitment.schedule_application_interview(str(pair[0]), ApplicationInterviewSchedule(
                        interview_at=when, interview_end_at=when + timedelta(minutes=30),
                        interview_mode='online', interview_link='https://example.org/isolated-meet',
                        jury_member_ids=[pair[1]]), Request({'type': 'http', 'headers': []}), db, user)
                    return 200
                except HTTPException as error:
                    db.rollback()
                    return error.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            outcomes = list(pool.map(schedule, pairs))
        self.assertEqual(sorted(outcomes), [200, 409])
        with self.Session() as db:
            self.assertEqual(db.query(ApplicationInterviewJuror).filter(ApplicationInterviewJuror.application_id.in_([p[0] for p in pairs])).count(), 1)

    def test_parallel_draft_saves_do_not_erase_each_other(self):
        with self.Session() as db:
            campaign = RecruitmentCampaign(title='Fictional draft concurrency', is_active=True)
            db.add(campaign); db.flush()
            app = Application(campaign_id=campaign.id, first_name='Synthetic', last_name='Candidate',
                email='draft-' + str(uuid.uuid4()) + '@example.org', tracking_code=uuid.uuid4().hex, status='under_review')
            db.add(app); db.flush()
            snapshot = instrument()
            db.add(ApplicationPersonality(application_id=app.id, instrument_version=snapshot['version'], instrument_snapshot=snapshot))
            credentials = {'application_id': app.tracking_code, 'email': app.email, 'version': snapshot['version'], 'revision': 0, 'consent': True}
            app_id = app.id
            db.commit()
        # Resolve the same UUID-shaped code before racing the two writes, so a
        # reference lookup failure cannot masquerade as a concurrency result.
        with self.Session() as db:
            resolved = recruitment.get_application_by_public_reference(db, credentials['application_id'], credentials['email'])
            self.assertIsNotNone(resolved, 'UUID-shaped tracking code must identify the invited candidate')
            self.assertEqual(resolved.id, app_id)
        barrier = Barrier(2)
        def save(value):
            with self.Session() as db:
                barrier.wait(5)
                payload = PersonalitySave(**credentials, answers={'p01': value})
                try:
                    app, row = public_attempt(db, payload, lock=True)
                    editable(app, row)
                    save_answers(row, payload, complete=False)
                    db.commit()
                    return 200
                except HTTPException as error:
                    db.rollback()
                    return error.status_code
        with ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sorted(pool.map(save, [1, 5])), [200, 409])
        with self.Session() as db:
            row = db.get(ApplicationPersonality, app_id)
            self.assertEqual(row.revision, 1)
            self.assertIn(row.answers['p01'], (1, 5))
