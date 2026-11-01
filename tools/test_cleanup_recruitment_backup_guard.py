"""Backup guard migration with private synthetic files; no systemd or DB calls."""
import fcntl
import hashlib
import json
import os
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch

import recruitment_backup_schema_guard as guard


def fixture_source():
    directory = Path(__file__).resolve().parent
    paths = [directory / 'prelaunch_scheduled_backup.py',
             directory.parent / 'backend/app/scripts/prelaunch_scheduled_backup.py']
    return next(path for path in paths if path.is_file()).read_bytes()


class BackupSchemaGuardTests(unittest.TestCase):
    def setUp(self):
        self.new = fixture_source()
        self.old = self.new.replace(guard.NEW_LINE.encode(), guard.OLD_LINE.encode(), 1)
        self.directory = tempfile.TemporaryDirectory()
        root = Path(self.directory.name)
        self.root = root / 'backup-lot26'
        self.root.mkdir(mode=0o700)
        self.schedule = self.root / 'scheduled.py'
        self.schedule.write_bytes(self.old)
        self.schedule.chmod(0o640)
        self.core = self.root / 'core.py'
        self.core.write_bytes(b'known synthetic restore engine')
        self.lock = self.root / 'capture.lock'
        self.lock.write_bytes(b'lock contents preserved')
        self.operation = root / 'operation'
        self.operation.mkdir(mode=0o700)
        self.host = SimpleNamespace(directory=self.operation)
        self.state = {'ActiveState': 'failed', 'SubState': 'failed', 'Result': 'exit-code', 'ExecMainStatus': '1'}
        self.patches = [
            patch.object(guard, 'BACKUP_ROOT', self.root),
            patch.object(guard, 'SCHEDULE', self.schedule),
            patch.object(guard, 'CORE', self.core),
            patch.object(guard, 'CORE_SHA', hashlib.sha256(self.core.read_bytes()).hexdigest()),
            patch.object(guard, 'unit_state', return_value=self.state),
            patch.object(guard, 'read_regular_source', side_effect=lambda path: (path.read_bytes(), path.stat())),
        ]
        for item in self.patches:
            item.start()

    def tearDown(self):
        for item in reversed(self.patches):
            item.stop()
        self.directory.cleanup()

    def test_only_known_allowlist_gains_0033_and_unknown_revisions_stay_excluded(self):
        changed = guard.revised_source(self.old)
        self.assertEqual(changed, self.new)
        self.assertEqual(guard.approved_revisions(changed), {'20261006_0025', '20261007_0031', '20261031_0033'})
        self.assertNotIn('20261031_0034', guard.approved_revisions(changed))
        self.assertEqual(changed.replace(guard.NEW_LINE.encode(), guard.OLD_LINE.encode()), self.old)

    def test_unrecognized_modified_script_is_never_rewritten(self):
        self.schedule.write_bytes(self.old + b'\n# unreviewed modification\n')
        before = self.schedule.read_bytes()
        with self.assertRaisesRegex(guard.BackupGuardError, 'Backup_sources_differ_from_verified_versions'):
            guard.prepare(self.host, apply=True)
        self.assertEqual(self.schedule.read_bytes(), before)
        self.assertFalse((self.operation / 'backup-scheduler.previous.py').exists())

    def test_unknown_restore_engine_blocks_before_edit(self):
        self.core.write_bytes(b'unknown restore engine')
        with self.assertRaisesRegex(guard.BackupGuardError, 'Backup_sources_differ_from_verified_versions'):
            guard.prepare(self.host, apply=True)
        self.assertEqual(self.schedule.read_bytes(), self.old)

    def test_read_only_inspection_never_edits_source(self):
        result = guard.prepare(self.host)
        self.assertFalse(result['ready_for_schema_0033'])
        self.assertFalse(result['source_modified'])
        self.assertEqual(self.schedule.read_bytes(), self.old)

    def test_atomic_change_preserves_mode_owner_lock_and_previous_source(self):
        before = self.schedule.stat()
        result = guard.prepare(self.host, apply=True)
        self.assertTrue(result['ready_for_schema_0033'])
        self.assertTrue(result['source_modified'])
        self.assertEqual(self.schedule.read_bytes(), self.new)
        after = self.schedule.stat()
        self.assertEqual((before.st_mode, before.st_uid, before.st_gid), (after.st_mode, after.st_uid, after.st_gid))
        saved = self.operation / 'backup-scheduler.previous.py'
        self.assertEqual(saved.read_bytes(), self.old)
        self.assertEqual(saved.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.lock.read_bytes(), b'lock contents preserved')

    def test_already_fixed_script_is_idempotent(self):
        guard.prepare(self.host, apply=True)
        result = guard.prepare(self.host, apply=True)
        self.assertFalse(result['source_modified'])
        self.assertTrue(result['schema_already_approved'])

    def test_known_windows_line_endings_are_preserved_during_guard_update(self):
        windows = self.old.replace(b'\n', b'\r\n')
        self.schedule.write_bytes(windows)
        result = guard.prepare(self.host, apply=True)
        self.assertTrue(result['source_modified'])
        self.assertEqual(self.schedule.read_bytes(), self.new.replace(b'\n', b'\r\n'))

    def test_running_backup_blocks_without_changing_its_code(self):
        self.state['ActiveState'] = 'activating'
        with self.assertRaisesRegex(guard.BackupGuardError, 'Backup_already_running'):
            guard.prepare(self.host, apply=True)
        self.assertEqual(self.schedule.read_bytes(), self.old)

    def test_busy_capture_lock_prevents_replacement(self):
        with self.lock.open('rb') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaises(BlockingIOError):
                guard.prepare(self.host, apply=True)
        self.assertEqual(self.schedule.read_bytes(), self.old)

    def test_wrong_unit_command_or_directory_is_rejected_without_printing_it(self):
        self.patches[4].stop()
        host = SimpleNamespace(run=lambda *args: 'WorkingDirectory=/unexpected\nExecStart=private command\n')
        with self.assertRaisesRegex(guard.BackupGuardError, 'Backup_unit_command_or_directory_unknown') as error:
            guard.unit_state(host)
        self.assertNotIn('private command', str(error.exception))

    def test_correct_unit_command_returns_only_safe_state_fields(self):
        self.patches[4].stop()
        text = ('WorkingDirectory=' + str(guard.WORKING_DIRECTORY) + '\n'
            'ExecStart={ path=/usr/bin/python3 ; argv[]=/usr/bin/python3 -m app.scripts.prelaunch_scheduled_backup --execute-scheduled-capture ; }\n'
            'ActiveState=failed\nSubState=failed\nResult=exit-code\nExecMainStatus=1\n')
        host = SimpleNamespace(run=lambda *args: text)
        self.assertEqual(guard.unit_state(host), self.state)

    def test_fresh_receipt_must_verify_the_current_revision_and_restore(self):
        identity = '20261101T090000Z_abcdef'
        folder = self.root / ('prelaunch-lot26-' + identity)
        folder.mkdir()
        receipt = dict(backup_id=identity, production_revision='20261007_0031', passed=True,
                       schema_backup_restored=True, owned_test_resources_removed=True, decrypted_staging_removed=True)
        target = folder / 'rehearsal.json'
        with patch.object(guard, 'BACKUPS', self.root):
            target.write_text(json.dumps(receipt))
            with self.assertRaisesRegex(guard.BackupGuardError, 'Fresh_backup_for_schema_0033_not_verified'):
                guard.verify_backup_revision(identity)
            receipt['production_revision'] = guard.SCHEMA
            target.write_text(json.dumps(receipt))
            self.assertTrue(guard.verify_backup_revision(identity))
            receipt['schema_backup_restored'] = False
            target.write_text(json.dumps(receipt))
            with self.assertRaises(guard.BackupGuardError):
                guard.verify_backup_revision(identity)

    def test_symlink_source_is_never_followed(self):
        self.patches[5].stop()
        link = self.root / 'linked.py'
        link.symlink_to(self.schedule)
        with self.assertRaisesRegex(guard.BackupGuardError, 'Backup_source_symlink_or_path_changed'):
            guard.read_regular_source(link)

    def test_failure_diagnostic_reports_known_codes_and_masks_arbitrary_values(self):
        folder = self.root / 'prelaunch-lot26-20261101T090000Z_abcdef'
        folder.mkdir()
        receipt = folder / 'rehearsal.json'
        with patch.object(guard, 'BACKUPS', self.root):
            receipt.write_text(json.dumps({'passed': False, 'failure': 'Unexpected production revision'}))
            result = guard.failure_diagnostic(self.host)
            self.assertEqual(result['latest_backup']['failure_code'], 'Unexpected production revision')
            receipt.write_text(json.dumps({'passed': False, 'failure': 'private diagnostic text'}))
            result = guard.failure_diagnostic(self.host)
            self.assertEqual(result['latest_backup']['failure_code'], 'unclassified_failure')
            self.assertNotIn('private diagnostic text', json.dumps(result))


if __name__ == '__main__':
    unittest.main()
