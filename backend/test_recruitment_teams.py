"""Campaign teams, changing appointments and public countdown boundaries."""
from datetime import datetime, timedelta
from unittest import TestCase
from unittest.mock import patch
import uuid

import test_attachments_lifecycle as fixture
from app.core.time import utc_now
from app.models.pole import PoleMember
from app.models.recruitment import Application, RecruitmentCampaign, ApplicationInterviewTeam
import test_recruitment_jury_personality as helper_fixture


class RecruitmentTeamsTests(TestCase):
    setUp = fixture.AttachmentLifecycleTests.setUp
    tearDown = fixture.AttachmentLifecycleTests.tearDown
    as_user = fixture.AttachmentLifecycleTests.as_user
    make_task = fixture.AttachmentLifecycleTests.make_task
    campaign = fixture.AttachmentLifecycleTests.campaign
    application_payload = fixture.AttachmentLifecycleTests.application_payload
    post, appoint = helper_fixture.RecruitmentJuryPersonalityTests.post, helper_fixture.RecruitmentJuryPersonalityTests.appoint

    def application(self, campaign=None, **extra):
        app = helper_fixture.RecruitmentJuryPersonalityTests.application(self, campaign, **extra)
        self.as_user('sg')
        self.post(f"/applications/{app['id']}/status", {'status':'under_review'})
        return app

    def team(self, campaign, members, name='Jury unique'):
        self.as_user('sg')
        return self.post(f'/campaigns/{campaign.id}/jury/teams', {'name': name, 'member_ids': [m['id'] for m in members]})

    def edit(self, campaign, team, **changes):
        body = dict(name=team['name'], revision=team['revision'], active=team['active'],
                    member_ids=[row['id'] for row in team['members']], **{})
        body.update(changes)
        return self.client.patch(f"/api/recruitment/campaigns/{campaign.id}/jury/teams/{team['id']}", json=body)

    def schedule(self, app, team, minutes=0, code=200):
        when = (utc_now() + timedelta(days=3)).replace(hour=12, minute=0, second=0, microsecond=0) + timedelta(minutes=minutes)
        return self.post(f"/applications/{app['id']}/interview", {
            'interview_at': when.isoformat() + 'Z', 'interview_end_at': (when + timedelta(minutes=25)).isoformat() + 'Z',
            'interview_mode': 'in_person', 'interview_location': 'Salle fictive',
            'jury_team_id': team['id'], 'jury_team_revision': team['revision'],
        }, code)

    def detail(self, app):
        return self.client.get(f"/api/recruitment/applications/{app['id']}").json()

    def test_single_jury_and_independent_parallel_teams_use_real_appointments(self):
        campaign = self.campaign()
        a, b = self.appoint(campaign, 'a'), self.appoint(campaign, 'b')
        whole = self.team(campaign, [a, b])
        first = self.application(campaign)
        self.schedule(first, whole)
        self.assertEqual(len(self.detail(first)['interview_jurors']), 2)
        second = self.application(campaign, email='second@example.org')
        self.schedule(second, whole, code=409)
        self.schedule(second, whole, minutes=25)  # Adjacent appointments are valid.
        left = self.team(campaign, [a], 'Équipe A')
        right = self.team(campaign, [b], 'Équipe B')
        third = self.application(campaign, email='third@example.org')
        fourth = self.application(campaign, email='fourth@example.org')
        self.schedule(third, left, minutes=120)
        self.schedule(fourth, right, minutes=120)
        self.assertEqual(self.detail(fourth)['interview_team']['id'], right['id'])

    def test_shared_juror_in_two_teams_cannot_be_double_booked(self):
        campaign = self.campaign()
        member = self.appoint(campaign)
        one, two = self.team(campaign, [member], 'A'), self.team(campaign, [member], 'B')
        first, second = self.application(campaign), self.application(campaign, email='second@example.org')
        self.schedule(first, one)
        self.schedule(second, two, code=409)
        self.assertIsNone(self.detail(second)['interview_at'])

    def test_team_edit_keeps_snapshot_and_flags_future_interview_until_reconfirmed(self):
        campaign = self.campaign()
        a, b = self.appoint(campaign, 'a'), self.appoint(campaign, 'b')
        team = self.team(campaign, [a], 'Avant')
        app = self.application(campaign)
        self.schedule(app, team)
        changed = self.edit(campaign, team, name='Après', member_ids=[b['id']])
        self.assertEqual(changed.status_code, 200, changed.text)
        new = changed.json()
        detail = self.detail(app)
        self.assertTrue(detail['interview_needs_reassignment'])
        self.assertEqual(detail['interview_team']['name'], 'Avant')
        self.assertEqual(detail['interview_jurors'][0]['member_id'], a['id'])
        roster = self.client.get(f'/api/recruitment/campaigns/{campaign.id}/jury').json()
        self.assertIn(app['id'], [r['application_id'] for r in roster['interviews_needing_reassignment']])
        self.schedule(app, team, code=409)  # A stale planning dialog cannot override the new team.
        self.schedule(app, new)
        detail = self.detail(app)
        self.assertFalse(detail['interview_needs_reassignment'])
        self.assertEqual(detail['interview_jurors'][0]['member_id'], b['id'])

    def test_stale_team_edit_archive_and_reactivation_preserve_history(self):
        campaign = self.campaign()
        team = self.team(campaign, [self.appoint(campaign)])
        app = self.application(campaign)
        self.schedule(app, team)
        archived = self.edit(campaign, team, active=False)
        self.assertEqual(archived.status_code, 200, archived.text)
        self.assertTrue(self.detail(app)['interview_needs_reassignment'])
        self.assertEqual(self.edit(campaign, team, name='Concurrent').status_code, 409)
        self.schedule(app, archived.json(), code=409)
        revived = self.edit(campaign, archived.json(), active=True).json()
        self.schedule(app, revived)
        self.assertEqual(self.db.query(ApplicationInterviewTeam).count(), 1)

    def test_foreign_member_foreign_team_empty_duplicate_and_name_collisions_are_rejected(self):
        campaign, foreign = self.campaign(), self.campaign()
        member, other = self.appoint(campaign), self.appoint(foreign, 'a')
        team = self.team(campaign, [member], 'Équipe A')
        path = f'/campaigns/{campaign.id}/jury/teams'
        for body, code in [({'name':'Vide','member_ids':[]},422),
                           ({'name':'Double','member_ids':[member['id']]*2},422),
                           ({'name':'Externe','member_ids':[other['id']]},409),
                           ({'name':'  équipe   a ','member_ids':[member['id']]},409)]:
            self.post(path, body, code)
        app = self.application(foreign)
        self.schedule(app, team, code=409)

    def test_only_admin_tl_sg_veille_chief_and_deputy_can_create_or_edit_teams(self):
        campaign = self.campaign()
        member = self.appoint(campaign)
        team = self.team(campaign, [member])
        for actor in ('a', 'b', 'lead', 'veille'):
            self.as_user(actor)
            self.post(f'/campaigns/{campaign.id}/jury/teams', {'name':actor,'member_ids':[member['id']]},403)
            self.assertEqual(self.edit(campaign, team).status_code, 403)
        for actor in ('admin', 'tl', 'sg'):
            self.as_user(actor)
            self.post(f'/campaigns/{campaign.id}/jury/teams', {'name':actor,'member_ids':[member['id']]})
        membership = self.db.query(PoleMember).filter_by(user_id=self.users['veille'].id, pole_id=self.watch.id).one()
        for position in ('chef_pole', 'adjoint_chef_pole'):
            membership.position = position
            self.db.commit()
            self.as_user('veille')
            self.post(f'/campaigns/{campaign.id}/jury/teams', {'name':position,'member_ids':[member['id']]})

    def test_revocation_blocks_team_assignment_and_access_without_erasing_membership(self):
        campaign = self.campaign()
        member = self.appoint(campaign)
        team = self.team(campaign, [member])
        app = self.application(campaign)
        self.schedule(app, team)
        self.as_user('sg')
        self.assertEqual(self.client.delete(f"/api/recruitment/campaigns/{campaign.id}/jury/{member['id']}").status_code, 200)
        self.schedule(app, team, code=409)
        roster = self.client.get(f'/api/recruitment/campaigns/{campaign.id}/jury').json()
        self.assertFalse(roster['teams'][0]['available'])
        self.as_user('b')
        self.assertEqual(self.client.get(f'/api/recruitment/campaigns/{campaign.id}/jury/teams').status_code, 403)
        self.assertEqual(self.db.query(ApplicationInterviewTeam).count(), 1)

    def test_custom_jury_can_replace_team_for_one_candidate_without_changing_team(self):
        campaign = self.campaign()
        a, b = self.appoint(campaign, 'a'), self.appoint(campaign, 'b')
        team = self.team(campaign, [a])
        app = self.application(campaign)
        self.schedule(app, team)
        start = (utc_now() + timedelta(days=3)).replace(hour=19, minute=0)
        self.post(f"/applications/{app['id']}/interview", {'interview_at':start.isoformat()+'Z',
            'jury_member_ids':[b['id']], 'interview_mode':'online','interview_link':'https://example.org/meet'})
        detail = self.detail(app)
        self.assertIsNone(detail['interview_team'])
        self.assertEqual(detail['interview_jurors'][0]['member_id'], b['id'])


