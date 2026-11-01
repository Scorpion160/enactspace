"""One-off maintenance scope, never an ordinary campaign-deletion permission.

Only the sole, expired campaign and the one application reported by the audit
may be selected automatically. Attachments and converted accounts require a
separate reviewed plan; this operation never removes their files or accounts.
"""
from datetime import date
import hashlib
import json

from sqlalchemy import and_, false, func, inspect, or_, select


class ScopeError(RuntimeError):
    """Fixed diagnostic codes only; never exception details or candidate data."""


ORDER = (
    'push_deliveries', 'email_deliveries', 'notifications', 'audit_logs',
    'application_interview_teams', 'application_interview_jurors',
    'application_personality', 'application_reviews',
    'recruitment_jury_team_members', 'recruitment_jury_teams',
    'recruitment_jury_members', 'applications', 'recruitment_campaigns',
)


def require(value, code):
    if not value:
        raise ScopeError(code)


def tables():
    import app.models.base  # noqa: F401 -- metadata only, no startup hooks
    from app.db.database import Base
    return Base.metadata.tables


def count(connection, table, condition=None):
    query = select(func.count()).select_from(table)
    return connection.execute(query.where(condition) if condition is not None else query).scalar_one()


def entity_condition(table, type_column, id_column, groups):
    return or_(false(), *(and_(table.c[type_column].in_(names), table.c[id_column].in_(ids))
                          for names, ids in groups if ids))


def build_scope(connection, campaign_id):
    t = tables()
    campaign = connection.execute(select(t['recruitment_campaigns']).where(
        t['recruitment_campaigns'].c.id == campaign_id)).mappings().one()
    apps = connection.execute(select(t['applications']).where(
        t['applications'].c.campaign_id == campaign_id)).mappings().all()
    app_ids = [row['id'] for row in apps]
    member_ids = connection.execute(select(t['recruitment_jury_members'].c.id).where(
        t['recruitment_jury_members'].c.campaign_id == campaign_id)).scalars().all()
    team_ids = connection.execute(select(t['recruitment_jury_teams'].c.id).where(
        t['recruitment_jury_teams'].c.campaign_id == campaign_id)).scalars().all()
    groups = [
        (('recruitment_campaign', 'campaign'), [campaign_id]),
        (('application',), app_ids),
        (('recruitment_jury_member', 'jury_member'), member_ids),
        (('recruitment_jury_team', 'jury_team'), team_ids),
    ]
    where = {
        'recruitment_campaigns': t['recruitment_campaigns'].c.id == campaign_id,
        'applications': t['applications'].c.campaign_id == campaign_id,
        'recruitment_jury_members': t['recruitment_jury_members'].c.campaign_id == campaign_id,
        'recruitment_jury_teams': t['recruitment_jury_teams'].c.campaign_id == campaign_id,
        'application_reviews': t['application_reviews'].c.application_id.in_(app_ids),
        'application_personality': t['application_personality'].c.application_id.in_(app_ids),
        'notifications': entity_condition(t['notifications'], 'related_type', 'related_id', groups),
        'audit_logs': entity_condition(t['audit_logs'], 'entity_type', 'entity_id', groups),
        'stored_files': entity_condition(t['stored_files'], 'entity_type', 'entity_id', groups),
    }
    # An inconsistent cross-campaign assignment must never be silently removed.
    for name, left, left_ids, right, right_ids in (
        ('application_interview_jurors', 'application_id', app_ids, 'jury_member_id', member_ids),
        ('application_interview_teams', 'application_id', app_ids, 'team_id', team_ids),
        ('recruitment_jury_team_members', 'team_id', team_ids, 'jury_member_id', member_ids),
    ):
        a, b = t[name].c[left].in_(left_ids), t[name].c[right].in_(right_ids)
        where[name] = or_(a, b)
        require(count(connection, t[name], and_(or_(a, b), ~and_(a, b))) == 0,
                'Cross_campaign_assignment_requires_review')
    notification_ids = connection.execute(select(t['notifications'].c.id).where(
        where['notifications'])).scalars().all()
    email = t['email_deliveries']
    dedupe = or_(false(), *(or_(
        email.c.dedupe_key == f'recruitment-submission:{value}',
        email.c.dedupe_key.startswith(f'candidate-update:{value}:', autoescape=True),
        email.c.dedupe_key.startswith(f'personality-invite:{value}:', autoescape=True),
    ) for value in app_ids))
    require(count(connection, email, and_(dedupe, email.c.notification_id.is_not(None),
                ~email.c.notification_id.in_(notification_ids))) == 0,
            'Cross_scope_email_notification_requires_review')
    where['email_deliveries'] = or_(email.c.notification_id.in_(notification_ids), dedupe)
    where['push_deliveries'] = t['push_deliveries'].c.notification_id.in_(notification_ids)
    counts, digests, outside = {}, {}, {}
    for name, condition in where.items():
        condition = func.coalesce(condition, false())
        where[name] = condition
        # Hash complete scoped rows privately so edits between inventory and
        # maintenance invalidate the plan. No answers or identities are returned.
        rows = connection.execute(select(t[name]).where(condition)).mappings().all()
        serialized = sorted(json.dumps(dict(row), sort_keys=True, default=str) for row in rows)
        counts[name] = len(rows)
        digests[name] = hashlib.sha256('\n'.join(serialized).encode()).hexdigest()
        primary = list(t[name].primary_key.columns)
        untouched = connection.execute(select(*primary).where(~condition)).all()
        outside[name] = sorted(tuple(str(value) for value in row) for row in untouched)
    fingerprint = hashlib.sha256(json.dumps(digests, sort_keys=True).encode()).hexdigest()
    attachments = sum(bool(str(row[name] or '').strip()) for row in apps
                      for name in ('cv_url', 'motivation_letter_url', 'attachment_url'))
    return dict(campaign=campaign, where=where, counts=counts, fingerprint=fingerprint,
                outside=outside, converted=sum(row['converted_user_id'] is not None for row in apps),
                attachment_links=attachments, users=count(connection, t['users']))


