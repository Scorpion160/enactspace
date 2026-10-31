"""Read-only VPS inventory for the November campaign. Never activates a campaign."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import subprocess
import sys


EXPECTED_HARDENING = {'app/api/deps.py': 'b45bf8d1ae3ab62b6c8164552238475a555045eb3ba7092cb5c52fbfbd70580a', 'app/api/routes/files.py': '91a33350d35b6fa3ded199c61b50c3af1c153100c1eb7ce8c080e0f91ccf9b3b', 'app/api/routes/recruitment.py': '7196c06df36f2639f0c05f1f9d20ffd1b1191328c68450503acc63498f4d6f8f', 'app/api/routes/recruitment_extensions.py': '002eb246623cefdb6772f0df9fc714cf03688ddcbae028c2ea4773a57eb97934', 'app/models/recruitment.py': 'cd9be7c29b09d76bb8f2d71e49e2d28967375b7d90f29162fcc44b955a9a4e7c', 'app/schemas/recruitment.py': '0768b20f9517b4d861c6474454710894eeaef2c391853556fe1f292040e09bdc', 'app/services/email_delivery_service.py': 'ba6bcd3b4a8fc14ef5c8e188b1bf4a77a8d51d0e92bb1c70e7833b48a5a5d186', 'app/services/public_request_protection.py': '4284e6c63da06b0abed4132c7ae3b205895251e7e1d91fca316f19dbb9fd929a', 'app/services/recruitment_access.py': 'df000ab8b7f7486b74bd60fe025af5bc3a27ec9e293739af56f09cbae512794b', 'app/services/recruitment_emails.py': 'cb8d5bc64b06a7a11c2d942e1a2b1254557e861418162278e90be72463384bbc', 'app/services/recruitment_interviews.py': '5d233fb6dc7a33cfbc596cfcd9cb5081a4f1b2a071b94c06af0491db09e608cd', 'app/services/recruitment_personality.py': '40632b9a4d80061941eac4c5d772f9551c03153bb65a5f28d02ea65265310f78', 'app/services/request_rate_limit.py': 'a3c0d1f7514f84a8a212c61e94897d7c79c8aefab560725d3f284842994d1a1e'}

CONTAINER_PROBE = r'''
import hashlib, json, os
from datetime import datetime, timezone
from pathlib import Path
from sqlalchemy import text
from app.core.config import settings
from app.db.database import engine

now = datetime.now(timezone.utc)
report = {"database_modified": False, "emails_sent": False,
          "now_utc": now.isoformat(), "database_read_only_verified": False}
stage = "configuration"
try:
    report["configuration"] = {
        "production": settings.APP_ENV == "production",
        "debug_disabled": not settings.APP_DEBUG,
        "auto_create_disabled": not settings.database_auto_create_tables,
        "seed_disabled": not settings.seed_routes_enabled,
        "web_origin_allowed": "https://enactspace.kerunjombor.net" in settings.cors_origins_list,
        "email_enabled": settings.email_enabled,
        "email_redirection_disabled": not settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT,
        "institutional_sender": (settings.SMTP_USERNAME or "").strip().lower() == "enactus@esp.sn",
        "smtp_password_present": bool(settings.SMTP_PASSWORD),
        "storage_writable_by_backend": os.access(settings.FILE_STORAGE_PATH, os.W_OK),
    }
    report["source_sha256"] = {name: hashlib.sha256((Path("/app/backend") / name).read_bytes()).hexdigest()
                               for name in ['app/api/deps.py', 'app/api/routes/files.py', 'app/api/routes/recruitment.py', 'app/api/routes/recruitment_extensions.py', 'app/models/recruitment.py', 'app/schemas/recruitment.py', 'app/services/email_delivery_service.py', 'app/services/public_request_protection.py', 'app/services/recruitment_access.py', 'app/services/recruitment_emails.py', 'app/services/recruitment_interviews.py', 'app/services/recruitment_personality.py', 'app/services/request_rate_limit.py']}
    if engine.dialect.name != "postgresql":
        raise RuntimeError("PostgreSQL_required")
    stage = "read_only_queries"
    with engine.connect() as connection:
        transaction = connection.begin()
        try:
            connection.execute(text("SET TRANSACTION READ ONLY"))
            connection.execute(text("SET LOCAL statement_timeout = '10s'"))
            connection.execute(text("SET LOCAL lock_timeout = '2s'"))
            report["database_read_only_verified"] = connection.execute(text("SHOW transaction_read_only")).scalar_one() == "on"
            report["schema"] = connection.execute(text("SELECT version_num FROM alembic_version")).scalars().all()
            campaigns = connection.execute(text("""
                SELECT c.id, c.title, c.start_date, c.end_date, c.is_active,
                       c.target_headcount, c.application_questions,
                       (SELECT count(*) FROM applications a WHERE a.campaign_id=c.id) AS applications
                FROM recruitment_campaigns c
                WHERE c.end_date >= DATE '2026-10-30' OR c.end_date IS NULL
                ORDER BY c.created_at DESC LIMIT 30
            """)).mappings().all()
            from app.services.recruitment_questionnaire import effective_questions, questionnaire_version
            report["campaigns"] = []
            for row in campaigns:
                questions = effective_questions(row["application_questions"])
                report["campaigns"].append({
                    "id": str(row["id"]), "title": row["title"],
                    "start_date": str(row["start_date"]) if row["start_date"] else None,
                    "end_date": str(row["end_date"]) if row["end_date"] else None,
                    "active": row["is_active"], "target_headcount": row["target_headcount"],
                    "applications": row["applications"], "questions": len(questions),
                    "required_questions": sum(bool(q.get("required")) for q in questions),
                    "questionnaire_version": questionnaire_version(row["application_questions"]),
                    "matches_november_dates": str(row["start_date"]) == "2026-11-04" and str(row["end_date"]) == "2026-11-08",
                })
            report["outbox"] = [dict(row) for row in connection.execute(text("""
                SELECT status, count(*) AS count, min(created_at) AS oldest_created_at
                FROM email_deliveries
                WHERE dedupe_key LIKE 'recruitment-submission:%'
                   OR dedupe_key LIKE 'candidate-update:%'
                   OR created_at >= CURRENT_TIMESTAMP - INTERVAL '7 days'
                GROUP BY status
            """)).mappings()]
            report["recruitment_integrity"] = dict(connection.execute(text("""
                SELECT count(*) AS applications,
                    count(*) FILTER (WHERE tracking_code IS NULL OR tracking_code='') AS missing_tracking_codes,
                    count(*) FILTER (WHERE status='interview_scheduled' AND interview_at IS NULL) AS interviews_without_date,
                    count(*) FILTER (WHERE converted_user_id IS NOT NULL AND status <> 'accepted') AS inconsistent_conversions
                FROM applications
            """)).mappings().one())
            from app.core.roles import RECRUITMENT_ACCESS_ROLES, normalize_role_name, is_veille_pole_name
            role_rows = connection.execute(text("""
                SELECT u.id, r.name FROM users u
                JOIN user_roles ur ON ur.user_id=u.id JOIN roles r ON r.id=ur.role_id
                WHERE u.is_active=true AND u.status='active' AND u.email_verified=true
                  AND coalesce(u.credential_setup_required,false)=false
                  AND coalesce(u.onboarding_required,false)=false
            """)).all()
            recruiters = {str(uid) for uid, role in role_rows if normalize_role_name(role) in RECRUITMENT_ACCESS_ROLES}
            converters = {str(uid) for uid, role in role_rows if normalize_role_name(role) in
                          {'administrateur', 'team_leader', 'secretaire_generale'}}
            pole_rows = connection.execute(text("""
                SELECT u.id, p.name FROM users u
                JOIN pole_members pm ON pm.user_id=u.id JOIN poles p ON p.id=pm.pole_id
                WHERE u.is_active=true AND u.status='active' AND u.email_verified=true
                  AND pm.is_active=true AND pm.left_at IS NULL
                  AND coalesce(u.credential_setup_required,false)=false
                  AND coalesce(u.onboarding_required,false)=false
            """)).all()
            recruiters.update(str(uid) for uid, name in pole_rows if is_veille_pole_name(name))
            report['authorized_accounts'] = {'recruiters_ready': len(recruiters), 'converters_ready': len(converters),
                                             'identities_printed': False}
            # A bounded file sample verifies existence only; no CV is opened or returned.
            files = connection.execute(text("""
                SELECT storage_path FROM stored_files
                WHERE storage_scope='recruitment'
                ORDER BY created_at DESC LIMIT 100
            """)).scalars().all()
            from app.services.file_storage_service import UPLOAD_ROOT
            base = UPLOAD_ROOT.resolve()
            missing = 0
            for storage_path in files:
                path = (base / storage_path).resolve()
                if not path.is_relative_to(base) or not path.is_file():
                    missing += 1
            report["document_sample"] = {"sample_size": len(files), "missing": missing, "contents_read": False}
        finally:
            transaction.rollback()
    report["status"] = "READ_ONLY_DATABASE_INVENTORY_COMPLETE"
except Exception as error:
    report.update(status="READ_ONLY_DATABASE_INVENTORY_BLOCKED", stage=stage, error_type=type(error).__name__)
print(json.dumps(report, ensure_ascii=False, default=str))
'''


class AuditCommandError(RuntimeError):
    def __init__(self, args, returncode):
        self.operation = ' '.join(args[:2])
        self.returncode = returncode
        super().__init__('Read_only_command_failed')


def run(args, *, input=None, timeout=45):
    result = subprocess.run(args, input=input, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise AuditCommandError(args, result.returncode)
    return result.stdout


def backup_inventory(root=Path('/var/backups/enactspace')):
    reports = sorted(root.glob('prelaunch-lot26-*/rehearsal.json'), key=lambda p: p.stat().st_mtime, reverse=True)
    if not reports:
        return {'report_found': False, 'verified': False}
    data = json.loads(reports[0].read_text())
    finished = datetime.fromisoformat(data['finished_at'])
    if finished.tzinfo is None:
        return {'report_found': True, 'verified': False, 'timestamp_has_timezone': False}
    age = (datetime.now(timezone.utc) - finished).total_seconds() / 3600
    return {
        'report_found': True, 'backup_id': data.get('backup_id'), 'finished_at': finished.isoformat(),
        'age_hours': round(age, 1), 'fresh_within_26_hours': 0 <= age <= 26,
        'verified': data.get('passed') is True and data.get('owned_test_resources_removed') is True
                    and data.get('decrypted_staging_removed') is True,
        'offsite_copy_verified_by_this_audit': False,
    }


def audit(expected_candidates=500):
    report = {'database_modified': False, 'production_services_changed': False, 'emails_sent': False,
              'campaign_activated': False, 'load_test_performed': False,
              'expected_candidates_assumption': expected_candidates, 'blockers': [], 'unverified': []}
    blockers = report['blockers']
    names = ['enactspace_backend', 'enactspace_email_worker', 'enactspace_push_worker', 'enactspace_veille_worker', 'enactspace_web']
    containers = json.loads(run(['docker', 'inspect', *names]))
    report['containers'] = [{
        'name': item['Name'].lstrip('/'), 'running': item['State']['Running'],
        'health': (item['State'].get('Health') or {}).get('Status', 'not_configured'),
        'restart_count': item['RestartCount'],
        'source_revision': (item['Config'].get('Labels') or {}).get('org.opencontainers.image.revision'),
        'patch_revision': (item['Config'].get('Labels') or {}).get('net.enactspace.patch_revision'),
    } for item in containers]
    if not all(c['running'] and c['health'] in ('healthy', 'not_configured') for c in report['containers']):
        blockers.append('Container_unhealthy_or_stopped')
    backend = next(item for item in containers if item['Name'] == '/enactspace_backend')
    mounts = backend.get('Mounts') or []
    storage = [m for m in mounts if m.get('Destination') == '/app/uploads']
    report['persistent_upload_mount'] = len(storage) == 1 and storage[0].get('Type') in ('bind', 'volume')
    if not report['persistent_upload_mount']:
        blockers.append('Persistent_upload_mount_not_verified')
    else:
        usage = shutil.disk_usage(storage[0]['Source'])
        reserve = max(2 * 1024**3, expected_candidates * 3 * 10 * 1024**2 * 2)
        report['storage'] = {'free_gib': round(usage.free / 1024**3, 2),
                             'conservative_reserve_gib': round(reserve / 1024**3, 2),
                             'capacity_reserve_met': usage.free >= reserve}
        if usage.free < reserve:
            blockers.append('Storage_below_conservative_reserve')
    report['backup'] = backup_inventory()
    if not report['backup'].get('verified') or not report['backup'].get('fresh_within_26_hours'):
        blockers.append('Recent_verified_backup_missing')
    timer = run(['systemctl', 'show', 'enactspace-verified-backup.timer', '-p', 'ActiveState', '-p', 'NextElapseUSecRealtime'])
    report['backup_timer'] = dict(line.split('=', 1) for line in timer.splitlines() if '=' in line)
    if report['backup_timer'].get('ActiveState') != 'active':
        blockers.append('Backup_timer_inactive')
    database = json.loads(run(['docker', 'exec', '-i', '-e', 'PYTHONDONTWRITEBYTECODE=1', 'enactspace_backend', 'python', '-'], input=CONTAINER_PROBE, timeout=90))
    report['database'] = database
    if database.get('status') != 'READ_ONLY_DATABASE_INVENTORY_COMPLETE':
        blockers.append('Database_inventory_incomplete')
    else:
        report['hardening_sources_match'] = database.get('source_sha256') == EXPECTED_HARDENING
        if not report['hardening_sources_match']:
            blockers.append('Recruitment_hardening_not_deployed_or_source_differs')
        if not database['database_read_only_verified']:
            blockers.append('Read_only_transaction_not_verified')
        if not all(database['configuration'].values()):
            blockers.append('Configuration_check_failed')
        if database.get('schema') != ['20261031_0032']:
            blockers.append('Unexpected_database_schema')
        matching = [c for c in database['campaigns'] if c['matches_november_dates'] and c['active']]
        if len(matching) != 1:
            blockers.append('Exactly_one_active_November_4_to_8_campaign_required')
        else:
            if matching[0]['questions'] < 1 or matching[0]['required_questions'] < 1:
                blockers.append('Campaign_questionnaire_requires_review')
            if not matching[0]['target_headcount']:
                report['unverified'].append('Target_headcount_not_configured')
        if any(c['active'] and not c['matches_november_dates'] for c in database['campaigns']):
            report['unverified'].append('Other_active_campaigns_require_operator_review')
        if database['document_sample']['missing']:
            blockers.append('Missing_recruitment_documents_in_sample')
        if database['recruitment_integrity']['missing_tracking_codes'] or database['recruitment_integrity']['inconsistent_conversions']:
            blockers.append('Recruitment_integrity_anomaly')
        if database['authorized_accounts']['recruiters_ready'] < 1 or database['authorized_accounts']['converters_ready'] < 1:
            blockers.append('Recruitment_or_conversion_authority_missing')
        if database['authorized_accounts']['recruiters_ready'] < 2:
            report['unverified'].append('Second_recruiter_required_for_operational_cover')
        if any(r['status'] == 'dead' and r['count'] for r in database['outbox']):
            blockers.append('Undelivered_emails_require_review')
        if any(r['status'] in ('pending', 'retry', 'processing') and r['count'] for r in database['outbox']):
            report['unverified'].append('Email_queue_age_and_progress_require_review')
    report['unverified'] += [
        'Real_mail_delivery_to_controlled_candidate_address',
        'Production_reverse_proxy_body_limit_and_trusted_client_IP',
        'Peak_load_and_PostgreSQL_concurrency_on_isolated_environment',
        'Offsite_backup_and_latest_restore_rehearsal',
        'Jury_accounts_interview_capacity_and_candidate_support_contact',
        'Final_decision_date_and_optional_personality_test_process',
    ]
    report['status'] = 'RECRUITMENT_AUDIT_REQUIRES_ACTION' if blockers else 'RECRUITMENT_INVENTORY_COMPLETE_REHEARSAL_REQUIRED'
    report['ready_for_launch'] = False  # An inventory cannot certify the entire candidate journey.
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--expected-candidates', type=int, default=500)
    args = parser.parse_args()
    if not 1 <= args.expected_candidates <= 10000:
        parser.error('Expected candidates must be between 1 and 10000')
    try:
        report = audit(args.expected_candidates)
    except Exception as error:
        report = {'status': 'RECRUITMENT_READ_ONLY_AUDIT_BLOCKED', 'error_type': type(error).__name__,
                  'database_modified': False, 'production_services_changed': False, 'emails_sent': False,
                  'ready_for_launch': False}
        if isinstance(error, AuditCommandError):
            report.update(operation=error.operation, exit_code=error.returncode)
    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 1 if report['status'] == 'RECRUITMENT_READ_ONLY_AUDIT_BLOCKED' else 0


if __name__ == '__main__':
    sys.exit(main())
