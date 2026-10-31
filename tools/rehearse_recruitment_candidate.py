"""Build a scoped candidate and rehearse on owned, offline PostgreSQL resources."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid


TEST_PROGRAM = r'''
import json,sys,traceback
stage='initialization'
try:
    import json, sys, unittest
    modules = [
        'test_recruitment_readiness_audit', 'test_recruitment_campaign_readiness',
        'test_recruitment_questionnaire', 'test_recruitment_preparation', 'test_recruitment_history',
        'test_recruitment_rubric', 'test_attachments_lifecycle', 'test_password_reset_guard',
        'test_prelaunch_email_lifecycle', 'test_prelaunch_first_access', 'test_request_rate_limit',
        'test_recruitment_campaign_postgresql.RecruitmentCampaignPostgreSQLTests',
        'test_recruitment_history_postgresql.RecruitmentHistoryPostgreSQLTests',
        'test_recruitment_rubric_postgresql.RecruitmentRubricPostgreSQLTests',
        'test_request_rate_limit_postgresql.PostgreSQLQuotaTests',
    ]
    for name in ('test_12_concurrent_candidate_conversion_returns_one_user',
                 'test_13_duplicate_campaign_email_application_has_one_row',
                 'test_17_conversion_vs_application_delete_preserves_provenance',
                 'test_18_conversion_vs_campaign_delete_preserves_provenance',
                 'test_19_cross_campaign_case_insensitive_conversion_has_one_user'):
        modules.append('test_operational_integrity_postgresql.OperationalIntegrityPostgreSQLTests.' + name)
    stage = 'test_loading'
    suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromName(name) for name in modules)
    stage = 'functional_tests'
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    report = {'tests_run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
              'skipped': len(result.skipped), 'production_database_access': False, 'emails_sent': False}
    if not result.wasSuccessful() or result.skipped:
        report['status'] = 'REHEARSAL_TESTS_FAILED_OR_SKIPPED'
    else:
        stage = 'volume_tests'
        from rehearse_recruitment_volume import run
        report['volume'] = run()
        report['status'] = 'RECRUITMENT_POSTGRESQL_AND_VOLUME_REHEARSAL_PASSED'
    print(json.dumps(report))
    sys.exit(0 if report['status'] == 'RECRUITMENT_POSTGRESQL_AND_VOLUME_REHEARSAL_PASSED' else 1)
except Exception as error:
    traceback.print_exc()
    print(json.dumps({'status':'REHEARSAL_PROGRAM_FAILED','stage':stage,'error_type':type(error).__name__,'production_database_access':False,'emails_sent':False}))
    sys.exit(1)
'''


def run(args, *, input=None, timeout=120):
    result = subprocess.run(args, input=input, text=True, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Command_failed:' + '_'.join(args[:2]))
    return result.stdout


def validate_payload(directory):
    manifest = json.loads((directory / 'manifest.json').read_text())
    allowed = {
        'backend/app/api/routes/recruitment.py', 'backend/app/schemas/recruitment.py',
        'backend/app/services/email_delivery_service.py', 'backend/test_prelaunch_first_access.py',
        'backend/test_recruitment_campaign_readiness.py', 'backend/test_recruitment_readiness_audit.py',
        'backend/test_recruitment_campaign_postgresql.py', 'backend/rehearse_recruitment_volume.py',
        'tools/audit_recruitment_campaign.py',
    }
    if set(manifest['files']) != allowed:
        raise RuntimeError('Unexpected_payload_scope')
    applications = {name.removeprefix('backend/') for name in allowed if name.startswith('backend/app/')}
    if set(manifest['base_hashes']) != applications:
        raise RuntimeError('Unexpected_baseline_scope')
    if any(not re.fullmatch('[a-f0-9]{40}', manifest[key]) for key in ('base_revision', 'patch_revision')):
        raise RuntimeError('Invalid_source_revision')
    for name, expected in manifest['files'].items():
        path = directory / 'payload' / name
        if not re.fullmatch('[a-f0-9]{64}', expected) or not path.resolve().is_relative_to((directory / 'payload').resolve()) or path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError('Payload_integrity_failed')
    return manifest


def remove_owned_container(name, owner):
    result = subprocess.run(['docker', 'inspect', name], capture_output=True, text=True, timeout=30)
    if result.returncode:
        if 'No such' in result.stderr:
            return
        raise RuntimeError('Cleanup_inspection_failed')
    data = json.loads(result.stdout)[0]
    if (data['Config'].get('Labels') or {}).get('net.enactspace.rehearsal') != owner:
        raise RuntimeError('Cleanup_ownership_mismatch')
    run(['docker', 'rm', '-f', '-v', name])


def cleanup_previous(candidate, expected_image_id):
    if not re.fullmatch(r'enactspace-backend:recruitment-hardening-[a-f0-9]{12}', candidate) or not re.fullmatch(r'sha256:[a-f0-9]{64}', expected_image_id):
        raise RuntimeError('Invalid_previous_candidate_identity')
    image = json.loads(run(['docker', 'image', 'inspect', candidate]))[0]
    if image['Id'] != expected_image_id:
        raise RuntimeError('Previous_candidate_image_changed')
    owner = (image['Config'].get('Labels') or {}).get('net.enactspace.rehearsal', '')
    if not re.fullmatch(r'[a-f0-9]{32}', owner) or not candidate.endswith(owner[:12]):
        raise RuntimeError('Previous_candidate_ownership_unverified')
    names = ['enactspace-recruitment-rehearsal-' + kind + '-' + owner for kind in ('test', 'db')]
    for name in names:
        remove_owned_container(name, owner)
    return {'status': 'PREVIOUS_OWNED_RUNTIME_CLEANED', 'operation_id': owner,
            'production_services_changed': False, 'production_database_access': False,
            'owned_runtime_resources_removed': True, 'candidate_and_base_images_retained': True}


def candidate_dockerfile(base_tag, owner, manifest, original_user):
    if not re.fullmatch(r'[a-zA-Z0-9_.:-]+', original_user) or original_user in {'0', 'root', '0:0', 'root:root'}:
        raise RuntimeError('Non_root_base_user_required')
    lines = ['FROM ' + base_tag, 'USER root',
             'LABEL net.enactspace.rehearsal="' + owner + '"',
             'LABEL net.enactspace.patch_revision="' + manifest['patch_revision'] + '"']
    for path in manifest['files']:
        lines.append('COPY --chmod=0644 ' + path + ' /app/' + path)
    # COPY can create a tools directory without traversal rights for the image user.
    lines += ['RUN chmod 0755 /app/tools && chmod 0644 /app/tools/audit_recruitment_campaign.py',
              'USER ' + original_user]
    return '\n'.join(lines) + '\n'


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument('--directory', type=Path)
    action.add_argument('--cleanup-candidate')
    parser.add_argument('--expected-image-id')
    args = parser.parse_args(argv)
    if args.cleanup_candidate:
        try:
            result = cleanup_previous(args.cleanup_candidate, args.expected_image_id or '')
        except Exception as error:
            result = {'status': 'PREVIOUS_CLEANUP_BLOCKED', 'error_type': type(error).__name__,
                      'reason': str(error) if isinstance(error, RuntimeError) else 'Details_hidden',
                      'production_services_changed': False}
        print(json.dumps(result, indent=2))
        return 0 if result['status'] == 'PREVIOUS_OWNED_RUNTIME_CLEANED' else 1
    directory = args.directory.resolve()
    if not re.fullmatch(r'recruitment-rehearsal-[a-f0-9]{32}', directory.name) or directory.parent != Path('/opt/enactspace/staging'):
        parser.error('Owned staging directory required')
    owner = uuid.uuid4().hex
    db_name = 'enactspace-recruitment-rehearsal-db-' + owner
    runner_name = 'enactspace-recruitment-rehearsal-test-' + owner
    base_tag = 'enactspace-backend:rehearsal-base-' + owner
    candidate = 'enactspace-backend:recruitment-hardening-' + owner[:12]
    stage = 'payload_integrity'
    db_owned = runner_owned = base_tag_created = False
    report = {'production_database_access': False, 'production_services_changed': False,
              'production_migration_performed': False, 'emails_sent': False, 'campaign_created': False,
              'deployment_performed': False, 'public_load_test_performed': False,
              'operation_id': owner, 'runtime_containers': [runner_name, db_name]}
    try:
        manifest = validate_payload(directory)
        stage = 'baseline_verification'
        inspected = json.loads(run(['docker', 'inspect', 'enactspace_backend', 'enactspace_postgres']))
        backend, postgres = inspected
        if not backend['State']['Running'] or not postgres['State']['Running']:
            raise RuntimeError('Production_baseline_not_running')
        if (backend['Config'].get('Labels') or {}).get('org.opencontainers.image.revision') != manifest['base_revision']:
            raise RuntimeError('Unexpected_production_base_revision')
        probe = 'import hashlib,json\nfrom pathlib import Path\nprint(json.dumps({p:hashlib.sha256((Path("/app/backend")/p).read_bytes()).hexdigest() for p in ' + repr(list(manifest['base_hashes'])) + '}))'
        actual = json.loads(run(['docker', 'exec', '-i', '-e', 'PYTHONDONTWRITEBYTECODE=1',
                                 'enactspace_backend', 'python', '-'], input=probe))
        if actual != manifest['base_hashes']:
            raise RuntimeError('Production_source_changed_since_audit')
        available = next(int(line.split()[1]) * 1024 for line in Path('/proc/meminfo').read_text().splitlines() if line.startswith('MemAvailable:'))
        if available < 2 * 1024**3:
            raise RuntimeError('At_least_2_GiB_available_memory_required')
        report['base_image_id'] = backend['Image']
        run(['docker', 'image', 'tag', backend['Image'], base_tag])
        base_tag_created = True
        original_user = backend['Config'].get('User') or 'root'
        dockerfile = candidate_dockerfile(base_tag, owner, manifest, original_user)
        context = directory / 'payload'
        (context / 'Dockerfile').write_text(dockerfile)
        stage = 'candidate_image_build'
        print('RECRUITMENT_CANDIDATE_IMAGE_BUILD', flush=True)
        run(['docker', 'build', '--pull=false', '--network=none', '-t', candidate, str(context)], timeout=300)
        report['candidate_image'] = candidate
        report['candidate_image_id'] = json.loads(run(['docker', 'image', 'inspect', candidate]))[0]['Id']
        stage = 'non_root_payload_readability'
        readability = ('import os,json\nfrom pathlib import Path\n'
                       'assert os.geteuid() != 0\n'
                       'paths=' + repr(['/app/' + path for path in manifest['files']]) + '\n'
                       'for p in paths: Path(p).read_bytes()\n'
                       'print(json.dumps({"uid":os.geteuid(),"readable_files":len(paths)}))')
        report['payload_readability'] = json.loads(run(['docker', 'run', '--rm', '-i', '--network=none',
            '--read-only', '--entrypoint', 'python', candidate, '-'], input=readability))
        stage = 'isolated_postgresql'
        database = 'enactspace_pr2b_test_recruitment_' + owner[:12]
        db_owned = True
        run(['docker', 'run', '-d', '--name', db_name, '--label', 'net.enactspace.rehearsal=' + owner,
             '--network=none', '--memory=512m', '--cpus=0.5', '--pids-limit=128', '--read-only',
             '--tmpfs', '/var/lib/postgresql/data:rw,size=768m', '--tmpfs', '/var/run/postgresql:rw,mode=1777',
             '--tmpfs', '/tmp:rw,size=32m,mode=1777',
             '-e', 'POSTGRES_PASSWORD=isolated-rehearsal-only-not-production', '-e', 'POSTGRES_DB=' + database,
             postgres['Image']])
        for attempt in range(40):
            ready = subprocess.run(['docker', 'exec', db_name, 'pg_isready', '-U', 'postgres', '-d', database],
                                   capture_output=True, timeout=5)
            if ready.returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('Isolated_PostgreSQL_not_ready')
        isolated = json.loads(run(['docker', 'inspect', db_name]))[0]
        if isolated['HostConfig']['NetworkMode'] != 'none' or isolated['HostConfig'].get('PortBindings'):
            raise RuntimeError('PostgreSQL_network_isolation_failed')
        url = 'postgresql+psycopg://postgres:isolated-rehearsal-only-not-production@127.0.0.1:5432/' + database
        environment = {
            'APP_ENV': 'test', 'APP_DEBUG': 'false', 'DATABASE_URL': 'sqlite://',
            'SECRET_KEY': 'isolated-recruitment-rehearsal-secret-not-production',
            'JWT_SECRET_KEY': '', 'EMAIL_ENABLED': 'false', 'PUSH_ENABLED': 'false',
            'SMTP_HOST': 'smtp.invalid', 'SMTP_PASSWORD': '', 'MOBILE_MONEY_ENABLED': 'false',
            'AUTO_CREATE_TABLES': 'false', 'ENABLE_SEED': 'false', 'FILE_STORAGE_PATH': '/app/uploads',
            'PYTHONDONTWRITEBYTECODE': '1', 'TEST_DATABASE_URL': url, 'VEILLE_TEST_POSTGRESQL_URL': url,
            'GOOGLE_APPLICATION_CREDENTIALS': '/nonexistent-isolated-rehearsal',
        }
        command = ['docker', 'run', '--rm', '-i', '--name', runner_name,
                   '--label', 'net.enactspace.rehearsal=' + owner, '--network', 'container:' + db_name,
                   '--memory=1g', '--cpus=0.5', '--pids-limit=256', '--read-only',
                   '--tmpfs', '/tmp:rw,size=384m,mode=1777', '--tmpfs', '/app/uploads:rw,size=64m,mode=1777',
                   '--workdir', '/app/backend']
        for key, value in environment.items():
            command.extend(['-e', key + '=' + value])
        command.extend(['--entrypoint', 'python', candidate, '-'])
        stage = 'isolated_tests_and_volume'
        print('SQLITE_POSTGRESQL_AND_500_1000_DOSSIERS_REHEARSAL', flush=True)
        runner_owned = True
        outcome = subprocess.run(command, input=TEST_PROGRAM, text=True, capture_output=True, timeout=1200)
        if outcome.stderr:
            print(outcome.stderr, end='', file=sys.stderr)
        lines = outcome.stdout.strip().splitlines()
        if not lines:
            raise RuntimeError('Rehearsal_report_missing')
        result = json.loads(lines[-1])
        report['rehearsal'] = result
        if outcome.returncode != 0 or result.get('status') != 'RECRUITMENT_POSTGRESQL_AND_VOLUME_REHEARSAL_PASSED':
            raise RuntimeError('Candidate_rehearsal_failed')
        report['status'] = 'RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED'
    except Exception as error:
        report.update(status='RECRUITMENT_REHEARSAL_BLOCKED', stage=stage, error_type=type(error).__name__)
        if isinstance(error, RuntimeError):
            report['reason'] = str(error)
    finally:
        clean = True
        cleanup_errors = []
        for name, owned in [(runner_name, runner_owned), (db_name, db_owned)]:
            if owned:
                try:
                    remove_owned_container(name, owner)
                except Exception as error:
                    clean = False
                    cleanup_errors.append({'resource': name, 'error_type': type(error).__name__})
        if base_tag_created:
            try:
                run(['docker', 'image', 'rm', base_tag])
            except Exception:
                # The base image is also used by production; never force its removal.
                report['temporary_base_alias_retained'] = base_tag
        report['owned_runtime_resources_removed'] = clean
        report['cleanup_errors'] = cleanup_errors
        if not clean:
            report['status'] = 'RECRUITMENT_REHEARSAL_BLOCKED'
            report['cleanup_requires_review'] = True
    receipt = directory / 'rehearsal.json'
    receipt.write_text(json.dumps(report, indent=2))
    receipt.chmod(0o600)
    print(json.dumps(report, indent=2))
    return 0 if report['status'] == 'RECRUITMENT_CANDIDATE_REHEARSED_NOT_DEPLOYED' else 1


if __name__ == '__main__':
    sys.exit(main())
