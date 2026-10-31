"""Safety and failure reporting for the read-only VPS inventory."""
import ast
from datetime import datetime, timedelta, timezone
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('campaign_audit', Path(__file__).resolve().parents[1] / 'tools/audit_recruitment_campaign.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class ReadinessAuditTests(unittest.TestCase):
    def test_backup_requires_verified_recent_timestamp_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = root / 'prelaunch-lot26-owned' / 'rehearsal.json'
            report.parent.mkdir()
            body = {'finished_at': datetime.now(timezone.utc).isoformat(), 'passed': True,
                    'owned_test_resources_removed': True, 'decrypted_staging_removed': True}
            report.write_text(json.dumps(body))
            self.assertTrue(audit.backup_inventory(root)['verified'])
            self.assertTrue(audit.backup_inventory(root)['fresh_within_26_hours'])
            body['finished_at'] = (datetime.now(timezone.utc) - timedelta(hours=30)).isoformat()
            report.write_text(json.dumps(body))
            self.assertFalse(audit.backup_inventory(root)['fresh_within_26_hours'])
            body['decrypted_staging_removed'] = False
            report.write_text(json.dumps(body))
            self.assertFalse(audit.backup_inventory(root)['verified'])

    def test_missing_backup_is_reported_without_creating_anything(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertFalse(audit.backup_inventory(root)['report_found'])
            self.assertEqual(list(root.iterdir()), [])

    def test_inner_program_has_only_literal_read_only_sql(self):
        tree = ast.parse(audit.CONTAINER_PROBE)
        statements = []
        for node in ast.walk(tree):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == 'text':
                self.assertIsInstance(node.args[0], ast.Constant)
                sql = node.args[0].value.strip()
                self.assertIn(sql.split()[0].upper(), {'SELECT', 'SET', 'SHOW'})
                statements.append(sql)
        self.assertGreater(len(statements), 8)
        self.assertIn('SET TRANSACTION READ ONLY', statements)
        self.assertIn("SET LOCAL statement_timeout = '10s'", statements)

    def inventory(self, *, matching=True, dead=False, read_only=True):
        database = {
            'status': 'READ_ONLY_DATABASE_INVENTORY_COMPLETE',
            'source_sha256': audit.EXPECTED_HARDENING,
            'database_read_only_verified': read_only, 'configuration': {'safe': True},
            'schema': ['20261031_0033'],
            'campaigns': [{'matches_november_dates': matching, 'active': True, 'questions': 12,
                           'required_questions': 7, 'target_headcount': 30}],
            'document_sample': {'missing': 0},
            'recruitment_integrity': {'missing_tracking_codes': 0, 'inconsistent_conversions': 0},
            'authorized_accounts': {'recruiters_ready': 2, 'converters_ready': 1},
            'outbox': [{'status': 'dead' if dead else 'sent', 'count': 1}],
        }
        names = ['backend', 'email_worker', 'push_worker', 'veille_worker', 'web']
        containers = [{
            'Name': '/enactspace_' + name, 'State': {'Running': True, 'Health': {'Status': 'healthy'}},
            'RestartCount': 0, 'Config': {'Labels': {}},
            'Mounts': [{'Destination': '/app/uploads', 'Type': 'bind', 'Source': '/owned-test'}],
        } for name in names]
        commands = []

        def run(args, **kwargs):
            commands.append(args)
            if args[:2] == ['docker', 'inspect']:
                return json.dumps(containers)
            if args[:2] == ['docker', 'exec']:
                return json.dumps(database)
            if args[:2] == ['systemctl', 'show']:
                return 'ActiveState=active\n'
            self.fail('Unapproved command: ' + repr(args))

        with patch.object(audit, 'run', side_effect=run), patch.object(audit, 'backup_inventory', return_value={
            'verified': True, 'fresh_within_26_hours': True}), patch.object(audit.shutil, 'disk_usage', return_value=SimpleNamespace(free=100 * 1024**3)):
            result = audit.audit(500)
        return result, commands

    def test_healthy_inventory_never_claims_a_launch_rehearsal_was_done(self):
        report, commands = self.inventory()
        self.assertEqual(report['blockers'], [])
        self.assertFalse(report['ready_for_launch'])
        self.assertFalse(report['load_test_performed'])
        self.assertFalse(report['database_modified'])
        self.assertTrue(report['unverified'])
        self.assertEqual(len(commands), 3)

    def test_wrong_campaign_and_dead_mail_are_actionable_blockers(self):
        report, _ = self.inventory(matching=False, dead=True)
        self.assertIn('Exactly_one_active_November_4_to_8_campaign_required', report['blockers'])
        self.assertIn('Undelivered_emails_require_review', report['blockers'])

    def test_read_only_mode_must_be_confirmed_by_postgresql(self):
        report, _ = self.inventory(read_only=False)
        self.assertIn('Read_only_transaction_not_verified', report['blockers'])


if __name__ == '__main__':
    unittest.main()
