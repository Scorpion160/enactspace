"""Ensure diagnostics expose only allowlisted booleans and preserve the guard."""
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('configuration_diagnostic', Path(__file__).with_name('diagnose_recruitment_configuration.py'))
diagnostic = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diagnostic)


class ConfigurationDiagnosticTests(unittest.TestCase):
    def good(self):
        return dict.fromkeys(diagnostic.CHECKS | diagnostic.DETAILS, True)

    def test_failed_flags_are_identified_without_changing_the_guard(self):
        data = self.good(); data['push_enabled'] = False
        result = diagnostic.summarize(json.dumps(data))
        self.assertEqual(result['failed_checks'], ['push_enabled'])
        self.assertIs(result['checks']['push_enabled'], False)

    def test_seed_flag_and_effective_route_are_distinguished(self):
        data = self.good(); data['seed_disabled'] = False
        result = diagnostic.summarize(json.dumps(data))
        self.assertEqual(result['failed_checks'], ['seed_disabled'])
        self.assertTrue(result['seed_routes_disabled'])

    def test_raw_credentials_and_unknown_fields_are_rejected(self):
        data = self.good(); data['SMTP_PASSWORD'] = 'sensitive-fixture'
        with self.assertRaisesRegex(diagnostic.DiagnosticError, 'Unexpected_configuration_probe_fields'):
            diagnostic.summarize(json.dumps(data))

    def test_non_boolean_values_are_never_echoed(self):
        for invalid in ['sensitive-fixture', 1, 0, None, {}]:
            data = self.good(); data['smtp_password_present'] = invalid
            with self.subTest(value=invalid), self.assertRaisesRegex(diagnostic.DiagnosticError, 'only_booleans'):
                diagnostic.summarize(json.dumps(data))

    def test_missing_flags_fail_closed(self):
        data = self.good(); del data['production']
        with self.assertRaises(diagnostic.DiagnosticError): diagnostic.summarize(json.dumps(data))

    def test_probe_adds_only_a_boolean_detail(self):
        source = ' "seed_disabled": not settings.ENABLE_SEED,'
        program = diagnostic.diagnostic_program(SimpleNamespace(CONFIG_PROBE=source))
        self.assertIn(source, program)
        self.assertIn('not settings.seed_routes_enabled', program)
        with self.assertRaises(diagnostic.DiagnosticError):
            diagnostic.diagnostic_program(SimpleNamespace(CONFIG_PROBE='unexpected'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
