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
    def test_volume_refuses_production_or_remote_database_urls(self):
        for url in ['postgresql://user@127.0.0.1/enactspace', 'postgresql://user@production/enactspace_pr2b_test_x', 'sqlite://']:
            with self.subTest(url=url), self.assertRaises(RuntimeError):
                guarded_url(url)
        self.assertEqual(guarded_url('postgresql://user@127.0.0.1/enactspace_pr2b_test_owned').host, '127.0.0.1')

    def test_cleanup_refuses_an_unowned_container(self):
        result = SimpleNamespace(returncode=0, stdout=json.dumps([{'Config': {'Labels': {'net.enactspace.rehearsal': 'other'}}}]))
        with patch.object(rehearsal.subprocess, 'run', return_value=result), patch.object(rehearsal, 'run') as mutate:
            with self.assertRaisesRegex(RuntimeError, 'ownership'):
                rehearsal.remove_owned_container('owned-name', 'our-id')
            mutate.assert_not_called()

    def test_cleanup_removes_only_the_matching_owned_name(self):
        result = SimpleNamespace(returncode=0, stdout=json.dumps([{'Config': {'Labels': {'net.enactspace.rehearsal': 'our-id'}}}]))
        with patch.object(rehearsal.subprocess, 'run', return_value=result), patch.object(rehearsal, 'run') as mutate:
            rehearsal.remove_owned_container('owned-name', 'our-id')
            mutate.assert_called_once_with(['docker', 'rm', '-f', '-v', 'owned-name'])

    def test_failed_inspection_cannot_be_reported_as_successful_cleanup(self):
        result = SimpleNamespace(returncode=1, stderr='Docker daemon unavailable')
        with patch.object(rehearsal.subprocess, 'run', return_value=result):
            with self.assertRaisesRegex(RuntimeError, 'Cleanup_inspection_failed'):
                rehearsal.remove_owned_container('owned-name', 'our-id')


if __name__ == '__main__':
    unittest.main()
