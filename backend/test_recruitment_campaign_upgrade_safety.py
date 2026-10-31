"""Rehearsal allowlist and integrity checks without Docker or a real database."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
from unittest import TestCase

path = Path(__file__).resolve().parents[1] / 'tools/rehearse_recruitment_campaign_v2.py'
spec = importlib.util.spec_from_file_location('campaign_v2_safety', path)
runner = importlib.util.module_from_spec(spec); spec.loader.exec_module(runner)


class CampaignUpgradeSafetyTests(TestCase):
    def package(self, directory):
        files = {}
        for name in runner.ALLOWED_FILES:
            path = directory / 'payload' / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('synthetic-owned-fixture\n')
            files[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        manifest = {'schema': 2, 'base_revision': runner.BASE_REVISION,
                    'base_hashes': runner.BASE_HASHES, 'patch_revision': 'a' * 40, 'files': files}
        (directory / 'manifest.json').write_text(json.dumps(manifest))
        return manifest

    def test_valid_scoped_package_includes_migration_and_every_access_boundary(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); self.package(root)
            body = runner.validate_payload(root)
            for name in ('backend/app/api/deps.py', 'backend/app/api/routes/files.py',
                         'backend/app/models/recruitment.py', 'backend/alembic/versions/20261031_0032_recruitment_jury_personality.py'):
                self.assertIn(name, body['files'])

    def test_extra_payload_and_modified_file_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); body = self.package(root)
            body['files']['../not-owned.py'] = '0' * 64
            (root / 'manifest.json').write_text(json.dumps(body))
            with self.assertRaisesRegex(RuntimeError, 'scope'):
                runner.validate_payload(root)
            self.package(root)
            (root / 'payload/backend/app/api/deps.py').write_text('changed')
            with self.assertRaisesRegex(RuntimeError, 'integrity'):
                runner.validate_payload(root)

    def test_pinned_helper_is_non_root_and_all_postgresql_suites_are_requested(self):
        helper = runner.configure(runner.load_helper())
        self.assertIn('RecruitmentJuryRacesPostgreSQLTests', helper.TEST_PROGRAM)
        self.assertIn("['20261031_0033']", helper.TEST_PROGRAM)
        self.assertIn('result.skipped', helper.TEST_PROGRAM)
        source = helper.candidate_dockerfile('owned-base', 'b' * 32,
            {'patch_revision': 'a' * 40, 'files': {'tools/audit_recruitment_campaign.py': 'fixture'}}, 'enactspace')
        self.assertTrue(source.endswith('USER enactspace\n'))
        self.assertIn('chmod 0755 /app/tools', source)