def guard(scope, campaign_count, total_applications, expected_applications=1, today=None):
    today = today or date.today()
    campaign = scope['campaign']
    require(campaign_count == 1, 'Exactly_one_existing_campaign_required')
    require(scope['counts']['applications'] == expected_applications == total_applications,
            'Application_count_differs_from_reviewed_audit')
    require(campaign['end_date'] is not None and campaign['end_date'] < today
            and campaign['end_date'] < date(2026, 11, 4), 'Only_expired_pre_November_test_allowed')
    require(scope['converted'] == 0, 'Converted_accounts_require_separate_review')
    require(scope['counts']['stored_files'] == 0 and scope['attachment_links'] == 0,
            'Attachments_require_separate_file_cleanup_plan')


def check_incoming_foreign_keys(connection):
    removed = set(ORDER)
    foreign_keys = inspect(connection).get_multi_foreign_keys()
    for (_, child), keys in foreign_keys.items():
        for key in keys:
            require(key['referred_table'] not in removed or child in removed,
                    'Unknown_dependent_table_requires_review')


def inventory(connection, expected_applications=1, today=None):
    t = tables()
    campaigns = connection.execute(select(t['recruitment_campaigns']).order_by(
        t['recruitment_campaigns'].c.created_at)).mappings().all()
    total_applications = count(connection, t['applications'])
    report = dict(campaign_count=len(campaigns), total_applications=total_applications,
                  candidate_identities_printed=False, campaigns=[])
    selected = None
    for row in campaigns:
        scope = build_scope(connection, row['id'])
        blocked = None
        try:
            guard(scope, len(campaigns), total_applications, expected_applications, today)
            check_incoming_foreign_keys(connection)
        except ScopeError as error:
            blocked = str(error)
        item = dict(id=str(row['id']), title=row['title'], start_date=str(row['start_date']) if row['start_date'] else None,
                    end_date=str(row['end_date']) if row['end_date'] else None, active=row['is_active'],
                    counts=scope['counts'], converted_accounts=scope['converted'],
                    attachment_links=scope['attachment_links'], fingerprint=scope['fingerprint'],
                    eligible_for_authorized_test_cleanup=blocked is None, blocker=blocked)
        report['campaigns'].append(item)
        if blocked is None:
            selected = scope
    return report, selected


def erase(connection, scope, expected_fingerprint, expected_applications=1, today=None):
    """Caller owns the transaction; every verification precedes its commit."""
    t = tables()
    campaign_id = scope['campaign']['id']
    fresh = build_scope(connection, campaign_id)
    guard(fresh, count(connection, t['recruitment_campaigns']), count(connection, t['applications']),
          expected_applications, today)
    require(fresh['fingerprint'] == expected_fingerprint, 'Campaign_changed_since_inventory')
    check_incoming_foreign_keys(connection)
    deleted = {}
    for name in ORDER:
        result = connection.execute(t[name].delete().where(fresh['where'][name]))
        require(result.rowcount == fresh['counts'][name], 'Deleted_count_does_not_match_plan')
        deleted[name] = result.rowcount
    # Also verify zero polymorphic residue and the exact untouched primary keys.
    for name, condition in fresh['where'].items():
        require(count(connection, t[name], condition) == 0, 'Scoped_data_remains')
        outside = sorted(tuple(str(value) for value in row) for row in
                         connection.execute(select(*t[name].primary_key.columns)).all())
        require(outside == fresh['outside'][name], 'Unrelated_rows_changed')
    require(count(connection, t['users']) == fresh['users'], 'User_accounts_changed')
    return dict(deleted_counts=deleted, campaign_id=str(campaign_id),
                unrelated_rows_preserved=True, user_accounts_preserved=True,
                physical_files_removed=0, active_campaign_data_removed=True)
