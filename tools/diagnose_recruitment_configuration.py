"""Read only the boolean checks behind a blocked recruitment preflight."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys
import uuid

HELPER_SHA256 = '50e8d990c6651a8ef4bf101a543118044f6b096ebb47194cb2eaa8daef963353'
CHECKS = frozenset({
    'production', 'debug_disabled', 'auto_create_disabled', 'seed_disabled',
    'email_enabled', 'push_enabled', 'email_redirection_disabled',
    'push_redirection_disabled', 'institutional_sender', 'smtp_password_present',
    'payments_remain_disabled',
})
DETAILS = frozenset({'seed_routes_disabled'})


class DiagnosticError(RuntimeError):
    pass


def require(condition, reason):
    if not condition:
        raise DiagnosticError(reason)


def summarize(raw):
    value = json.loads(raw)
    require(isinstance(value, dict) and set(value) == CHECKS | DETAILS,
            'Unexpected_configuration_probe_fields')
    require(all(type(item) is bool for item in value.values()),
            'Configuration_probe_requires_only_booleans')
    return {'checks': {key: value[key] for key in sorted(CHECKS)},
            'failed_checks': sorted(key for key in CHECKS if value[key] is False),
            'seed_routes_disabled': value['seed_routes_disabled']}


def diagnostic_program(helper):
    needle = ' "seed_disabled": not settings.ENABLE_SEED,'
    require(helper.CONFIG_PROBE.count(needle) == 1, 'Pinned_probe_structure_changed')
    return helper.CONFIG_PROBE.replace(needle, needle +
        '\n "seed_routes_disabled": not settings.seed_routes_enabled,', 1)


def diagnose(operation):
    operation = operation.resolve()
    require(operation.parent == Path('/opt/enactspace/operations') and
            re.fullmatch(r'publish-recruitment-[a-f0-9]{32}', operation.name),
            'Known_operation_directory_required')
    source = operation / 'publish_recruitment_campaign_backend.py'
    require(not source.is_symlink() and
            hashlib.sha256(source.read_bytes()).hexdigest() == HELPER_SHA256,
            'Original_publication_helper_integrity_incorrect')
    previous = json.loads((operation / 'deployment.json').read_text())
    require(previous.get('status') == 'RECRUITMENT_BACKEND_DEPLOYMENT_BLOCKED'
            and previous.get('stage') == 'preflight'
            and previous.get('reason') == 'Production_configuration_incorrect'
            and previous.get('migration_attempted') is False
            and previous.get('deployment_performed') is False,
            'Expected_preflight_failure_receipt_required')
    spec = importlib.util.spec_from_file_location('verified_recruitment_publication', source)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    expected = {'services': {'backend': {'image': helper.IMAGE_ID,
                                        'environment': {'APP_VERSION': helper.VERSION}}}}
    require(json.loads((operation / 'candidate.json').read_text()) == expected,
            'Candidate_override_changed')
    program = diagnostic_program(helper)
    result = subprocess.run(['docker', 'exec', '-i', '-e', 'PYTHONDONTWRITEBYTECODE=1',
                             'enactspace_backend', 'python', '-'], input=program,
                            capture_output=True, text=True, timeout=60, check=False)
    require(result.returncode == 0, 'Current_configuration_probe_failed')
    current = summarize(result.stdout)
    host = helper.Host(operation)
    # Use a different one-off name from the completed deployment attempt.
    host.calls = int(uuid.uuid4().hex[:12], 16)
    candidate = summarize(host.candidate(program))
    return {'status': 'RECRUITMENT_CONFIGURATION_DIAGNOSED',
            'configuration_modified': False, 'production_services_restarted': False,
            'database_accessed': False, 'migration_performed': False,
            'emails_sent': False, 'credentials_printed': False,
            'current_backend': current, 'tested_candidate': candidate,
            'checks_that_differ': sorted(key for key in CHECKS | DETAILS
                if (current['checks'].get(key) if key in CHECKS else current[key]) !=
                   (candidate['checks'].get(key) if key in CHECKS else candidate[key]))}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--operation', type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        report = diagnose(args.operation)
    except Exception as error:
        report = {'status': 'RECRUITMENT_CONFIGURATION_DIAGNOSTIC_BLOCKED',
                  'configuration_modified': False, 'migration_performed': False,
                  'error_type': type(error).__name__, 'details_hidden': True}
        if isinstance(error, DiagnosticError):
            report['reason'] = str(error)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'RECRUITMENT_CONFIGURATION_DIAGNOSED' else 1


if __name__ == '__main__':
    sys.exit(main())
