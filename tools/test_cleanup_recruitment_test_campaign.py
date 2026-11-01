"""Host orchestration only: no Docker, production DB, mail or service access."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import cleanup_recruitment_test_campaign as cleanup


TARGET = dict(id='00000000-0000-4000-8000-000000000001', title='Synthetic test',
              fingerprint='a' * 64, eligible_for_authorized_test_cleanup=True)
BEFORE = dict(campaign_count=1, total_applications=1, campaigns=[TARGET])
AFTER = dict(campaign_count=0, total_applications=0, campaigns=[])
SUCCESS = dict(status='TEST_CAMPAIGN_DATA_REMOVED', database_modified=True,
               unrelated_rows_preserved=True, user_accounts_preserved=True)


class FakeHost:
    def __init__(self):
        self.events = []
        self.inventories = [deepcopy(BEFORE), deepcopy(BEFORE), deepcopy(AFTER)]
        self.probes_stopped = True
        self.backup_error = False
        self.cleanup_error = False
        self.result = deepcopy(SUCCESS)

    def healthy(self, *args):
        self.events.append('health')

    def configuration(self):
        self.events.append('configuration')

    def compose(self, *args):
        self.events.append(args[0])

    def verified_backup(self):
        self.events.append('backup')
        if self.backup_error:
            raise RuntimeError('Synthetic failure')
        return 'synthetic_verified_backup'

    def candidate(self, program):
        if "MODE='erase'" in program:
            self.events.append('erase')
            if self.cleanup_error:
                self.probes_stopped = False
                raise RuntimeError('Synthetic timeout')
            return json.dumps(self.result)
        self.events.append('inventory')
        return json.dumps(dict(status='TEST_CAMPAIGN_INVENTORY_COMPLETE',
                               database_read_only_verified=True, inventory=self.inventories.pop(0)))


class CleanupHostTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.base = Path(self.directory.name) / 'compose.yml'
        self.base.write_text('unchanged production compose')
        self.patch_base = patch.object(cleanup, 'BASE', self.base)
        self.patch_base.start()
        self.patch_test = patch.object(cleanup, 'isolated_tests', return_value={'passed': True, 'tests_run': 15})
        self.patch_test.start()
        self.patch_guard = patch.object(cleanup.backup_guard, 'prepare', return_value={
            'ready_for_schema_0033': True, 'source_modified': False})
        self.patch_guard.start()
        self.patch_revision = patch.object(cleanup.backup_guard, 'verify_backup_revision', return_value=True)
        self.patch_revision.start()
        self.patch_diagnostic = patch.object(cleanup.backup_guard, 'failure_diagnostic', return_value={'raw_logs_printed': False})
        self.patch_diagnostic.start()
        self.host = FakeHost()

    def tearDown(self):
        self.patch_test.stop()
        self.patch_guard.stop()
        self.patch_revision.stop()
        self.patch_diagnostic.stop()
        self.patch_base.stop()
        self.directory.cleanup()

    def perform(self, execute=True):
        return cleanup.perform_cleanup(self.host, 'unchanged production compose', execute)

    def test_inventory_never_pauses_backs_up_or_deletes(self):
        report = self.perform(False)
        self.assertEqual(report['status'], 'TEST_CAMPAIGN_INVENTORY_COMPLETE')
        self.assertFalse(report['database_modified'])
        self.assertNotIn('stop', self.host.events)
        self.assertNotIn('backup', self.host.events)
        self.assertNotIn('erase', self.host.events)

    def test_success_orders_backup_revalidation_transaction_and_restart(self):
        report = self.perform()
        self.assertEqual(report['status'], 'TEST_CAMPAIGN_CLEANUP_PASSED')
        events = self.host.events
        self.assertLess(events.index('stop'), events.index('backup'))
        self.assertLess(events.index('backup'), events.index('erase'))
        self.assertEqual(events[:events.index('erase')].count('inventory'), 2)
        self.assertLess(events.index('erase'), events.index('start'))
        self.assertTrue(report['production_services_restored'])
        self.assertEqual(self.base.read_text(), 'unchanged production compose')

    def test_unexpected_campaign_inventory_blocks_before_any_stop(self):
        self.host.inventories[0] = dict(campaign_count=2, campaigns=[])
        report = self.perform()
        self.assertEqual(report['status'], 'TEST_CAMPAIGN_CLEANUP_BLOCKED')
        self.assertNotIn('stop', self.host.events)
        self.assertNotIn('erase', self.host.events)

    def test_failed_isolated_tests_never_touch_services(self):
        self.patch_test.stop()
        with patch.object(cleanup, 'isolated_tests', side_effect=RuntimeError):
            report = self.perform()
        self.assertEqual(report['status'], 'TEST_CAMPAIGN_CLEANUP_BLOCKED')
        self.assertNotIn('stop', self.host.events)

    def test_failed_backup_restarts_existing_services_without_deletion(self):
        self.host.backup_error = True
        report = self.perform()
        self.assertEqual(report['stage'], 'fresh_verified_backup')
        self.assertTrue(report['production_services_restored'])
        self.assertFalse(report['database_modified'])
        self.assertNotIn('erase', self.host.events)

    def test_missing_schema_approval_blocks_before_services_are_stopped(self):
        self.patch_guard.stop()
        with patch.object(cleanup.backup_guard, 'prepare', return_value={'ready_for_schema_0033': False}):
            report = self.perform()
        self.assertEqual(report['stage'], 'backup_schema_preflight')
        self.assertNotIn('stop', self.host.events)
        self.assertNotIn('erase', self.host.events)

    def test_backup_for_another_revision_never_allows_erasure(self):
        self.patch_revision.stop()
        with patch.object(cleanup.backup_guard, 'verify_backup_revision',
                          side_effect=cleanup.backup_guard.BackupGuardError('Fresh_backup_for_schema_0033_not_verified')):
            report = self.perform()
        self.assertEqual(report['reason'], 'Fresh_backup_for_schema_0033_not_verified')
        self.assertNotIn('erase', self.host.events)
        self.assertTrue(report['production_services_restored'])

    def test_known_release_error_code_is_reported_without_raw_command_output(self):
        ReleaseError = type('ReleaseError', (RuntimeError,), {})
        def failed_backup():
            raise ReleaseError('Backup_service_failed_or_stale')
        self.host.verified_backup = failed_backup
        report = self.perform()
        self.assertEqual(report['reason'], 'Backup_service_failed_or_stale')
        self.assertIn('backup_failure_diagnostic', report)

    def test_identified_campaign_id_is_checked_before_backup_or_service_stop(self):
        report = cleanup.perform_cleanup(self.host, 'unchanged production compose', True,
                                         expected_campaign_id='c430e401-34ca-4f4b-8713-aaab44faba6f')
        self.assertEqual(report['reason'], 'Campaign_identifier_differs_from_identified_test')
        self.assertNotIn('stop', self.host.events)

    def test_changed_fingerprint_prevents_delete_and_resumes_services(self):
        self.host.inventories[1]['campaigns'][0]['fingerprint'] = 'b' * 64
        report = self.perform()
        self.assertEqual(report['stage'], 'revalidate_plan')
        self.assertNotIn('erase', self.host.events)
        self.assertTrue(report['production_services_restored'])

    def test_rejected_transaction_is_not_reported_as_deleted(self):
        self.host.result = dict(status='TEST_CAMPAIGN_OPERATION_BLOCKED', database_modified=False)
        report = self.perform()
        self.assertEqual(report['status'], 'TEST_CAMPAIGN_CLEANUP_BLOCKED')
        self.assertFalse(report['database_modified'])
        self.assertTrue(report['production_services_restored'])

    def test_unverified_one_off_cleanup_blocks_restart_and_keeps_unknown_outcome(self):
        self.host.cleanup_error = True
        report = self.perform()
        self.assertFalse(report['production_services_restored'])
        self.assertEqual(report['database_modified'], 'unknown')
        self.assertNotIn('start', self.host.events)

    def test_external_config_change_is_never_overwritten(self):
        def changed():
            self.base.write_text('external change')
            return 'verified'
        self.host.verified_backup = changed
        report = self.perform()
        self.assertNotIn('erase', self.host.events)
        self.assertNotIn('start', self.host.events)
        self.assertFalse(report['production_services_restored'])
        self.assertEqual(self.base.read_text(), 'external change')


if __name__ == '__main__':
    unittest.main()
