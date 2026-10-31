"""Rehearsal guards; these tests never launch Docker or access a real database."""
import importlib.util
from contextlib import nullcontext, redirect_stderr, redirect_stdout
import io
import json
import stat
import tempfile
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from rehearse_recruitment_volume import guarded_url

spec = importlib.util.spec_from_file_location('candidate_rehearsal', Path(__file__).resolve().parents[1] / 'tools/rehearse_recruitment_candidate.py')
rehearsal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rehearsal)


class RehearsalSafetyTests(unittest.TestCase):
    def test_candidate_tools_are_traversable_and_base_user_is_restored(self):
        manifest = {'patch_revision': 'a' * 40, 'files': {'tools/audit_recruitment_campaign.py': 'unused'}}
        source = rehearsal.candidate_dockerfile('owned-base', 'b' * 32, manifest, 'enactspace:enactspace')
        self.assertIn('RUN chmod 0755 /app/tools', source)
        self.assertLess(source.index('COPY '), source.index('RUN chmod 0755 /app/tools'))
        self.assertTrue(source.endswith('USER enactspace:enactspace\n'))
        with self.assertRaisesRegex(RuntimeError, 'Non_root'):
            rehearsal.candidate_dockerfile('owned-base', 'b' * 32, manifest, 'root')

    def test_previous_cleanup_is_bound_to_the_exact_candidate_image(self):
        owner = 'a' * 32
        tag = 'enactspace-backend:recruitment-hardening-' + owner[:12]
        image = {'Id': 'sha256:' + 'b' * 64, 'Config': {'Labels': {'net.enactspace.rehearsal': owner}}}
        with patch.object(rehearsal, 'run', return_value=json.dumps([image])), patch.object(rehearsal, 'remove_owned_container') as remove, patch.object(rehearsal, 'remove_owned_volume') as remove_volume:
            with self.assertRaisesRegex(RuntimeError, 'image_changed'):
                rehearsal.cleanup_previous(tag, 'sha256:' + 'c' * 64)
            remove.assert_not_called()
            remove_volume.assert_not_called()
            body = rehearsal.cleanup_previous(tag, image['Id'])
            self.assertTrue(body['owned_runtime_resources_removed'])
            self.assertEqual(remove.call_count, 2)
            remove_volume.assert_called_once_with(rehearsal.owned_volume_name(owner), owner)
            self.assertEqual({call.args[0] for call in remove.call_args_list}, {
                'enactspace-recruitment-rehearsal-test-' + owner,
                'enactspace-recruitment-rehearsal-db-' + owner})

    def test_volume_refuses_production_or_remote_database_urls(self):
        for url in ['postgresql://user@127.0.0.1/enactspace', 'postgresql://user@production/enactspace_pr2b_test_x', 'sqlite://']:
            with self.subTest(url=url), self.assertRaises(RuntimeError):
                guarded_url(url)
        self.assertEqual(guarded_url('postgresql://user@127.0.0.1/enactspace_pr2b_test_owned').host, '127.0.0.1')

    def test_cleanup_refuses_an_unowned_container(self):
        results = [SimpleNamespace(returncode=0, stdout='d' * 64), SimpleNamespace(returncode=0, stdout=json.dumps([{'Id': 'd' * 64, 'Name': '/owned-name', 'Config': {'Labels': {'net.enactspace.rehearsal': 'other'}}}]))]
        with patch.object(rehearsal.subprocess, 'run', side_effect=results), patch.object(rehearsal, 'run') as mutate:
            with self.assertRaisesRegex(RuntimeError, 'ownership'):
                rehearsal.remove_owned_container('owned-name', 'our-id')
            mutate.assert_not_called()

    def test_cleanup_removes_only_the_matching_owned_name(self):
        results = [SimpleNamespace(returncode=0, stdout='d' * 64), SimpleNamespace(returncode=0, stdout=json.dumps([{'Id': 'd' * 64, 'Name': '/owned-name', 'Config': {'Labels': {'net.enactspace.rehearsal': 'our-id'}}}]))]
        with patch.object(rehearsal.subprocess, 'run', side_effect=results), patch.object(rehearsal, 'run') as mutate:
            rehearsal.remove_owned_container('owned-name', 'our-id')
            mutate.assert_called_once_with(['docker', 'container', 'rm', '-f', '-v', 'd' * 64])

    def test_failed_inspection_cannot_be_reported_as_successful_cleanup(self):
        results = [SimpleNamespace(returncode=0, stdout='d' * 64), SimpleNamespace(returncode=1, stderr='Docker daemon unavailable')]
        with patch.object(rehearsal.subprocess, 'run', side_effect=results):
            with self.assertRaisesRegex(RuntimeError, 'Cleanup_inspection_failed'):
                rehearsal.remove_owned_container('owned-name', 'our-id')

    def test_successful_empty_inventory_needs_no_inspection_or_deletion(self):
        result = SimpleNamespace(returncode=0, stdout='')
        with patch.object(rehearsal.subprocess, 'run', return_value=result) as inspect, patch.object(rehearsal, 'run') as mutate:
            rehearsal.remove_owned_container('already-absent', 'our-id')
            self.assertEqual(inspect.call_count, 1)
            mutate.assert_not_called()

    def test_failed_inventory_cannot_be_reported_as_successful_cleanup(self):
        result = SimpleNamespace(returncode=1, stderr='Untranslated daemon error')
        with patch.object(rehearsal.subprocess, 'run', return_value=result), patch.object(rehearsal, 'run') as mutate:
            with self.assertRaisesRegex(RuntimeError, 'Cleanup_inventory_failed'):
                rehearsal.remove_owned_container('owned-name', 'our-id')
            mutate.assert_not_called()

    def test_reused_name_and_ambiguous_inventory_never_authorize_removal(self):
        for results in ([SimpleNamespace(returncode=0, stdout='d' * 64), SimpleNamespace(returncode=0, stdout=json.dumps([{'Id': 'd' * 64, 'Name': '/other-name', 'Config': {'Labels': {'net.enactspace.rehearsal': 'our-id'}}}]))],
                        [SimpleNamespace(returncode=0, stdout='d' * 64 + '\n' + 'e' * 64)]):
            with patch.object(rehearsal.subprocess, 'run', side_effect=results), patch.object(rehearsal, 'run') as mutate:
                with self.assertRaises(RuntimeError):
                    rehearsal.remove_owned_container('owned-name', 'our-id')
                mutate.assert_not_called()

    def test_database_uses_owned_disk_data_with_same_memory_cpu_and_network_limits(self):
        owner = 'a' * 32
        volume = rehearsal.owned_volume_name(owner)
        command = rehearsal.database_command('enactspace-recruitment-rehearsal-db-'+owner, owner,
            volume, 'enactspace_pr2b_test_recruitment_'+owner[:12], 'postgres-fixture')
        self.assertIn('type=volume,source='+volume+',target=/var/lib/postgresql/data',command)
        self.assertIn('--memory=512m',command)
        self.assertIn('--cpus=0.5',command)
        self.assertIn('--network=none',command)
        self.assertFalse(any('/var/lib/postgresql/data:rw,size=' in arg for arg in command))
        with self.assertRaises(RuntimeError):
            rehearsal.database_command('enactspace_postgres',owner,volume,'enactspace','postgres-fixture')

    def test_volume_cleanup_refuses_unowned_data_or_driver_mount_options(self):
        owner='a'*32; name=rehearsal.owned_volume_name(owner)
        for row in ({'Name':name,'Driver':'local','Labels':{'net.enactspace.rehearsal':'someone-else'}},
                    {'Name':name,'Driver':'local','Labels':{'net.enactspace.rehearsal':owner},'Options':{'device':'/production'}}):
            with patch.object(rehearsal,'volume_inventory',return_value=[name]), patch.object(rehearsal,'run',return_value=json.dumps([row])) as commands:
                with self.assertRaisesRegex(RuntimeError,'ownership'):
                    rehearsal.remove_owned_volume(name,owner)
                self.assertEqual(commands.call_count,1)
                self.assertEqual(commands.call_args.args[0],['docker','volume','inspect',name])

    def test_volume_absence_requires_successful_inventory(self):
        owner='a'*32; name=rehearsal.owned_volume_name(owner)
        with patch.object(rehearsal.subprocess,'run',return_value=SimpleNamespace(returncode=0,stdout='production-data\n')), patch.object(rehearsal,'run') as mutate:
            rehearsal.remove_owned_volume(name,owner)
            mutate.assert_not_called()
        with patch.object(rehearsal.subprocess,'run',return_value=SimpleNamespace(returncode=1,stdout='')), patch.object(rehearsal,'run') as mutate:
            with self.assertRaisesRegex(RuntimeError,'inventory'):
                rehearsal.remove_owned_volume(name,owner)
            mutate.assert_not_called()

    def test_matching_volume_is_removed_by_exact_name_without_force_or_prune(self):
        owner='a'*32; name=rehearsal.owned_volume_name(owner)
        row={'Name':name,'Driver':'local','Options':{},'Labels':{'net.enactspace.rehearsal':owner}}
        with patch.object(rehearsal,'volume_inventory',return_value=[name]), patch.object(rehearsal,'run',side_effect=[json.dumps([row]),name]) as commands:
            rehearsal.remove_owned_volume(name,owner)
            self.assertEqual(commands.call_args.args[0],['docker','volume','rm',name])

    def test_disk_reserve_and_owned_data_limit_fail_closed(self):
        free=rehearsal.MIN_FREE_DISK_BYTES+1
        with patch.object(rehearsal.shutil,'disk_usage',return_value=SimpleNamespace(free=free)), patch.object(rehearsal,'owned_data_size',return_value=123):
            self.assertEqual(rehearsal.storage_observation(Path('/owned-fixture'))['owned_data_bytes'],123)
        with patch.object(rehearsal.shutil,'disk_usage',return_value=SimpleNamespace(free=free)), patch.object(rehearsal,'owned_data_size',return_value=rehearsal.MAX_REHEARSAL_DATA_BYTES+1):
            with self.assertRaisesRegex(RuntimeError,'owned_data_limit'):
                rehearsal.storage_observation(Path('/owned-fixture'))
        with patch.object(rehearsal.shutil,'disk_usage',return_value=SimpleNamespace(free=1)), patch.object(rehearsal,'owned_data_size',return_value=123):
            with self.assertRaisesRegex(RuntimeError,'disk_reserve'):
                rehearsal.storage_observation(Path('/owned-fixture'))
        # Relation files may disappear during a PostgreSQL checkpoint/drop.
        # Ignore that race, while never following links outside the owned data.
        removed=SimpleNamespace(stat=Mock(side_effect=FileNotFoundError()))
        regular=SimpleNamespace(stat=Mock(return_value=SimpleNamespace(st_size=123,st_mode=stat.S_IFREG)))
        link=SimpleNamespace(stat=Mock(return_value=SimpleNamespace(st_size=8,st_mode=stat.S_IFLNK)))
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(rehearsal.os,'scandir',return_value=nullcontext(iter([removed,regular,link]))):
                self.assertEqual(rehearsal.owned_data_size(Path(directory)),131)
        link.stat.assert_called_once_with(follow_symlinks=False)

    def test_storage_guard_stops_only_the_owned_test_runner(self):
        process=SimpleNamespace(poll=Mock(side_effect=[None,137]),wait=Mock(return_value=137),returncode=137)
        report={}
        with patch.object(rehearsal.subprocess,'Popen',return_value=process), patch.object(rehearsal,'storage_observation',side_effect=RuntimeError('Rehearsal_disk_reserve_reached')), patch.object(rehearsal,'remove_owned_container') as remove:
            result=rehearsal.guarded_test_process(['synthetic-command'],'print(1)',Path('/owned-fixture'),'owned-runner','our-owner',report)
            self.assertEqual(result.returncode,137)
            self.assertEqual(report['resource_guard_reason'],'Rehearsal_disk_reserve_reached')
            remove.assert_called_once_with('owned-runner','our-owner')

    def test_owned_database_diagnostics_preserve_signals_without_environment_or_raw_logs(self):
        owner='a'*32; name='enactspace-recruitment-rehearsal-db-'+owner
        row={'Id':'d'*64,'Name':'/'+name,'Config':{'Labels':{'net.enactspace.rehearsal':owner},'Env':['SMTP_PASSWORD=SECRET-SENTINEL']},
             'State':{'Running':True,'OOMKilled':False,'ExitCode':0},'HostConfig':{'Memory':512*1024**2},'RestartCount':0}
        responses=[SimpleNamespace(returncode=0,stdout='terminated by signal 9; SECRET-SENTINEL',stderr=''),
                   SimpleNamespace(returncode=0,stdout='oom 2\noom_kill 1\nmax 5\nhigh 0\n',stderr='')]
        with patch.object(rehearsal,'run',return_value=json.dumps([row])), patch.object(rehearsal.subprocess,'run',side_effect=responses):
            result=rehearsal.owned_database_diagnostic(name,owner)
            self.assertTrue(result['log_signals']['signal_9'])
            self.assertEqual(result['memory_events']['oom_kill'],1)
            self.assertNotIn('SECRET-SENTINEL',json.dumps(result))
        row['Config']['Labels']['net.enactspace.rehearsal']='other'
        with patch.object(rehearsal,'run',return_value=json.dumps([row])), patch.object(rehearsal.subprocess,'run') as command:
            self.assertFalse(rehearsal.owned_database_diagnostic(name,owner)['available'])
            command.assert_not_called()

    def test_volume_failure_keeps_the_previously_completed_functional_test_counts(self):
        result=SimpleNamespace(testsRun=257,failures=[],errors=[],skipped=[],wasSuccessful=lambda:True)
        output=io.StringIO()
        with patch('unittest.TestSuite',return_value='synthetic-suite'), patch('unittest.TextTestRunner') as runner, \
             patch.dict('sys.modules',{'rehearse_recruitment_volume':SimpleNamespace(run=Mock(side_effect=RuntimeError('synthetic-volume-failure')))}), \
             redirect_stdout(output), redirect_stderr(io.StringIO()):
            runner.return_value.run.return_value=result
            with self.assertRaises(SystemExit) as exit_status:
                exec(rehearsal.TEST_PROGRAM, {})
            self.assertEqual(exit_status.exception.code,1)
        body=json.loads(output.getvalue().strip().splitlines()[-1])
        self.assertEqual(body['tests_run'],257)
        self.assertEqual(body['failures'],0)
        self.assertEqual(body['stage'],'volume_tests')
        self.assertEqual(body['status'],'REHEARSAL_PROGRAM_FAILED')


if __name__ == '__main__':
    unittest.main()
