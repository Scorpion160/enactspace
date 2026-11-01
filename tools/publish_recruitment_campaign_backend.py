"""Publish only the exact recruitment image whose isolated rehearsal passed.

Default: read-only preflight. --execute adds a verified backup, additive migration
and four-service switch. No campaign creation, web build or payment activation.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time
import urllib.request
import uuid

BASE = Path('/opt/enactspace/app/deploy/docker-compose.vps.yml')
OPERATIONS = Path('/opt/enactspace/operations')
OLD_IMAGE = 'enactspace-backend:release-1ccbb0a'
OLD_IMAGE_ID = 'sha256:b19dfa13f6a9d62a67822aa441913e97713cd566892bce94727c1d85b7b3f65b'
IMAGE = 'enactspace-backend:recruitment-hardening-abaf52081f3b'
IMAGE_ID = 'sha256:415403e80c33ab717337d3e742bfea544dcc3651fc147da107450d76582bcc04'
REHEARSAL_ID = 'abaf52081f3b46eca9f763d8c4ae681a'
PATCH = 'be81a48f50c6eb06e9c34b60d84c6e2cdf654209'
MANIFEST_SHA256 = '4862607c0be62f6138543354423ab0b569efc429c0cb6432e5e2b2265edf92b2'
VERSION = '1.0.21'
OLD_VERSION = '1.0.17'
SCHEMA = '20261031_0033'
SERVICES = ('backend', 'email-worker', 'push-worker', 'veille-worker')
NAMES = ('enactspace_backend', 'enactspace_email_worker',
         'enactspace_push_worker', 'enactspace_veille_worker')
BACKUP_UNIT = 'enactspace-verified-backup.service'
BACKUPS = Path('/var/backups/enactspace')
PUSH_TEST_RESTRICTION = 'PUSH_RESTRICT_TO_TEST_USER_EMAIL'
CONFIGURATION_CHECKS = frozenset({
    'production', 'debug_disabled', 'auto_create_disabled', 'seed_disabled',
    'email_enabled', 'push_enabled', 'email_redirection_disabled',
    'push_redirection_disabled', 'institutional_sender', 'smtp_password_present',
    'payments_remain_disabled',
})


class ReleaseError(RuntimeError):
    """Only fixed, non-sensitive diagnostic codes belong in this exception."""


def require(condition, code):
    if not condition:
        raise ReleaseError(code)


def validate_rehearsal(report):
    require(report.get('status') == 'RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED'
            and report.get('operation_id') == REHEARSAL_ID
            and report.get('candidate_image') == IMAGE
            and report.get('candidate_image_id') == IMAGE_ID
            and report.get('base_image_id') == OLD_IMAGE_ID
            and report.get('owned_runtime_resources_removed') is True
            and report.get('cleanup_errors') == []
            and report.get('test_runner_exit_code') == 0, 'Rehearsal_receipt_incorrect')
    test = report.get('rehearsal', {})
    require(test.get('status') == 'RECRUITMENT_POSTGRESQL_AND_VOLUME_REHEARSAL_PASSED'
            and test.get('candidate_schema_head') == SCHEMA
            and test.get('tests_run') == 265
            and all(test.get(key) == 0 for key in ('failures', 'errors', 'skipped')),
            'Rehearsal_tests_not_passed')
    volume = test.get('volume', {})
    measures = volume.get('measurements', [])
    require(volume.get('owned_schema_and_files_removed') is True
            and len(measures) == 2
            and {item.get('dossiers') for item in measures} == {500, 1000}
            and all(item.get('writers') == 8 and
                    item.get('dossiers_and_tracking_and_files_match') is True
                    for item in measures), 'Rehearsal_volume_not_passed')


def production_push_compose(content):
    """Set only the explicit production push flag in each application service."""
    seen = []
    pattern = re.compile(r'^  (?P<name>backend|email-worker|push-worker|veille-worker):[ \t]*\n'
                         r'(?P<body>.*?)(?=^  [^\s#][^\n:]*:[ \t]*\n|^[^\s#]|\Z)', re.M | re.S)
    def update(match):
        name, body = match['name'], match['body']
        require(name not in seen, 'Duplicate_application_service')
        seen.append(name)
        require(len(re.findall(r'^    environment:', body, re.M)) <= 1,
                'Duplicate_service_environment')
        header = re.search(r'^    environment:[ \t]*\n', body, re.M)
        flag = '      ' + PUSH_TEST_RESTRICTION + ': "false"\n'
        if header is None:
            require(not re.search(r'^    environment:', body, re.M), 'Unsupported_service_environment')
            body = '    environment:\n' + flag + body
        else:
            rest = body[header.end():]
            end = re.search(r'^    [^\s#]', rest, re.M)
            boundary = end.start() if end else len(rest)
            env, suffix = rest[:boundary], rest[boundary:]
            require(not re.search(r'^      -', env, re.M), 'Unsupported_service_environment_list')
            entries = re.findall(r'^      ' + PUSH_TEST_RESTRICTION + r'[ \t]*:.*$', env, re.M)
            require(len(entries) <= 1, 'Duplicate_push_restriction_setting')
            if entries:
                env = re.sub(r'^      ' + PUSH_TEST_RESTRICTION + r'[ \t]*:[^\n]*(?:\n|\Z)', flag, env, count=1, flags=re.M)
            else:
                env = flag + env
            body = body[:header.end()] + env + suffix
        return '  ' + name + ':\n' + body
    updated = pattern.sub(update, content)
    require(set(seen) == set(SERVICES) and len(seen) == 4, 'Application_service_scope_incorrect')
    return updated


def validate_compose_plan(before, after, restore_normal_push):
    """Compare fully resolved Compose maps without returning any secret values."""
    expected = json.loads(json.dumps(before))
    for name in SERVICES:
        service = expected['services'][name]
        require(service.get('image') == OLD_IMAGE, 'Unexpected_resolved_service_image')
        service['image'] = IMAGE_ID
        environment = service.setdefault('environment', {})
        if name == 'backend':
            require(environment.get('APP_VERSION') == OLD_VERSION, 'Unexpected_resolved_version')
            environment['APP_VERSION'] = VERSION
        if restore_normal_push:
            environment[PUSH_TEST_RESTRICTION] = 'false'
    require(expected == after, 'Unexpected_resolved_configuration_change')


def configuration_failures(value, allow_test_push=False):
    require(isinstance(value, dict) and set(value) == CONFIGURATION_CHECKS
            and all(type(item) is bool for item in value.values()),
            'Configuration_probe_format_incorrect')
    return sorted(key for key in CONFIGURATION_CHECKS if value[key] is False
                  and not (allow_test_push and key == 'push_redirection_disabled'))


def updated_compose(original, restore_normal_push=False):
    require(original.count('image: ' + OLD_IMAGE) == 4,
            'Unexpected_current_images')
    require(original.count('APP_VERSION: "' + OLD_VERSION + '"') == 1,
            'Unexpected_current_version')
    # The image ID is immutable; do not deploy a mutable candidate tag.
    updated = original.replace('image: ' + OLD_IMAGE, 'image: ' + IMAGE_ID).replace(
        'APP_VERSION: "' + OLD_VERSION + '"', 'APP_VERSION: "' + VERSION + '"')
    return production_push_compose(updated) if restore_normal_push else updated


def validate_backup(receipt, started):
    require(receipt.get('passed') is True
            and receipt.get('owned_test_resources_removed') is True
            and receipt.get('decrypted_staging_removed') is True,
            'Backup_report_not_verified')
    finished = datetime.fromisoformat(receipt.get('finished_at', ''))
    require(finished.tzinfo is not None and finished.timestamp() >= started,
            'Backup_report_not_fresh')
    require(isinstance(receipt.get('backup_id'), str) and
            re.fullmatch(r'[A-Za-z0-9_-]{1,100}', receipt['backup_id']),
            'Backup_identifier_invalid')


CONFIG_PROBE = r'''
import json
from app.core.config import settings
print(json.dumps({
 "production": settings.APP_ENV == "production",
 "debug_disabled": not settings.APP_DEBUG,
 "auto_create_disabled": not settings.database_auto_create_tables,
 "seed_disabled": not settings.ENABLE_SEED,
 "email_enabled": settings.email_enabled,
 "push_enabled": settings.push_enabled,
 "email_redirection_disabled": not settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT,
 "push_redirection_disabled": not settings.PUSH_RESTRICT_TO_TEST_USER_EMAIL,
 "institutional_sender": (settings.SMTP_USERNAME or "").strip().lower() == "enactus@esp.sn",
 "smtp_password_present": bool(settings.SMTP_PASSWORD),
 "payments_remain_disabled": not settings.MOBILE_MONEY_ENABLED
}))
'''

DATABASE_PROBE = CONFIG_PROBE + r'''
from sqlalchemy import text
from app.db.database import engine
assert engine.dialect.name == "postgresql"
with engine.connect() as connection:
 with connection.begin():
  connection.execute(text("SET TRANSACTION READ ONLY"))
  connection.execute(text("SET LOCAL statement_timeout = '15s'"))
  assert connection.execute(text("SHOW transaction_read_only")).scalar_one() == "on"
  schema = connection.execute(text("SELECT version_num FROM alembic_version")).scalars().all()
  counts = {name: connection.execute(text("SELECT COUNT(*) FROM " + name)).scalar_one()
            for name in ["applications", "application_reviews", "users", "stored_files", "recruitment_campaigns"]}
print(json.dumps({"schema": schema, "counts": counts, "database_read_only_verified": True}))
'''

CATALOG_PROBE = r'''
import json
from alembic.config import Config
from alembic.script import ScriptDirectory
from app.main import app
heads = ScriptDirectory.from_config(Config("alembic.ini")).get_heads()
paths = set(app.openapi()["paths"])
expected = {"/api/recruitment/campaigns/timeline", "/api/recruitment/access",
            "/api/recruitment/personality/save", "/api/recruitment/campaigns/{campaign_id}/jury"}
assert heads == ["20261031_0033"] and expected <= paths
print(json.dumps({"catalog_and_routes_verified": True}))
'''

MIGRATION_PROBE = r'''
import json
from alembic import command
from alembic.config import Config
command.upgrade(Config("alembic.ini"), "20261031_0033")
print(json.dumps({"migration_command_completed": True}))
'''


class Host:
    def __init__(self, directory, restore_normal_push=False):
        self.directory = directory
        self.owner = directory.name.removeprefix('publish-recruitment-')
        self.override = directory / 'candidate.json'
        self.calls = 0
        self.probes_stopped = True
        self.restore_normal_push = restore_normal_push
        self.failed_configuration_checks = []

    def validate_plan(self, updated):
        plan = self.directory / 'compose.candidate.yml'
        plan.write_text(updated)
        plan.chmod(0o600)
        before = json.loads(self.compose('config', '--format', 'json'))
        after = json.loads(self.run(['docker', 'compose', '-p', 'enactspace',
            '--project-directory', str(BASE.parent), '-f', str(plan), 'config', '--format', 'json']))
        validate_compose_plan(before, after, self.restore_normal_push)

    def check_settings(self, value, *, allow_test_push=False):
        self.failed_configuration_checks = configuration_failures(value, allow_test_push)
        require(not self.failed_configuration_checks, 'Production_configuration_incorrect')

    def run(self, args, *, input=None, timeout=180):
        try:
            result = subprocess.run(args, input=input, capture_output=True,
                                    text=True, timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            raise ReleaseError('Command_timeout') from None
        require(result.returncode == 0, 'Command_failed')
        return result.stdout

    def compose(self, *args):
        return self.run(['docker', 'compose', '-p', 'enactspace', '-f', str(BASE), *args])

    def healthy(self, version, image_id):
        for _ in range(50):
            try:
                with urllib.request.urlopen('http://127.0.0.1:18002/health', timeout=3) as response:
                    health = json.load(response)
                rows = json.loads(self.run(['docker', 'inspect', *NAMES], timeout=15))
                if (health.get('ok') is True and health.get('version') == version
                        and len(rows) == 4 and all(
                            row['Image'] == image_id and row['State']['Running']
                            and (row['State'].get('Health') or {}).get('Status', 'healthy') == 'healthy'
                            for row in rows)):
                    return
            except Exception:
                pass
            time.sleep(2)
        raise ReleaseError('Service_health_check_failed')

    def source_check(self, manifest):
        image = json.loads(self.run(['docker', 'image', 'inspect', IMAGE_ID]))[0]
        labels = image['Config'].get('Labels') or {}
        require(image['Id'] == IMAGE_ID and labels.get('net.enactspace.patch_revision') == PATCH
                and labels.get('net.enactspace.rehearsal') == REHEARSAL_ID,
                'Tested_image_provenance_incorrect')
        expected = manifest['files']
        require(len(expected) == 32 and manifest.get('patch_revision') == PATCH,
                'Manifest_scope_incorrect')
        probe = ('import hashlib,json,os\nfrom pathlib import Path\nassert os.geteuid()!=0\n'
                 'expected=' + repr(expected) + '\n'
                 'assert all(hashlib.sha256((Path("/app")/name).read_bytes()).hexdigest()==digest '
                 'for name,digest in expected.items())\nprint("SOURCE_HASHES_VERIFIED")\n')
        require(self.run(['docker', 'run', '--rm', '-i', '--network=none', '--read-only',
                          '--entrypoint', 'python', IMAGE_ID, '-'], input=probe).strip()
                == 'SOURCE_HASHES_VERIFIED', 'Tested_image_sources_incorrect')

    def candidate(self, program):
        self.calls += 1
        name = 'enactspace-recruitment-probe-' + self.owner + '-' + str(self.calls)
        try:
            return self.run([
                'docker', 'compose', '-p', 'enactspace', '-f', str(BASE), '-f', str(self.override),
                'run', '--rm', '-T', '--no-deps', '--pull', 'never', '--name', name,
                '--label', 'net.enactspace.release=' + self.owner,
                '-e', 'PGOPTIONS=-c lock_timeout=15000 -c statement_timeout=180000',
                '--entrypoint', 'python', 'backend', '-'], input=program, timeout=300)
        finally:
            # A timed-out compose client can leave its one-off container alive.
            try:
                self.cleanup_probe(name)
            except BaseException:
                self.probes_stopped = False
                raise

    def cleanup_probe(self, name):
        inventory = ['docker', 'ps', '-a', '--no-trunc', '--filter', 'name=^/' + name + '$', '--format', 'json']
        rows = json.loads(self.run(inventory) or 'null')
        if not rows:
            return
        require(rows.get('Names') == name, 'Probe_cleanup_scope_incorrect')
        try:
            item = json.loads(self.run(['docker', 'inspect', name]))[0]
            require((item['Config'].get('Labels') or {}).get('net.enactspace.release') == self.owner,
                    'Probe_cleanup_owner_incorrect')
            self.run(['docker', 'rm', '-f', item['Id']])
        except ReleaseError:
            # --rm may complete between inventory, inspect and removal. Only a
            # successful second inventory proving absence can resolve that race.
            require(not json.loads(self.run(inventory) or 'null'), 'Probe_cleanup_not_verified')

    def database(self):
        lines = self.candidate(DATABASE_PROBE).splitlines()
        require(len(lines) == 2, 'Database_probe_report_incorrect')
        settings, data = map(json.loads, lines)
        self.check_settings(settings)
        require(data.get('database_read_only_verified') is True and
                data.get('schema') in [['20261007_0031'], ['20261031_0032'], [SCHEMA]],
                'Unexpected_database_revision')
        return data

    def verified_backup(self):
        started = time.time()
        marker = int(time.monotonic() * 1_000_000)
        state = self.run(['systemctl', 'show', BACKUP_UNIT, '-p', 'ActiveState', '--value']).strip()
        require(state in {'inactive', 'failed'}, 'Backup_already_running')
        self.run(['systemctl', 'start', '--no-block', BACKUP_UNIT])
        for attempt in range(330):
            raw = self.run(['systemctl', 'show', BACKUP_UNIT, '-p', 'ActiveState', '-p', 'Result',
                            '-p', 'ExecMainStatus', '-p', 'ExecMainStartTimestampMonotonic'])
            state = dict(line.split('=', 1) for line in raw.splitlines() if '=' in line)
            invocation_started = int(state.get('ExecMainStartTimestampMonotonic', '0')) >= marker
            if invocation_started and state.get('ActiveState') not in {'active', 'activating', 'deactivating'}:
                break
            if attempt % 15 == 0:
                print('SAUVEGARDE_VERIFIEE_EN_COURS', flush=True)
            time.sleep(2)
        else:
            raise ReleaseError('Backup_service_timeout')
        require(state.get('Result') == 'success' and state.get('ExecMainStatus') == '0'
                and int(state.get('ExecMainStartTimestampMonotonic', '0')) >= marker,
                'Backup_service_failed_or_stale')
        reports = sorted(BACKUPS.glob('prelaunch-lot26-*/rehearsal.json'),
                         key=lambda path: path.stat().st_mtime, reverse=True)
        require(reports and reports[0].stat().st_mtime >= started, 'Fresh_backup_report_missing')
        receipt = json.loads(reports[0].read_text())
        validate_backup(receipt, started)
        return receipt['backup_id']

    def replace(self, expected, replacement):
        require(not BASE.is_symlink() and BASE.read_text() == expected,
                'Compose_changed_during_release')
        stat = BASE.stat()
        temporary = BASE.with_name(BASE.name + '.' + uuid.uuid4().hex)
        try:
            with temporary.open('x') as output:
                output.write(replacement)
                output.flush()
                os.fsync(output.fileno())
            temporary.chmod(stat.st_mode & 0o777)
            os.chown(temporary, stat.st_uid, stat.st_gid)
            temporary.replace(BASE)
        finally:
            temporary.unlink(missing_ok=True)

    def configuration(self, *, allow_test_push=False):
        for name in NAMES:
            value = json.loads(self.run(['docker', 'exec', '-i', name, 'python', '-'], input=CONFIG_PROBE))
            self.check_settings(value, allow_test_push=allow_test_push)

    def timeline(self):
        with urllib.request.urlopen('http://127.0.0.1:18002/api/recruitment/campaigns/timeline', timeout=15) as response:
            body = json.load(response)
        require(body.get('timezone') == 'Africa/Dakar' and isinstance(body.get('campaigns'), list)
                and isinstance(body.get('server_time'), str), 'Public_timeline_check_failed')


def perform_release(host, original, execute):
    restore_normal_push = getattr(host, 'restore_normal_push', False)
    updated = updated_compose(original, restore_normal_push)
    report = {'deployment_performed': False, 'migration_attempted': False,
              'migration_performed': False, 'web_changed': False, 'campaign_created': False,
              'mail_routing_changed': False, 'payments_enabled': False,
              'production_push_restoration_requested': restore_normal_push}
    paused = switched = False
    stage = 'preflight'
    try:
        host.healthy(OLD_VERSION, OLD_IMAGE_ID)
        host.validate_plan(updated)
        if restore_normal_push:
            # The old process may retain its test restriction until recreation.
            # Every other safety check still has to pass before stopping it.
            host.configuration(allow_test_push=True)
        before = host.database()
        catalog = json.loads(host.candidate(CATALOG_PROBE))
        require(catalog.get('catalog_and_routes_verified') is True, 'Candidate_catalog_incorrect')
        if not execute:
            return {**report, 'status': 'RECRUITMENT_BACKEND_PREFLIGHT_PASSED',
                    'schema': before['schema'], 'target_schema': SCHEMA, 'target_version': VERSION}

        backup = host.directory / 'compose.previous.yml'
        backup.write_text(original)
        backup.chmod(0o600)
        stage = 'pause_services'
        paused = True
        host.compose('stop', *SERVICES)
        print('API_ET_WORKERS_EN_PAUSE', flush=True)
        stable = host.database()
        stage = 'verified_backup'
        report['backup_id'] = host.verified_backup()
        print('SAUVEGARDE_VERIFIEE', flush=True)

        stage = 'additive_migration'
        report['migration_attempted'] = True
        require(json.loads(host.candidate(MIGRATION_PROBE)).get('migration_command_completed') is True,
                'Migration_report_incorrect')
        after = host.database()
        require(after['schema'] == [SCHEMA] and after['counts'] == stable['counts'],
                'Post_migration_integrity_failed')
        report['migration_performed'] = stable['schema'] != [SCHEMA]
        print('MIGRATION_0033_ET_COMPTAGES_OK', flush=True)
        stage = 'configuration_switch'
        host.replace(original, updated)
        switched = True
        stage = 'start_candidate'
        host.compose('config', '--quiet')
        host.compose('up', '-d', '--no-deps', '--no-build', '--pull', 'never', '--force-recreate', *SERVICES)
        stage = 'health_and_configuration'
        host.healthy(VERSION, IMAGE_ID)
        host.configuration()
        host.timeline()
        report.update(status='RECRUITMENT_BACKEND_DEPLOYED', deployment_performed=True,
                      version=VERSION, schema=SCHEMA, image_id=IMAGE_ID, patch_revision=PATCH,
                      all_four_services_verified=True, timeline_verified=True,
                      push_test_restriction_removed=restore_normal_push,
                      rollback_configuration=str(backup), ready_for_campaign=False)
    except BaseException as error:
        report.update(status='RECRUITMENT_BACKEND_DEPLOYMENT_BLOCKED', stage=stage,
                      error_type=type(error).__name__)
        if isinstance(error, ReleaseError):
            report['reason'] = str(error)
        if getattr(host, 'failed_configuration_checks', None):
            report['failed_configuration_checks'] = host.failed_configuration_checks
        if paused:
            try:
                require(host.probes_stopped, 'Candidate_probe_cleanup_not_verified')
                if switched:
                    host.replace(updated, original)
                    host.compose('up', '-d', '--no-deps', '--no-build', '--pull', 'never',
                                 '--force-recreate', *SERVICES)
                else:
                    host.compose('start', *SERVICES)
                host.healthy(OLD_VERSION, OLD_IMAGE_ID)
                report['previous_services_restored'] = True
            except BaseException:
                report['previous_services_restored'] = False
            report['database_schema_preserved_no_downgrade'] = True
    return report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', required=True, type=Path)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--restore-normal-push', action='store_true')
    args = parser.parse_args(argv)
    directory = args.directory.resolve()
    require(directory.parent == OPERATIONS and re.fullmatch(r'publish-recruitment-[a-f0-9]{32}', directory.name)
            and not args.directory.is_symlink(), 'Owned_operation_directory_required')
    os.umask(0o077)
    report = {'status': 'RECRUITMENT_BACKEND_PREPARATION_BLOCKED', 'deployment_performed': False}
    try:
        manifest_path = directory / 'manifest.json'
        require(hashlib.sha256(manifest_path.read_bytes()).hexdigest() == MANIFEST_SHA256,
                'Manifest_integrity_incorrect')
        manifest = json.loads(manifest_path.read_text())
        receipts = []
        for path in Path('/opt/enactspace/staging').glob('recruitment-rehearsal-*/rehearsal.json'):
            if not path.is_symlink():
                item = json.loads(path.read_text())
                if item.get('operation_id') == REHEARSAL_ID:
                    receipts.append(item)
        require(len(receipts) == 1, 'Verified_rehearsal_receipt_missing_or_ambiguous')
        validate_rehearsal(receipts[0])
        require(not (directory / 'deployment.json').exists(), 'Operation_already_finished')
        host = Host(directory, restore_normal_push=args.restore_normal_push)
        host.source_check(manifest)
        candidate_environment = {'APP_VERSION': VERSION}
        if args.restore_normal_push:
            candidate_environment[PUSH_TEST_RESTRICTION] = 'false'
        host.override.write_text(json.dumps({'services': {'backend': {
            'image': IMAGE_ID, 'environment': candidate_environment}}}))
        with (OPERATIONS / 'backend-publication.lock').open('a') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            require(not BASE.is_symlink(), 'Unexpected_compose_symlink')
            report = perform_release(host, BASE.read_text(), args.execute)
    except BaseException as error:
        report.update(error_type=type(error).__name__)
        if isinstance(error, ReleaseError):
            report['reason'] = str(error)
    name = 'deployment.json' if args.execute else 'preflight.json'
    receipt = directory / name
    temporary = directory / (name + '.tmp')
    temporary.write_text(json.dumps(report, indent=2))
    temporary.replace(receipt)
    print(json.dumps(report, indent=2), flush=True)
    return 0 if report['status'] in {'RECRUITMENT_BACKEND_DEPLOYED', 'RECRUITMENT_BACKEND_PREFLIGHT_PASSED'} else 1


def interrupt_release(*_):
    # Do not let a retry loop swallow termination; unwind into recovery.
    raise KeyboardInterrupt


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, interrupt_release)
    sys.exit(main())
