"""Rehearsal guards; these tests never launch Docker or access a real database."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

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
        with patch.object(rehearsal, 'run', return_value=json.dumps([image])), patch.object(rehearsal, 'remove_owned_container') as remove:
            with self.assertRaisesRegex(RuntimeError, 'image_changed'):
                rehearsal.cleanup_previous(tag, 'sha256:' + 'c' * 64)
            remove.assert_not_called()
            body = rehearsal.cleanup_previous(tag, image['Id'])
            self.assertTrue(body['owned_runtime_resources_removed'])
            self.assertEqual(remove.call_count, 2)
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


if __name__ == '__main__':
    unittest.main()
