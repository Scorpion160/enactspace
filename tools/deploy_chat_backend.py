import argparse, fcntl, hashlib, json, os, subprocess, sys, time, uuid, urllib.request
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--directory', required=True)
parser.add_argument('--commit', required=True)
parser.add_argument('--execute', action='store_true')
args = parser.parse_args()
directory = Path(args.directory)
base = Path('/opt/enactspace/app/deploy/docker-compose.vps.yml')
old_image = 'enactspace-backend:release-43c3c07'
new_image = 'enactspace-backend:chat-' + args.commit[:7]
services = ['backend', 'email-worker', 'push-worker', 'veille-worker']
names = ['enactspace_backend', 'enactspace_email_worker', 'enactspace_push_worker', 'enactspace_veille_worker']
stage = 'integrity'
original = None
paused = switched = False
old = None
report = {'database_migration_performed': False, 'mail_routing_changed': False, 'web_changed': False}
def run(command, timeout=180, input=None):
    result = subprocess.run(command, input=input, capture_output=True, text=True, timeout=timeout)
    if stage == 'candidate_tests':
        print(result.stdout + result.stderr, end='', flush=True)
    if result.returncode: raise RuntimeError('Command_failed_at_' + stage)
    return result.stdout
def compose(*command):
    return run(['docker', 'compose', '-p', 'enactspace', '-f', str(base), *command])
def write_compose(content):
    stat = base.stat(); temp = base.with_name(base.name + '.' + uuid.uuid4().hex)
    temp.write_text(content); os.chmod(temp, stat.st_mode & 0o777); os.chown(temp, stat.st_uid, stat.st_gid); temp.replace(base)
def healthy(image_id):
    for _ in range(40):
        try:
            with urllib.request.urlopen('http://127.0.0.1:18002/health', timeout=3) as response: health = json.load(response)
            containers = json.loads(run(['docker', 'inspect', *names]))
            if health.get('ok') is True and health.get('version') == '1.0.15' and all(
                c['State']['Running'] and c['Image'] == image_id and (c['State'].get('Health') or {}).get('Status', 'healthy') == 'healthy' for c in containers): return
        except Exception: pass
        time.sleep(2)
    raise RuntimeError('Health_check_failed')
