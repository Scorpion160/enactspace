"""Recognize and extend only the known scheduled backup revision allowlist."""
import ast
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import uuid

BACKUP_ROOT = Path('/opt/enactspace/operations/backup-lot26')
WORKING_DIRECTORY = BACKUP_ROOT / 'backend'
SCHEDULE = WORKING_DIRECTORY / 'app/scripts/prelaunch_scheduled_backup.py'
CORE = WORKING_DIRECTORY / 'app/scripts/prelaunch_backup_restore.py'
BACKUPS = Path('/var/backups/enactspace')
UNIT = 'enactspace-verified-backup.service'
SCHEMA = '20261031_0033'
OLD_SHA = '00c7bb7c5b3ad7597c133a3727ce9b58d589fb6e521952e416d6d85c362d2a56'
NEW_SHA = 'bf18b1b978bddad5e3773a33060effd8617a184bdcdb29a51d8b3206113c0a80'
CORE_SHA = '14618327a490641af983e0dcd730955ebd5caf6cf0f498eef75cc6bb9fa6b5ed'
OLD_LINE = 'APPROVED_REVISIONS={"20261006_0025","20261007_0031"}'
NEW_LINE = 'APPROVED_REVISIONS={"20261006_0025","20261007_0031","20261031_0033"}'
SAFE_BACKUP_FAILURES = frozenset({
    'Storage mount mismatch', 'Insufficient private staging storage', 'Unexpected production revision',
    'Source_changed_during_capture_rehearsal_not_accepted', 'encrypted_backup_failed',
    'backup_integrity_failed', 'Restored database differs', 'Restored uploads differ',
    'Restored_reference_consistency_failed', 'Schema_change_detection_failed',
    'Verification_manifest_roundtrip_failed', 'Owned resource name already exists',
    'isolated_postgres_not_ready', 'isolated_database_restore_failed', 'readonly_sql_failed',
    'storage_inspection_failed', 'resource_inventory_failed', 'isolated_network_failed',
    'isolated_volume_failed', 'isolated_postgres_failed', 'isolated_reference_database_failed',
    'isolated_image_identity_failed', 'isolated_synthetic_schema_check_failed',
    'PermissionError', 'FileNotFoundError', 'ValueError', 'TimeoutExpired',
})


class BackupGuardError(RuntimeError):
    """Non-sensitive, fixed diagnostic codes only."""


def require(value, code):
    if not value:
        raise BackupGuardError(code)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(data):
    # Windows SCP can preserve CRLF. Accept only this encoding-equivalent
    # representation of the exact reviewed source; preserve it on replacement.
    return data.replace(b'\r\n', b'\n')


def approved_revisions(data):
    tree = ast.parse(data)
    assignments = [node for node in tree.body if isinstance(node, ast.Assign)
                   and any(isinstance(target, ast.Name) and target.id == 'APPROVED_REVISIONS'
                           for target in node.targets)]
    require(len(assignments) == 1, 'Backup_revision_guard_structure_unknown')
    value = ast.literal_eval(assignments[0].value)
    require(type(value) is set and all(type(item) is str for item in value),
            'Backup_revision_guard_not_a_literal_set')
    return value


def revised_source(data):
    require(digest(canonical(data)) in {OLD_SHA, NEW_SHA}, 'Backup_scheduler_source_unknown')
    if digest(canonical(data)) == NEW_SHA:
        return data
    text = data.decode('utf-8')
    require(text.count(OLD_LINE) == 1, 'Backup_revision_guard_structure_unknown')
    result = text.replace(OLD_LINE, NEW_LINE, 1).encode()
    require(digest(canonical(result)) == NEW_SHA and approved_revisions(result) ==
            {'20261006_0025', '20261007_0031', SCHEMA}, 'Backup_guard_change_outside_known_scope')
    return result


def read_regular_source(path):
    require(path.resolve() == path and not path.is_symlink(), 'Backup_source_symlink_or_path_changed')
    info = path.stat()
    require(stat.S_ISREG(info.st_mode) and info.st_uid == 0 and not info.st_mode & 0o022,
            'Backup_source_permissions_incorrect')
    return path.read_bytes(), info


