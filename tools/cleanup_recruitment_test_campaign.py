"""Guarded maintenance for the single expired test reported on 1 November.

Default is inventory. --execute is the user's explicit test-data erasure,
with an isolated rehearsal, fresh verified backup and transaction. This never
changes campaign API permissions, the image, schema, Compose or mail routing.
"""
from __future__ import annotations

import argparse
import fcntl
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import signal
import sys
import uuid

HELPER_HASH = '2ad80ede7b3c51eb4b349f0d35c6b595f28fc2fa58e2c3fed59a25495efb5a15'
IMAGE_ID = 'sha256:415403e80c33ab717337d3e742bfea544dcc3651fc147da107450d76582bcc04'
VERSION = '1.0.21'
SERVICES = ('backend', 'email-worker', 'push-worker', 'veille-worker')
BASE = Path('/opt/enactspace/app/deploy/docker-compose.vps.yml')
ROOT = Path('/opt/enactspace/operations')
TEST_FILES = ('test_recruitment_campaign_lifecycle.py', 'test_recruitment_test_campaign_cleanup.py')


class CleanupError(RuntimeError):
    """Only fixed diagnostic codes, without exception values or credentials."""


def require(value, code):
    if not value:
        raise CleanupError(code)


def load_helper():
    path = Path(__file__).with_name('publish_recruitment_campaign_backend.py')
    require(hashlib.sha256(path.read_bytes()).hexdigest() == HELPER_HASH, 'Backup_helper_integrity_incorrect')
    spec = importlib.util.spec_from_file_location('recruitment_release_helper', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def scope_source():
    return Path(__file__).with_name('recruitment_test_campaign_scope.py').read_text()


def container_program(mode='inventory', fingerprint=None):
    require(mode in {'inventory', 'erase'}, 'Unknown_operation')
    require(mode == 'inventory' or bool(re.fullmatch('[0-9a-f]{64}', fingerprint or '')),
            'Invalid_plan_fingerprint')
    return scope_source() + '\nMODE=' + repr(mode) + '\nEXPECTED=' + repr(fingerprint) + r'''
from sqlalchemy import text
from app.core.config import settings
from app.db.database import engine
report = {"database_modified": False, "emails_sent": False, "schema_changed": False}
stage = "database_configuration"
try:
    require(engine.dialect.name == "postgresql" and settings.APP_ENV == "production",
            "Production_PostgreSQL_required")
    with engine.connect() as connection:
        transaction = connection.begin()
        try:
            if MODE == "inventory":
                connection.execute(text("SET TRANSACTION READ ONLY"))
                require(connection.execute(text("SHOW transaction_read_only")).scalar_one() == "on",
                        "Read_only_transaction_not_verified")
            connection.execute(text("SET LOCAL statement_timeout = '30s'"))
            connection.execute(text("SET LOCAL lock_timeout = '3s'"))
            require(connection.execute(text("SELECT version_num FROM alembic_version")).scalars().all()
                    == ["20261031_0033"], "Unexpected_schema")
            if MODE == "erase":
                # Application services are stopped. Also exclude concurrent SQL
                # writers, and do not wait indefinitely on another operation.
                names = list(ORDER) + ["stored_files"]
                connection.execute(text("LOCK TABLE " + ", ".join(names)
                                        + " IN SHARE ROW EXCLUSIVE MODE NOWAIT"))
            stage = "exact_campaign_inventory"
            data, selected = inventory(connection)
            report["inventory"] = data
            if MODE == "erase":
                require(selected is not None, "Campaign_not_eligible_for_scoped_test_cleanup")
                stage = "transactional_cleanup"
                result = erase(connection, selected, EXPECTED)
                stage = "commit"
                transaction.commit()
                report.update(result, database_modified=True, status="TEST_CAMPAIGN_DATA_REMOVED")
            else:
                transaction.rollback()
                report.update(database_read_only_verified=True, status="TEST_CAMPAIGN_INVENTORY_COMPLETE")
        except BaseException:
            transaction.rollback()
            raise
except Exception as error:
    report.update(status="TEST_CAMPAIGN_OPERATION_BLOCKED", stage=stage, error_type=type(error).__name__)
    if stage == "commit":
        report["database_modified"] = "unknown"
    if isinstance(error, ScopeError):
        report["reason"] = str(error)
print(json.dumps(report, default=str))
'''


def test_source(name):
    directory = Path(__file__).resolve().parent
    candidates = [directory / name, directory.parent / 'backend' / name]
    return next(path for path in candidates if path.is_file()).read_text()


def isolated_tests(host):
    sources = {name.removesuffix('.py'): test_source(name) for name in TEST_FILES}
    sources['recruitment_test_campaign_scope'] = scope_source()
    program = 'sources=' + repr(sources) + r'''
import json, sys, types, unittest
for name, source in sources.items():
    if name != "recruitment_test_campaign_scope":
        continue
    module = types.ModuleType(name)
    module.__file__ = "/app/tools/" + name + ".py"
    sys.modules[name] = module
    exec(compile(source, module.__file__, "exec"), module.__dict__)
suite = unittest.TestSuite()
for name, source in sources.items():
    if not name.startswith("test_"):
        continue
    module = types.ModuleType(name)
    module.__file__ = "/app/backend/" + name + ".py"
    sys.modules[name] = module
    exec(compile(source, module.__file__, "exec"), module.__dict__)
    suite.addTests(unittest.defaultTestLoader.loadTestsFromModule(module))
result = unittest.TextTestRunner(verbosity=0).run(suite)
print(json.dumps({"passed": result.wasSuccessful() and result.testsRun == 15 and not result.skipped,
                  "tests_run": result.testsRun, "skipped": len(result.skipped),
                  "failures": len(result.failures), "errors": len(result.errors),
                  "production_database_access": False, "network_access": False}))
'''
    raw = host.run([
        'docker', 'run', '--rm', '-i', '--network=none', '--workdir', '/app/backend',
        '-e', 'APP_ENV=test', '-e', 'DATABASE_URL=sqlite://',
        '-e', 'SECRET_KEY=isolated-recruitment-cleanup-tests',
        '-e', 'EMAIL_ENABLED=false', '-e', 'PUSH_ENABLED=false',
        '-e', 'MOBILE_MONEY_ENABLED=false', '-e', 'PYTHONDONTWRITEBYTECODE=1',
        '--entrypoint', 'python', IMAGE_ID, '-'], input=program, timeout=180)
    result = json.loads(raw)
    require(result.get('passed') is True and result.get('tests_run') == 15
            and result.get('skipped') == 0, 'Isolated_lifecycle_or_cleanup_tests_failed')
    return result


def read_inventory(host):
    result = json.loads(host.candidate(container_program()))
    require(result.get('status') == 'TEST_CAMPAIGN_INVENTORY_COMPLETE'
            and result.get('database_read_only_verified') is True, 'Exact_inventory_failed')
    return result['inventory']


def perform_cleanup(host, original, execute):
    report = dict(database_modified=False, schema_changed=False, configuration_modified=False,
                  image_changed=False, mail_routing_changed=False, emails_sent=False,
                  campaign_created=False, services_temporarily_paused=False)
    stage, paused = 'preflight', False
    try:
        host.healthy(VERSION, IMAGE_ID)
        host.configuration()
        require(BASE.read_text() == original, 'Compose_changed_during_preparation')
        report['isolated_tests'] = isolated_tests(host)
        data = read_inventory(host)
        report['inventory'] = data
        if not execute:
            report['status'] = 'TEST_CAMPAIGN_INVENTORY_COMPLETE'
            return report
        eligible = [item for item in data['campaigns'] if item['eligible_for_authorized_test_cleanup']]
        require(data['campaign_count'] == 1 and len(eligible) == 1,
                'Campaign_not_eligible_for_scoped_test_cleanup')
        target = eligible[0]
        report['campaign_id'] = target['id']
        stage = 'pause_application_services'
        paused = True  # Also resume after a partially successful stop.
        host.compose('stop', *SERVICES)
        report['services_temporarily_paused'] = True
        print('SAUVEGARDE_AVANT_NETTOYAGE_DU_TEST', flush=True)
        stage = 'fresh_verified_backup'
        report['backup_id'] = host.verified_backup()
        require(BASE.read_text() == original, 'Compose_changed_during_backup')
        stage = 'revalidate_plan'
        fresh = read_inventory(host)
        require(len(fresh['campaigns']) == 1 and fresh['campaigns'][0] == target,
                'Campaign_changed_during_preparation')
        stage = 'transactional_cleanup'
        report['database_modified'] = 'unknown'
        result = json.loads(host.candidate(container_program('erase', target['fingerprint'])))
        report['database_modified'] = result.get('database_modified', 'unknown')
        require(result.get('status') == 'TEST_CAMPAIGN_DATA_REMOVED'
                and result.get('unrelated_rows_preserved') is True
                and result.get('user_accounts_preserved') is True, 'Transactional_cleanup_not_confirmed')
        report['cleanup'] = {key: value for key, value in result.items() if key != 'inventory'}
        stage = 'post_cleanup_inventory'
        after = read_inventory(host)
        require(after['campaign_count'] == 0 and after['total_applications'] == 0,
                'Test_campaign_or_application_remains')
        report['post_cleanup_inventory'] = after
        report['status'] = 'TEST_CAMPAIGN_CLEANUP_PASSED'
    except Exception as error:
        report.update(status='TEST_CAMPAIGN_CLEANUP_BLOCKED', stage=stage, error_type=type(error).__name__)
        if isinstance(error, CleanupError):
            report['reason'] = str(error)
    finally:
        if paused:
            try:
                require(host.probes_stopped and BASE.read_text() == original,
                        'Probe_cleanup_and_configuration_must_be_verified_before_restart')
                host.compose('start', *SERVICES)
                host.healthy(VERSION, IMAGE_ID)
                host.configuration()
                report['production_services_restored'] = True
            except Exception as error:
                report.update(status='TEST_CAMPAIGN_CLEANUP_BLOCKED', stage='resume_services',
                              production_services_restored=False, error_type=type(error).__name__)
    return report


def save_receipt(directory, report):
    target = directory / 'cleanup.json'
    temporary = directory / ('cleanup.' + uuid.uuid4().hex + '.tmp')
    temporary.write_text(json.dumps(report, indent=2))
    temporary.chmod(0o600)
    temporary.replace(target)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--operation', type=Path, required=True)
    args = parser.parse_args()
    def interrupt(signum, frame):
        raise CleanupError('Operation_interrupted')
    signal.signal(signal.SIGTERM, interrupt)
    signal.signal(signal.SIGINT, interrupt)
    directory = args.operation
    require(bool(re.fullmatch(r'/opt/enactspace/operations/cleanup-recruitment-test-[0-9a-f]{32}', str(directory)))
            and directory.is_dir() and not directory.is_symlink()
            and directory.resolve() == directory and os.geteuid() == 0, 'Invalid_operation_directory')
    helper = load_helper()
    host = helper.Host(directory)
    host.owner = directory.name.removeprefix('cleanup-recruitment-test-')
    host.override.write_text(json.dumps({'services': {'backend': {
        'image': IMAGE_ID, 'environment': {'APP_VERSION': VERSION}}}}))
    host.override.chmod(0o600)
    with (ROOT / 'backend-publication.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        report = perform_cleanup(host, BASE.read_text(), args.execute)
        save_receipt(directory, report)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] in {'TEST_CAMPAIGN_CLEANUP_PASSED', 'TEST_CAMPAIGN_INVENTORY_COMPLETE'} else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        report = dict(status='TEST_CAMPAIGN_PREPARATION_BLOCKED', error_type=type(error).__name__,
                      database_modified='unknown', credentials_printed=False)
        try:
            directory = Path(sys.argv[sys.argv.index('--operation') + 1])
            if re.fullmatch(r'/opt/enactspace/operations/cleanup-recruitment-test-[0-9a-f]{32}', str(directory)) \
                    and directory.is_dir() and not directory.is_symlink() and directory.resolve() == directory:
                save_receipt(directory, report)
        except Exception:
            pass
        print(json.dumps(report))
        sys.exit(1)
