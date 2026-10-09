"""Exact recruitment test cleanup; default dry run. Execute on the Linux VPS host."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

CAMPAIGN = '413a685b-4f73-4b08-8f6d-4078804fd1d0'
APPLICATIONS = {'1ff534e2-df73-427d-8b76-78aa7b3bc185',
                '70e96e1e-59ef-46e9-b3d5-ace63a90f23c',
                'da836ba9-543a-4a14-bd58-2cd017bb3ec8'}
ALLOWED = {'recruitment_campaigns', 'applications', 'application_reviews',
           'notifications', 'email_deliveries', 'push_deliveries', 'audit_logs', 'stored_files'}

def identity(row):
    if row.get('id') is None:
        raise RuntimeError('Selected_row_has_no_id')
    return str(row['id'])

def select_rows(data, foreign_keys):
    selected = {name: set() for name in data}
    campaign = [r for r in data['recruitment_campaigns'] if identity(r) == CAMPAIGN]
    if len(campaign) != 1 or campaign[0]['title'] != 'Test_recrutement':
        raise RuntimeError('Campaign_identity_changed')
    apps = [r for r in data['applications'] if str(r['campaign_id']) == CAMPAIGN]
    if {identity(r) for r in apps} != APPLICATIONS or any(r.get('converted_user_id') for r in apps):
        raise RuntimeError('Application_set_changed_or_converted')
    selected['recruitment_campaigns'] = {CAMPAIGN}
    selected['applications'] = set(APPLICATIONS)
    for name in ('notifications', 'audit_logs', 'stored_files'):
        if name not in data:
            continue
        for row in data[name]:
            kind = row.get('related_type') if name == 'notifications' else row.get('entity_type')
            reference = str(row.get('related_id') if name == 'notifications' else row.get('entity_id'))
            if (kind == 'application' and reference in APPLICATIONS) or (
                    kind in ('recruitment_campaign', 'campaign') and reference == CAMPAIGN):
                selected[name].add(identity(row))
    keys = {'recruitment-submission:' + value for value in APPLICATIONS}
    for row in data.get('email_deliveries', []):
        if row.get('dedupe_key') in keys:
            selected['email_deliveries'].add(identity(row))
    # Discover every FK dependent, including descendants, rather than relying on CASCADE alone.
    changed = True
    while changed:
        changed = False
        for child, parent, child_column, parent_column in foreign_keys:
            if not selected.get(parent):
                continue
            values = {str(r.get(parent_column)) for r in data.get(parent, [])
                      if identity(r) in selected.get(parent, set())}
            if not values:
                continue
            for row in data[child]:
                if row.get(child_column) is not None and str(row[child_column]) in values:
                    if child not in ALLOWED:
                        raise RuntimeError('Unexpected_linked_table_' + child)
                    value = identity(row)
                    if value not in selected[child]:
                        selected[child].add(value)
                        changed = True
    if len(selected.get('notifications', set())) != 9 or len(selected.get('email_deliveries', set())) != 12:
        raise RuntimeError('Notification_or_email_count_changed')
    # Attachment URLs must resolve to selected stored-file rows; no broad filesystem deletion.
    file_rows = [r for r in data.get('stored_files', []) if identity(r) in selected['stored_files']]
    for app in apps:
        for column in ('cv_url', 'motivation_letter_url', 'attachment_url'):
            url = app.get(column)
            if url and not any(identity(r) in url or str(r.get('storage_path') or '__unmatched__') in url for r in file_rows):
                raise RuntimeError('Attachment_reference_not_resolved')
    for stored in file_rows:
        fid, path = identity(stored), str(stored['storage_path'])
        for name, rows in data.items():
            for row in rows:
                if row.get('id') is not None and identity(row) in selected[name]:
                    continue
                if name == 'stored_files' and row.get('storage_path') == path:
                    raise RuntimeError('Shared_physical_file')
                if any(fid in str(v) or (path and path in str(v)) for v in row.values()):
                    raise RuntimeError('Shared_attachment_reference_' + name)
    return {name: values for name, values in selected.items() if values}

def fingerprint(data, selected):
    rows = {name: sorted((r for r in data[name] if identity(r) in ids), key=identity)
            for name, ids in sorted(selected.items())}
    return hashlib.sha256(json.dumps(rows, sort_keys=True, default=str).encode()).hexdigest()

def verify_backup(root, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    reports = sorted(root.glob('prelaunch-lot26-*/rehearsal.json'), key=lambda p: p.stat().st_mtime, reverse=True)
    if not reports:
        raise RuntimeError('Verified_backup_report_missing')
    path = reports[0]
    if path.is_symlink() or path.parent.is_symlink() or path.parent.stat().st_mode & 0o077:
        raise RuntimeError('Backup_directory_not_private')
    report = json.loads(path.read_text())
    finished = dt.datetime.fromisoformat(report['finished_at'])
    if not 0 <= (now - finished).total_seconds() <= 3600:
        raise RuntimeError('Verified_backup_not_fresh')
    for key in ('passed', 'database_content_equal', 'files_content_equal', 'owned_test_resources_removed', 'decrypted_staging_removed'):
        if report.get(key) is not True:
            raise RuntimeError('Backup_verification_incomplete')
    if report.get('production_revision') != '20261006_0025':
        raise RuntimeError('Backup_schema_changed')
    for name in ('database.dump.gpg', 'uploads.tar.gz.gpg', 'verification.json.gpg'):
        file = path.parent / name
        expected = report['encrypted_archives'][name]
        if file.is_symlink() or file.stat().st_size != expected['bytes'] or hashlib.sha256(file.read_bytes()).hexdigest() != expected['sha256']:
            raise RuntimeError('Encrypted_backup_integrity_failed')
    return {'backup_id': report['backup_id'], 'verified_report_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'finished_at': report['finished_at']}

def inside(execute, backup_receipt, expected_fingerprint):
    from sqlalchemy import MetaData, inspect, select, text, cast, String
    from app.db.database import engine
    from app.core.config import settings
    from app.services.file_storage_service import UPLOAD_ROOT
    if engine.dialect.name != 'postgresql':
        raise RuntimeError('PostgreSQL_required')
    if not settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT or (settings.EMAIL_TEST_RECIPIENT or '').strip().lower() != 'dioppylsci@gmail.com' or settings.MOBILE_MONEY_ENABLED:
        raise RuntimeError('Test_delivery_guards_changed')
    moved = []
    quarantine = None
    committed = False
    with engine.connect() as connection:
        tx = connection.begin()
        try:
            if not execute:
                connection.execute(text('SET TRANSACTION READ ONLY'))
            connection.execute(text("SET LOCAL lock_timeout = '10s'"))
            connection.execute(text("SET LOCAL statement_timeout = '30s'"))
            metadata = MetaData()
            metadata.reflect(bind=connection)
            if execute:
                # Keep FK and generic references stable while deleting. No workers/config changes.
                for name in sorted(metadata.tables):
                    quoted = connection.dialect.identifier_preparer.quote(name)
                    connection.execute(text('LOCK TABLE ' + quoted + ' IN SHARE ROW EXCLUSIVE MODE'))
            version = connection.execute(text('SELECT version_num FROM alembic_version')).scalar_one()
            if version != '20261006_0025':
                raise RuntimeError('Production_schema_changed')
            data = {name: [dict(r) for r in connection.execute(select(table)).mappings()]
                    for name, table in metadata.tables.items()}
            keys = []
            inspector = inspect(connection)
            for name in metadata.tables:
                for fk in inspector.get_foreign_keys(name):
                    if len(fk['constrained_columns']) != 1:
                        if fk['referred_table'] in ALLOWED:
                            raise RuntimeError('Unsupported_composite_reference')
                        continue
                    keys.append((name, fk['referred_table'], fk['constrained_columns'][0], fk['referred_columns'][0]))
            selected = select_rows(data, keys)
            digest = fingerprint(data, selected)
            file_rows = [r for r in data.get('stored_files', []) if identity(r) in selected.get('stored_files', set())]
            root = UPLOAD_ROOT.resolve()
            files = []
            for row in file_rows:
                raw = root / row['storage_path']
                path = raw.resolve()
                if raw.is_symlink() or root not in path.parents or not path.is_file():
                    raise RuntimeError('Attachment_path_unsafe_or_missing')
                # Reject symlinks at any component, including directory components.
                cursor = raw
                while cursor != root:
                    if cursor.is_symlink():
                        raise RuntimeError('Symlink_attachment_path')
                    cursor = cursor.parent
                files.append(path)
            if len(set(files)) != len(files):
                raise RuntimeError('Duplicate_physical_attachment')
            file_hashes = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
            digest = hashlib.sha256((digest + json.dumps(file_hashes, sort_keys=True)).encode()).hexdigest()
            summary = {'status': 'CLEANUP_PLAN', 'campaign_id': CAMPAIGN, 'counts': {k: len(v) for k, v in selected.items()},
                       'physical_files': len(files), 'selection_fingerprint': digest, 'backup': backup_receipt,
                       'deletion_performed': False, 'personal_data_printed': False}
            if not execute:
                tx.rollback()
                return summary
            if not backup_receipt or expected_fingerprint != digest:
                raise RuntimeError('Reviewed_selection_changed_or_missing')
            quarantine = root / ('.cleanup-test-' + uuid.uuid4().hex)
            quarantine.mkdir(mode=0o700)
            for index, path in enumerate(files):
                if hashlib.sha256(path.read_bytes()).hexdigest() != file_hashes[str(path)]:
                    raise RuntimeError('Attachment_changed_during_cleanup')
                target = quarantine / str(index)
                path.rename(target)
                moved.append((path, target))
            for table in reversed(metadata.sorted_tables):
                ids = selected.get(table.name)
                if ids:
                    connection.execute(table.delete().where(cast(table.c.id, String).in_(sorted(ids))))
            for name, table in metadata.tables.items():
                remaining = connection.execute(select(table)).mappings().all()
                expected = [r for r in data[name] if r.get('id') is None or identity(r) not in selected.get(name, set())]
                actual_hash = hashlib.sha256(json.dumps(sorted([dict(r) for r in remaining], key=lambda r: json.dumps(r, sort_keys=True, default=str)), sort_keys=True, default=str).encode()).hexdigest()
                expected_hash = hashlib.sha256(json.dumps(sorted(expected, key=lambda r: json.dumps(r, sort_keys=True, default=str)), sort_keys=True, default=str).encode()).hexdigest()
                if actual_hash != expected_hash:
                    raise RuntimeError('Unexpected_database_change_' + name)
            tx.commit()
            committed = True
            summary.update(status='CLEANUP_DATABASE_COMMITTED', deletion_performed=True, unrelated_rows_unchanged=True)
            try:
                shutil.rmtree(quarantine)
                summary.update(status='CLEANUP_COMPLETED', physical_files_removed=True)
            except OSError:
                summary.update(physical_files_removed=False, quarantine_cleanup_pending=True)
            return summary
        finally:
            if not committed:
                if tx.is_active:
                    tx.rollback()
                for original, target in reversed(moved):
                    target.rename(original)
                if quarantine and quarantine.exists():
                    quarantine.rmdir()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute', action='store_true')
    parser.add_argument('--expected-fingerprint')
    parser.add_argument('--inside-container', action='store_true')
    parser.add_argument('--backup-receipt')
    args = parser.parse_args()
    try:
        if args.inside_container:
            result = inside(args.execute, json.loads(args.backup_receipt) if args.backup_receipt else None, args.expected_fingerprint)
            print(json.dumps(result, default=str, sort_keys=True))
            return 0 if result.get('status') != 'CLEANUP_DATABASE_COMMITTED' else 1
        if os.name != 'posix':
            raise RuntimeError('Run_on_Linux_VPS_host')
        receipt = verify_backup(Path('/var/backups/enactspace'))
        command = ['docker', 'exec', '-i', 'enactspace_backend', 'python', '-', '--inside-container', '--backup-receipt', json.dumps(receipt)]
        if args.execute:
            if not args.expected_fingerprint or len(args.expected_fingerprint) != 64:
                raise RuntimeError('Reviewed_fingerprint_required')
            command += ['--execute', '--expected-fingerprint', args.expected_fingerprint]
        completed = subprocess.run(command, input=Path(__file__).read_text(), capture_output=True, text=True, timeout=180)
        if completed.returncode:
            # Only emit the last structured masked result, never traceback/SQL parameters.
            for line in reversed(completed.stdout.splitlines()):
                try:
                    value = json.loads(line)
                    if isinstance(value, dict) and 'status' in value:
                        print(json.dumps(value))
                        return 1
                except ValueError:
                    pass
            raise RuntimeError('Container_cleanup_failed')
        result = json.loads(completed.stdout)
        print(json.dumps(result, indent=2))
        return 0
    except Exception as exc:
        message = str(exc) if isinstance(exc, RuntimeError) and str(exc).replace('_', '').isalnum() else type(exc).__name__
        print(json.dumps({'status': 'CLEANUP_BLOCKED_OR_INTERRUPTED', 'reason': message, 'success_claimed': False}))
        return 1

if __name__ == '__main__':
    sys.exit(main())
