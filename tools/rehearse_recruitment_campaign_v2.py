"""Extended campaign rehearsal; no production migration, mail or activation.

Uses a checksum-pinned isolated runner with an owned disk volume and resource
guards. Older pinned commits retain their original rehearsal implementation.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

BASE_REVISION = "1ccbb0ac2b8220ee8eb19d24a9114790e7bf2b95"
HELPER_SHA256 = "73b13af8cbb7f69b2b42b003fccccf7a7babc0dc1ba22bbe8d10ff699bf07815"
ALLOWED_FILES = frozenset(['backend/alembic/versions/20261031_0032_recruitment_jury_personality.py', 'backend/alembic/versions/20261031_0033_recruitment_jury_teams.py', 'backend/app/api/deps.py', 'backend/app/api/routes/files.py', 'backend/app/api/routes/recruitment.py', 'backend/app/api/routes/recruitment_extensions.py', 'backend/app/models/recruitment.py', 'backend/app/schemas/recruitment.py', 'backend/app/services/email_delivery_service.py', 'backend/app/services/public_request_protection.py', 'backend/app/services/recruitment_access.py', 'backend/app/services/recruitment_emails.py', 'backend/app/services/recruitment_interviews.py', 'backend/app/services/recruitment_personality.py', 'backend/app/services/recruitment_teams.py', 'backend/app/services/request_rate_limit.py', 'backend/rehearse_recruitment_volume.py', 'backend/test_prelaunch_email_lifecycle.py', 'backend/test_prelaunch_first_access.py', 'backend/test_recruitment_campaign_postgresql.py', 'backend/test_recruitment_campaign_readiness.py', 'backend/test_recruitment_campaign_upgrade_safety.py', 'backend/test_recruitment_jury_migration.py', 'backend/test_recruitment_jury_personality.py', 'backend/test_recruitment_jury_postgresql.py', 'backend/test_recruitment_readiness_audit.py', 'backend/test_recruitment_rehearsal_safety.py', 'backend/test_recruitment_teams.py', 'backend/test_recruitment_teams_migration.py', 'tools/audit_recruitment_campaign.py', 'tools/rehearse_recruitment_campaign_v2.py', 'tools/rehearse_recruitment_candidate.py'])
BASE_HASHES = {'app/api/routes/recruitment.py': 'c6861eb6de84e52b14ea66eb767f386a280b4deb1049dd4faac226bd2e76bf04', 'app/schemas/recruitment.py': '678b6239aa38dc3938a91463ecd9f4c50b53d20f0dce58cc89c766ccee36b20e', 'app/services/email_delivery_service.py': '498cb3e68ff2793590a7a7276d690d6a75654679f89d2a4d494c0db77f19003e'}


def load_helper():
    path = Path(__file__).with_name("rehearse_recruitment_candidate.py")
    if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != HELPER_SHA256:
        raise RuntimeError("Rehearsal_helper_integrity_failed")
    spec = importlib.util.spec_from_file_location("pinned_campaign_rehearsal", path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


def validate_payload(directory):
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest.get("schema") != 2 or set(manifest.get("files", {})) != ALLOWED_FILES:
        raise RuntimeError("Unexpected_campaign_payload_scope")
    if manifest.get("base_revision") != BASE_REVISION or manifest.get("base_hashes") != BASE_HASHES:
        raise RuntimeError("Unexpected_campaign_baseline")
    if not re.fullmatch(r"[a-f0-9]{40}", manifest.get("patch_revision", "")):
        raise RuntimeError("Invalid_patch_revision")
    root = directory / "payload"
    for name, expected in manifest["files"].items():
        path = root / name
        if (not re.fullmatch(r"[a-f0-9]{64}", expected)
                or not path.resolve().is_relative_to(root.resolve()) or path.is_symlink()
                or hashlib.sha256(path.read_bytes()).hexdigest() != expected):
            raise RuntimeError("Campaign_payload_integrity_failed")
    return manifest


def configure(helper):
    helper.validate_payload = validate_payload
    extra = [
        'test_recruitment_jury_personality', 'test_recruitment_jury_migration',
        'test_recruitment_teams', 'test_recruitment_teams_migration',
        'test_recruitment_rehearsal_safety', 'test_recruitment_campaign_upgrade_safety',
        'test_recruitment_jury_postgresql.RecruitmentJuryHttpPostgreSQLTests',
        'test_recruitment_jury_postgresql.RecruitmentTeamsHttpPostgreSQLTests',
        'test_recruitment_jury_postgresql.RecruitmentJuryRacesPostgreSQLTests',
    ]
    program = helper.TEST_PROGRAM.replace('    modules = [',
        '    modules = ' + repr(extra) + ' + [', 1)
    needle = "        report['volume'] = run()"
    replacement = """        from alembic.config import Config
        from alembic.script import ScriptDirectory
        heads = ScriptDirectory.from_config(Config('alembic.ini')).get_heads()
        assert heads == ['20261031_0033']
        report['candidate_schema_head'] = heads[0]
        report['volume'] = run()"""
    if needle not in program:
        raise RuntimeError('Pinned_test_program_structure_changed')
    helper.TEST_PROGRAM = program.replace(needle, replacement, 1)
    compile(helper.TEST_PROGRAM, '<isolated-campaign-tests>', 'exec')
    return helper


def main(argv=None):
    try:
        return configure(load_helper()).main(argv)
    except Exception as error:
        print(json.dumps({'status': 'CAMPAIGN_REHEARSAL_PREPARATION_BLOCKED',
            'error_type': type(error).__name__, 'production_services_changed': False,
            'production_migration_performed': False, 'emails_sent': False}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
