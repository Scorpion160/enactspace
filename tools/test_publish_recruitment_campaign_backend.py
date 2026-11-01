"""Exercise release sequencing and recovery without Docker, mail or production."""
import copy
from datetime import datetime, timezone
import importlib.util
import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('recruitment_publish', Path(__file__).with_name('publish_recruitment_campaign_backend.py'))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)

ORIGINAL = '\n'.join('  image: ' + release.OLD_IMAGE for _ in range(4)) + '\n APP_VERSION: "1.0.17"\n# keep this\n'


def rehearsal():
    return {'status': 'RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED',
            'operation_id': release.REHEARSAL_ID, 'candidate_image': release.IMAGE,
            'candidate_image_id': release.IMAGE_ID, 'base_image_id': release.OLD_IMAGE_ID,
            'owned_runtime_resources_removed': True, 'cleanup_errors': [], 'test_runner_exit_code': 0,
            'rehearsal': {'status': 'RECRUITMENT_POSTGRESQL_AND_VOLUME_REHEARSAL_PASSED',
                          'candidate_schema_head': release.SCHEMA, 'tests_run': 265,
                          'failures': 0, 'errors': 0, 'skipped': 0,
                          'volume': {'owned_schema_and_files_removed': True, 'measurements': [
                              {'dossiers': n, 'writers': 8, 'dossiers_and_tracking_and_files_match': True}
                              for n in (500, 1000)]}}}


class FakeHost:
    def __init__(self, directory, fail=None):
        self.directory = directory
        self.fail = fail
        self.events = []
        self.migrated = False
        self.content = ORIGINAL
        self.probes_stopped = True

    def event(self, name):
        self.events.append(name)
        if self.fail == name:
            raise release.ReleaseError('Simulated_failure')

    def healthy(self, version, image):
        self.event('healthy:' + version)

    def database(self):
        self.event('database:after' if self.migrated else 'database:before')
        counts = {'applications': 17, 'users': 22, 'stored_files': 13}
        if self.fail == 'counts' and self.migrated:
            counts['applications'] = 16
        return {'schema': [release.SCHEMA if self.migrated else '20261007_0031'], 'counts': counts}

    def candidate(self, program):
        if program == release.CATALOG_PROBE:
            self.event('catalog')
            return json.dumps({'catalog_and_routes_verified': True})
        if program == release.MIGRATION_PROBE:
            self.event('migration')
            self.migrated = True
            return json.dumps({'migration_command_completed': True})
        raise AssertionError('Unexpected probe')

    def compose(self, *args):
        self.event('compose:' + args[0])
        self.events.append(tuple(args))

    def verified_backup(self):
        self.event('backup')
        return 'verified-fixture'

    def replace(self, old, new):
        self.event('replace')
        if self.content != old:
            raise release.ReleaseError('Compose_changed_during_release')
        self.content = new

    def configuration(self):
        self.event('configuration')

    def timeline(self):
        self.event('timeline')