probe = '''
import json
from sqlalchemy import text, or_
from app.core.config import settings
from app.db.database import SessionLocal
from app.api.routes.chat import ChatMessage, MEDIA_MESSAGE_TYPES, router
from app.main import app
assert not settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT
assert settings.email_enabled and settings.push_enabled
assert not settings.MOBILE_MONEY_ENABLED
assert (settings.SMTP_USERNAME or '').lower() == 'enactus@esp.sn'
assert any(route.path.endswith('/{thread_id}/shared') for route in router.routes)
db = SessionLocal()
try:
    db.execute(text('SET TRANSACTION READ ONLY'))
    db.execute(text("SET LOCAL statement_timeout = '15s'"))
    assert db.execute(text('SELECT version_num FROM alembic_version')).scalars().all() == ['20261007_0031']
    db.query(ChatMessage).filter(ChatMessage.deleted_at.is_(None),
        or_(ChatMessage.message_type.in_(MEDIA_MESSAGE_TYPES), ChatMessage.content.ilike('%https://%'))).limit(1).all()
finally:
    db.rollback(); db.close()
print(json.dumps({'candidate_preflight_passed': True, 'shared_query_actual_database_passed': True}))
'''
with open('/opt/enactspace/operations/backend-publication.lock', 'a') as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        manifest = json.loads((directory/'manifest.json').read_text())
        for filename, digest in manifest.items():
            if Path(filename).name != filename: raise RuntimeError('Unsafe_filename')
            if hashlib.sha256((directory/filename).read_bytes()).hexdigest() != digest: raise RuntimeError('Integrity_failed')
        original = base.read_text()
        if original.count('image: ' + old_image) != 4: raise RuntimeError('Unexpected_current_images')
        old = json.loads(run(['docker', 'image', 'inspect', old_image]))[0]
        healthy(old['Id'])
        backup = directory/'compose.previous.yml'; backup.write_text(original); backup.chmod(0o600)
        (directory/'Dockerfile').write_text('FROM ' + old_image + '\n'
            'COPY --chown=10001:10001 chat.py /app/backend/app/api/routes/chat.py\n'
            'COPY --chown=10001:10001 email_delivery_service.py /app/backend/app/services/email_delivery_service.py\n')
        stage = 'candidate_build'
        run(['docker', 'build', '--pull=false', '--network=none', '--label', 'org.opencontainers.image.revision='+args.commit, '-t', new_image, str(directory)], timeout=300)
        stage = 'candidate_tests'
        run(['docker', 'run', '--rm', '--network=none', '--user=0:0', '-v', str(directory)+':/app/backend/tests:ro', '--entrypoint', 'python', new_image,
             '-m', 'unittest', 'discover', '-s', '/app/backend/tests', '-p', 'test_chat_*.py', '-v'])
        override = directory/'candidate.json'; override.write_text(json.dumps({'services': {'backend': {'image': new_image}}}))
        stage = 'candidate_preflight'
        run(['docker', 'compose', '-p', 'enactspace', '-f', str(base), '-f', str(override), 'run', '--rm', '-T', '--no-deps', '--entrypoint', 'python', 'backend', '-'], input=probe)
        print('CHAT_CANDIDATE_TESTS_ET_REQUETE_BDD_OK', flush=True)
        if not args.execute:
            report.update(status='CHAT_BACKEND_PREPARED', deployment_performed=False)
        else:
            stage = 'verified_backup'
            paused = True; compose('stop', *services)
            started = time.time()
            run(['systemctl', 'start', 'enactspace-verified-backup.service'], timeout=900)
            state = dict(line.split('=',1) for line in run(['systemctl','show','enactspace-verified-backup.service','-p','Result','-p','ExecMainStatus']).splitlines() if '=' in line)
            if state.get('Result') != 'success' or state.get('ExecMainStatus') != '0': raise RuntimeError('Backup_service_failed')
            receipts = sorted(Path('/var/backups/enactspace').glob('prelaunch-lot26-*/rehearsal.json'), key=lambda p:p.stat().st_mtime, reverse=True)
            if not receipts or receipts[0].stat().st_mtime < started: raise RuntimeError('Fresh_backup_missing')
            receipt = json.loads(receipts[0].read_text())
            if not all(receipt.get(k) is True for k in ('passed','owned_test_resources_removed','decrypted_staging_removed')): raise RuntimeError('Backup_not_verified')
            report['backup_id'] = receipt.get('backup_id')
            stage = 'switch'
            if base.read_text() != original: raise RuntimeError('Compose_changed')
            write_compose(original.replace('image: '+old_image, 'image: '+new_image)); switched=True
            compose('up','-d','--no-deps','--no-build','--pull','never','--force-recreate',*services)
            stage = 'health'
            candidate = json.loads(run(['docker','image','inspect',new_image]))[0]
            healthy(candidate['Id'])
            report.update(status='CHAT_BACKEND_DEPLOYED', deployment_performed=True, image=new_image,
                          version='1.0.15', rollback_configuration=str(backup), shared_content_enabled=True)
        (directory/'result.json').write_text(json.dumps(report,indent=2))
    except Exception as error:
        report.update(status='CHAT_BACKEND_BLOCKED', stage=stage, error_type=type(error).__name__)
        if isinstance(error,RuntimeError): report['reason']=str(error)
        if paused and original is not None:
            try:
                if switched:
                    write_compose(original); compose('up','-d','--no-deps','--no-build','--pull','never','--force-recreate',*services)
                else: compose('start',*services)
                healthy(old['Id']); report['previous_services_restored']=True
            except Exception: report['previous_services_restored']=False
print(json.dumps(report,indent=2))
sys.exit(0 if report['status'] in ('CHAT_BACKEND_DEPLOYED','CHAT_BACKEND_PREPARED') else 1)