def unit_state(host):
    raw = host.run(['systemctl', 'show', UNIT, '-p', 'ActiveState', '-p', 'SubState',
                    '-p', 'Result', '-p', 'ExecMainStatus', '-p', 'WorkingDirectory', '-p', 'ExecStart'])
    values = dict(line.split('=', 1) for line in raw.splitlines() if '=' in line)
    # ExecStart can contain configuration: validate it privately, never print it.
    expected = 'argv[]=/usr/bin/python3 -m app.scripts.prelaunch_scheduled_backup --execute-scheduled-capture ;'
    require(values.get('WorkingDirectory') == str(WORKING_DIRECTORY)
            and expected in values.get('ExecStart', '')
            and values['ExecStart'].count('argv[]=') == 1, 'Backup_unit_command_or_directory_unknown')
    return {key: values.get(key) for key in ('ActiveState', 'SubState', 'Result', 'ExecMainStatus')}


def prepare(host, *, apply=False):
    state = unit_state(host)
    data, info = read_regular_source(SCHEDULE)
    core, _ = read_regular_source(CORE)
    revisions = approved_revisions(data)
    report = dict(unit=state, schema_required=SCHEMA, approved_revisions_before=sorted(revisions),
                  scheduler_sha256=digest(data), scheduler_source_recognized=digest(canonical(data)) in {OLD_SHA, NEW_SHA},
                  restore_engine_recognized=digest(canonical(core)) == CORE_SHA, restore_engine_sha256=digest(core),
                  schema_already_approved=SCHEMA in revisions, source_modified=False,
                  credentials_printed=False)
    host.backup_guard_diagnostic = report
    require(report['scheduler_source_recognized'] and report['restore_engine_recognized'],
            'Backup_sources_differ_from_verified_versions')
    require(state['ActiveState'] in {'inactive', 'failed'}, 'Backup_already_running')
    if SCHEMA not in revisions and apply:
        descriptor = os.open(BACKUP_ROOT / 'capture.lock', os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(descriptor, 'rb') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            # Never replace unknown edits, and preserve the previous code privately.
            require(SCHEDULE.read_bytes() == data, 'Backup_scheduler_changed_during_preparation')
            target = host.directory / 'backup-scheduler.previous.py'
            with target.open('xb') as saved:
                os.fchmod(saved.fileno(), 0o600)
                saved.write(data)
            updated = revised_source(data)
            temporary = SCHEDULE.with_name(SCHEDULE.name + '.' + uuid.uuid4().hex)
            try:
                with temporary.open('xb') as output:
                    os.fchmod(output.fileno(), stat.S_IMODE(info.st_mode))
                    os.fchown(output.fileno(), info.st_uid, info.st_gid)
                    output.write(updated)
                    output.flush()
                    os.fsync(output.fileno())
                require(SCHEDULE.read_bytes() == data, 'Backup_scheduler_changed_during_preparation')
                temporary.replace(SCHEDULE)
                report['source_modified'] = 'unknown'
            finally:
                temporary.unlink(missing_ok=True)
            require(digest(canonical(SCHEDULE.read_bytes())) == NEW_SHA, 'Updated_backup_scheduler_integrity_failed')
        report.update(source_modified=True, scheduler_sha256_after=digest(updated),
                      previous_source=str(target), approved_revisions_after=sorted(approved_revisions(updated)))
    report['ready_for_schema_0033'] = SCHEMA in approved_revisions(SCHEDULE.read_bytes())
    return report


def verify_backup_revision(backup_id):
    require(isinstance(backup_id, str) and bool(re.fullmatch(r'\d{8}T\d{6}Z_[0-9a-f]{6}', backup_id)),
            'Fresh_backup_identifier_invalid')
    report = json.loads((BACKUPS / ('prelaunch-lot26-' + backup_id) / 'rehearsal.json').read_text())
    require(report.get('backup_id') == backup_id and report.get('production_revision') == SCHEMA
            and report.get('passed') is True and report.get('schema_backup_restored') is True
            and report.get('owned_test_resources_removed') is True
            and report.get('decrypted_staging_removed') is True, 'Fresh_backup_for_schema_0033_not_verified')
    return True


def failure_diagnostic(host):
    report = {'unit': unit_state(host), 'raw_logs_printed': False}
    paths = sorted(BACKUPS.glob('prelaunch-lot26-*/rehearsal.json'),
                   key=lambda path: path.stat().st_mtime, reverse=True)
    if paths:
        raw = json.loads(paths[0].read_text())
        report['latest_backup'] = {key: raw.get(key) for key in
            ('backup_id', 'production_revision', 'passed', 'schema_backup_restored',
             'owned_test_resources_removed', 'decrypted_staging_removed', 'finished_at')}
        failure = raw.get('failure')
        if failure:
            report['latest_backup']['failure_code'] = failure if isinstance(failure, str) and failure in SAFE_BACKUP_FAILURES else 'unclassified_failure'
    return report