class ReleaseTests(unittest.TestCase):
    def run_release(self, fail=None, execute=True):
        with tempfile.TemporaryDirectory() as directory:
            host = FakeHost(Path(directory), fail)
            with patch('builtins.print'):
                report = release.perform_release(host, ORIGINAL, execute)
            return host, report

    def test_only_verified_image_and_successful_volume_receipt_are_accepted(self):
        release.validate_rehearsal(rehearsal())
        for change in ['candidate_image_id', 'operation_id', 'base_image_id', 'owned_runtime_resources_removed']:
            value = rehearsal(); value[change] = 'wrong'
            with self.subTest(field=change), self.assertRaises(release.ReleaseError):
                release.validate_rehearsal(value)

    def test_failures_skips_and_incomplete_volume_block_publication(self):
        for key in ['failures', 'errors', 'skipped', 'tests_run']:
            value = rehearsal(); value['rehearsal'][key] = 1
            with self.subTest(field=key), self.assertRaises(release.ReleaseError):
                release.validate_rehearsal(value)
        for key, value in [('writers', 1), ('dossiers_and_tracking_and_files_match', False), ('dossiers', 10)]:
            item = rehearsal(); item['rehearsal']['volume']['measurements'][1][key] = value
            with self.subTest(field=key), self.assertRaises(release.ReleaseError):
                release.validate_rehearsal(item)

    def test_compose_switch_changes_only_four_images_and_backend_version(self):
        updated = release.updated_compose(ORIGINAL)
        self.assertEqual(updated.count('image: ' + release.IMAGE_ID), 4)
        self.assertIn('# keep this', updated)
        self.assertIn('APP_VERSION: "1.0.21"', updated)
        for altered in [ORIGINAL.replace('1.0.17', 'other'), ORIGINAL.replace(release.OLD_IMAGE, 'other', 1)]:
            with self.assertRaises(release.ReleaseError): release.updated_compose(altered)

    def test_preflight_never_pauses_migrates_or_changes_configuration(self):
        host, report = self.run_release(execute=False)
        self.assertEqual(report['status'], 'RECRUITMENT_BACKEND_PREFLIGHT_PASSED')
        self.assertEqual(host.content, ORIGINAL)
        self.assertNotIn('backup', host.events)
        self.assertNotIn('migration', host.events)
        self.assertFalse(any(isinstance(e, tuple) for e in host.events))

    def test_success_orders_backup_migration_switch_then_health(self):
        host, report = self.run_release()
        self.assertEqual(report['status'], 'RECRUITMENT_BACKEND_DEPLOYED')
        for before, after in [('compose:stop', 'backup'), ('backup', 'migration'),
                              ('migration', 'replace'), ('replace', 'compose:up'),
                              ('compose:up', 'healthy:1.0.21')]:
            self.assertLess(host.events.index(before), host.events.index(after))
        self.assertTrue(report['deployment_performed'])
        self.assertTrue(report['migration_performed'])
        self.assertFalse(report['ready_for_campaign'])
        self.assertFalse(report['payments_enabled'])

    def test_missing_backup_restarts_old_services_without_migration(self):
        host, report = self.run_release('backup')
        self.assertNotIn('migration', host.events)
        self.assertEqual(host.content, ORIGINAL)
        self.assertIn('compose:start', host.events)
        self.assertTrue(report['previous_services_restored'])

    def test_failed_migration_restores_services_and_never_downgrades(self):
        host, report = self.run_release('migration')
        self.assertEqual(host.content, ORIGINAL)
        self.assertTrue(report['previous_services_restored'])
        self.assertTrue(report['database_schema_preserved_no_downgrade'])
        self.assertFalse(report['deployment_performed'])

    def test_changed_core_counts_block_before_config_switch(self):
        host, report = self.run_release('counts')
        self.assertNotIn('replace', host.events)
        self.assertTrue(report['previous_services_restored'])
        self.assertEqual(report['reason'], 'Post_migration_integrity_failed')

    def test_post_switch_failures_restore_original_configuration_and_services(self):
        for failure in ['healthy:1.0.21', 'configuration', 'timeline']:
            with self.subTest(failure=failure):
                host, report = self.run_release(failure)
                self.assertEqual(host.content, ORIGINAL)
                self.assertTrue(report['previous_services_restored'])
                self.assertTrue(host.migrated)
                self.assertFalse(report['deployment_performed'])

    def test_preflight_failure_does_not_change_active_services(self):
        host, report = self.run_release('catalog')
        self.assertFalse(any(isinstance(e, tuple) for e in host.events))
        self.assertFalse(report['migration_attempted'])

    def test_unknown_live_configuration_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / 'compose.yml'; base.write_text('newer content')
            with patch.object(release, 'BASE', base), self.assertRaises(release.ReleaseError):
                release.Host(Path(directory)).replace('expected', 'replacement')
            self.assertEqual(base.read_text(), 'newer content')

    def test_valid_atomic_replace_preserves_file_mode(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory) / 'compose.yml'; base.write_text('before'); base.chmod(0o640)
            with patch.object(release, 'BASE', base):
                release.Host(Path(directory)).replace('before', 'after')
            self.assertEqual(base.read_text(), 'after')
            self.assertEqual(base.stat().st_mode & 0o777, 0o640)

    def test_stale_or_unverified_backup_is_rejected(self):
        now = datetime.now(timezone.utc).timestamp()
        receipt = {'passed': True, 'owned_test_resources_removed': True,
                   'decrypted_staging_removed': True, 'backup_id': 'owned-backup',
                   'finished_at': datetime.fromtimestamp(now + 1, timezone.utc).isoformat()}
        release.validate_backup(receipt, now)
        for key in ['passed', 'owned_test_resources_removed', 'decrypted_staging_removed']:
            changed = copy.deepcopy(receipt); changed[key] = False
            with self.subTest(field=key), self.assertRaises(release.ReleaseError):
                release.validate_backup(changed, now)
        with self.assertRaises(release.ReleaseError): release.validate_backup(receipt, now + 5)

    def test_backup_waits_for_new_invocation_instead_of_using_old_success(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); report = root / 'prelaunch-lot26-owned/rehearsal.json'
            report.parent.mkdir()
            now = time.time() - 1
            report.write_text(json.dumps({'passed': True, 'owned_test_resources_removed': True,
                'decrypted_staging_removed': True, 'backup_id': 'fresh-fixture',
                'finished_at': datetime.fromtimestamp(now + 1, timezone.utc).isoformat()}))
            host = release.Host(root)
            states = iter([
                'inactive', '',
                'ActiveState=inactive\nResult=success\nExecMainStatus=0\nExecMainStartTimestampMonotonic=99000000',
                'ActiveState=activating\nResult=success\nExecMainStatus=0\nExecMainStartTimestampMonotonic=101000000',
                'ActiveState=inactive\nResult=success\nExecMainStatus=0\nExecMainStartTimestampMonotonic=101000000'])
            with patch.object(host, 'run', side_effect=lambda *a, **k: next(states)), \
                 patch.object(release, 'BACKUPS', root), patch.object(release.time, 'time', return_value=now), \
                 patch.object(release.time, 'monotonic', return_value=100), patch.object(release.time, 'sleep') as sleep, \
                 patch('builtins.print'):
                self.assertEqual(host.verified_backup(), 'fresh-fixture')
                self.assertEqual(sleep.call_count, 2)

    def test_running_backup_blocks_without_starting_another_invocation(self):
        with tempfile.TemporaryDirectory() as directory:
            host = release.Host(Path(directory))
            with patch.object(host, 'run', return_value='activating') as run, self.assertRaises(release.ReleaseError):
                host.verified_backup()
            self.assertEqual(run.call_count, 1)

    def test_timed_out_one_off_is_removed_only_with_matching_owner(self):
        for owned in (True, False):
            with self.subTest(owned=owned), tempfile.TemporaryDirectory() as directory:
                host = release.Host(Path(directory) / ('publish-recruitment-' + 'a' * 32))
                name = 'enactspace-recruitment-probe-' + 'a' * 32 + '-1'
                calls = []
                def run(args, **kwargs):
                    calls.append(args)
                    if args[1] == 'compose': raise release.ReleaseError('Command_timeout')
                    if args[1] == 'ps': return json.dumps({'Names': name})
                    if args[1] == 'inspect': return json.dumps([{'Id': 'owned-container-id', 'Config': {
                        'Labels': {'net.enactspace.release': 'a' * 32 if owned else 'b' * 32}}}])
                    return ''
                with patch.object(host, 'run', side_effect=run), self.assertRaises(release.ReleaseError):
                    host.candidate('fixture')
                removals = [args for args in calls if args[1] == 'rm']
                self.assertEqual(removals, [['docker', 'rm', '-f', 'owned-container-id']] if owned else [])
                self.assertEqual(host.probes_stopped, owned)

    def test_unverified_probe_cleanup_prevents_unsafe_service_restart(self):
        with tempfile.TemporaryDirectory() as directory:
            host = FakeHost(Path(directory), 'migration'); host.probes_stopped = False
            with patch('builtins.print'):
                report = release.perform_release(host, ORIGINAL, True)
            self.assertFalse(report['previous_services_restored'])
            self.assertNotIn('compose:start', host.events)
            self.assertNotIn('compose:up', host.events)

    def test_automatic_removal_race_requires_verified_absence(self):
        with tempfile.TemporaryDirectory() as directory:
            host = release.Host(Path(directory))
            name = 'owned-probe'
            with patch.object(host, 'run', side_effect=[json.dumps({'Names': name}),
                    release.ReleaseError('Command_failed'), '']):
                host.cleanup_probe(name)
            with patch.object(host, 'run', side_effect=[json.dumps({'Names': name}),
                    release.ReleaseError('Command_failed'), release.ReleaseError('Command_failed')]), \
                    self.assertRaises(release.ReleaseError):
                host.cleanup_probe(name)

    def test_database_probe_rejects_unsafe_settings_and_unknown_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            host = release.Host(Path(directory))
            valid = {'schema': ['20261007_0031'], 'counts': {}, 'database_read_only_verified': True}
            settings = {'production': True, 'payments_remain_disabled': True}
            with patch.object(host, 'candidate', return_value=json.dumps(settings) + '\n' + json.dumps(valid)):
                self.assertEqual(host.database(), valid)
            for unsafe, data in [({'production': False}, valid), (settings, {**valid, 'schema': ['unknown']}),
                                 (settings, {**valid, 'database_read_only_verified': False})]:
                with patch.object(host, 'candidate', return_value=json.dumps(unsafe) + '\n' + json.dumps(data)), \
                     self.assertRaises(release.ReleaseError):
                    host.database()

    def test_termination_is_not_swallowed_by_health_retry_loop(self):
        with tempfile.TemporaryDirectory() as directory:
            host = release.Host(Path(directory))
            with patch.object(release.urllib.request, 'urlopen', side_effect=KeyboardInterrupt), \
                 self.assertRaises(KeyboardInterrupt):
                host.healthy('fixture', 'fixture')


if __name__ == '__main__':
    unittest.main(verbosity=2)
