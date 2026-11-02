"""Exercise scope and rollback with an isolated Compose fixture."""
import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import publish_interface_copy_backend as release

BASE = "sha256:" + "a" * 64
MANIFEST = {"base_image_id": BASE, "base_version": "1.0.21", "source_commit": "patch",
            "schema_head": "20261031_0033", "tests_expected": 114,
            "runtime": {"file": "new"}, "baseline": {"file": "old"}}
ORIGINAL = "name: enactspace\nservices:\n" + "".join(
    f"  {name}:\n    image: {BASE}\n"
    + ('    environment:\n      APP_VERSION: "1.0.21"\n' if name == "backend" else "")
    for name in release.ops.SERVICES
) + "  web:\n    image: nginx\n"


class FakeHost:
    failed_configuration_checks = []

    def __init__(self, directory, fail=None):
        self.directory = directory
        self.config = directory / "compose.yml"
        self.config.write_text(ORIGINAL)
        self.events = []
        self.fail = fail
        self.image = BASE

    def event(self, event):
        self.events.append(event)
        if event == self.fail:
            raise release.ops.ReleaseError("Fixture_failure")

    def verify_image(self, _manifest):
        self.event("verify_image")

    def verify_sources(self, _expected):
        self.event("verify_sources")

    def healthy(self, version, image):
        self.event("healthy:" + version)
        assert image == self.image

    def configuration(self):
        self.event("configuration")

    def verify_schema(self, _expected):
        self.event("verify_schema")

    def timeline(self):
        self.event("timeline")

    def verify_plan(self, _updated, _manifest):
        self.event("verify_plan")

    def verified_backup(self):
        self.event("backup")
        return "fixture-backup"

    def replace(self, expected, replacement):
        self.event("replace")
        assert self.config.read_text() == expected
        self.config.write_text(replacement)
        if self.fail == "signal_after_replace" and replacement != ORIGINAL:
            raise KeyboardInterrupt

    def compose(self, *args):
        self.event("compose:" + args[0])
        if args[0] == "up":
            assert args == release.RECREATE
            self.image = BASE if self.config.read_text() == ORIGINAL else release.IMAGE


class ReleaseTests(unittest.TestCase):
    def invoke_release(self, fail=None, execute=True):
        with tempfile.TemporaryDirectory() as temporary:
            host = FakeHost(Path(temporary), fail)
            with patch.object(release.ops, "BASE", host.config), patch("builtins.print"):
                report = release.perform_release(host, ORIGINAL, MANIFEST, execute)
                content = host.config.read_text()
                backup = (host.directory / "compose.previous.yml").exists()
                return host, report, content, backup

    def test_preflight_only(self):
        host, report, content, backup = self.invoke_release(execute=False)
        self.assertEqual(report["status"], "INTERFACE_COPY_BACKEND_PREFLIGHT_PASSED")
        self.assertEqual(content, ORIGINAL)
        self.assertFalse(backup)
        self.assertNotIn("backup", host.events)

    def test_verified_backup_precedes_switch_and_post_checks(self):
        host, report, content, backup = self.invoke_release()
        self.assertEqual(report["status"], "INTERFACE_COPY_BACKEND_DEPLOYED")
        self.assertTrue(report["deployment_performed"])
        self.assertFalse(report["migration_performed"])
        self.assertTrue(backup)
        self.assertEqual(content.count(release.IMAGE), 4)
        self.assertLess(host.events.index("backup"), host.events.index("replace"))
        self.assertLess(host.events.index("compose:up"), host.events.index("healthy:1.0.22"))

    def test_failed_backup_never_switches(self):
        host, report, content, _ = self.invoke_release(fail="backup")
        self.assertFalse(report["deployment_performed"])
        self.assertEqual(content, ORIGINAL)
        self.assertNotIn("compose:up", host.events)

    def test_recreate_following_failed_health_or_interrupted_write(self):
        for failure in ("healthy:1.0.22", "signal_after_replace"):
            with self.subTest(failure=failure):
                host, report, content, _ = self.invoke_release(fail=failure)
                self.assertFalse(report["deployment_performed"])
                self.assertTrue(report["previous_services_restored"])
                self.assertEqual(content, ORIGINAL)
                self.assertEqual(host.image, BASE)

    def test_existing_target_does_not_restart_services(self):
        with tempfile.TemporaryDirectory() as temporary:
            host = FakeHost(Path(temporary))
            host.image = release.IMAGE
            target = release.updated_compose(ORIGINAL, MANIFEST)
            host.config.write_text(target)
            report = release.perform_release(host, target, MANIFEST, True)
            self.assertEqual(report["status"], "INTERFACE_COPY_BACKEND_ALREADY_DEPLOYED")
            self.assertNotIn("compose:up", host.events)
            self.assertNotIn("backup", host.events)

    def test_resolved_plan_preserves_settings_and_other_services(self):
        before = {"services": {name: {"image": BASE, "environment": {"KEEP": "1"}}
                               for name in release.ops.SERVICES}}
        before["services"]["backend"]["environment"]["APP_VERSION"] = "1.0.21"
        before["services"]["web"] = {"image": "nginx"}
        after = copy.deepcopy(before)
        for name in release.ops.SERVICES:
            after["services"][name]["image"] = release.IMAGE
        after["services"]["backend"]["environment"]["APP_VERSION"] = "1.0.22"
        release.validate_plan(before, after, MANIFEST)
        after["services"]["email-worker"]["environment"]["KEEP"] = "0"
        with self.assertRaisesRegex(release.ops.ReleaseError, "Unexpected_resolved_configuration_change"):
            release.validate_plan(before, after, MANIFEST)

    def test_receipt_rejects_another_image_or_skipped_tests(self):
        receipt = {"status": "INTERFACE_COPY_BACKEND_CANDIDATE_VERIFIED",
                   "operation_id": release.REHEARSAL, "deployment_performed": False,
                   "candidate_image": "enactspace-backend:interface-copy-" + release.REHEARSAL[:12],
                   "candidate_image_id": release.IMAGE, "base_image_id": BASE,
                   "source_commit": MANIFEST["source_commit"], "tests_run": 114,
                   "failures": 0, "errors": 0, "skipped": 0,
                   "candidate_schema_head": MANIFEST["schema_head"]}
        release.validate_rehearsal(json.loads(json.dumps(receipt)), MANIFEST)
        for field in ("candidate_image_id", "candidate_schema_head", "skipped"):
            with self.subTest(field=field), self.assertRaises(release.ops.ReleaseError):
                release.validate_rehearsal({**receipt, field: 1}, MANIFEST)


if __name__ == "__main__":
    unittest.main()