class RecruitmentTimelineTests(TestCase):
    setUp, tearDown = RecruitmentTeamsTests.setUp, RecruitmentTeamsTests.tearDown
    make_task, campaign, application_payload = RecruitmentTeamsTests.make_task, RecruitmentTeamsTests.campaign, RecruitmentTeamsTests.application_payload

    def test_upcoming_is_public_but_not_open_and_internal_planning_is_private(self):
        campaign = self.campaign()
        campaign.start_date, campaign.end_date = datetime(2026,11,4).date(), datetime(2026,11,8).date()
        campaign.interview_questions = [{'question':'INTERNAL-SECRET'}]
        self.db.commit()
        with patch('app.api.routes.recruitment.utc_now', return_value=datetime(2026,10,31,18,0)):
            response = self.client.get('/api/recruitment/campaigns/timeline')
            self.assertEqual(response.status_code,200,response.text)
            body = response.json()
            self.assertEqual(body['server_time'],'2026-10-31T18:00:00Z')
            self.assertEqual(body['campaigns'][0]['opens_at'],'2026-11-04T00:00:00Z')
            self.assertEqual(body['campaigns'][0]['closes_at'],'2026-11-09T00:00:00Z')
            self.assertNotIn('INTERNAL-SECRET',response.text)
            self.assertEqual(self.client.get('/api/recruitment/campaigns/public').json(),[])
            submitted=self.client.post('/api/recruitment/applications',json=self.application_payload(campaign))
            self.assertEqual(submitted.status_code,400,submitted.text)

    def test_inclusive_last_day_midnight_and_inactive_campaigns(self):
        active, inactive = self.campaign(), self.campaign()
        active.start_date, active.end_date = datetime(2026,11,4).date(), datetime(2026,11,8).date()
        inactive.is_active = False
        self.db.commit()
        for now, count in [(datetime(2026,11,4),1),(datetime(2026,11,8,23,59,59),1),(datetime(2026,11,9),0)]:
            with self.subTest(now=now), patch('app.api.routes.recruitment.utc_now',return_value=now):
                self.assertEqual(len(self.client.get('/api/recruitment/campaigns/timeline').json()['campaigns']),count)
