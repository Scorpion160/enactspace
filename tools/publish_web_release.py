"""Publish an already built web bundle on the existing VPS, with rollback."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import time
import urllib.request
import uuid

MAIN_SHA = 'caa61e7b9de71b5fbe1e7282ca391a58082744f14370615dc3d265e102e79235'
REQUIRED = ('index.html','main.dart.js','flutter_bootstrap.js','firebase-messaging-sw.js','version.json')

def sha(path):
    digest=hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''):digest.update(block)
    return digest.hexdigest()

def extract_bundle(archive,target):
    with tarfile.open(archive,'r:gz') as tar:
        members=tar.getmembers()
        seen=set();total=0
        for member in members:
            path=PurePosixPath(member.name)
            if path.is_absolute() or '..' in path.parts or not (member.isfile() or member.isdir()):
                raise RuntimeError('Unsafe_archive_member')
            name=str(path)
            if name in seen:raise RuntimeError('Duplicate_archive_member')
            seen.add(name);total+=member.size
            if total>1024*1024*1024:raise RuntimeError('Archive_too_large')
        for member in members:
            path=target.joinpath(*PurePosixPath(member.name).parts)
            if member.isdir():
                path.mkdir(parents=True,exist_ok=True);path.chmod(0o755)
            else:
                path.parent.mkdir(parents=True,exist_ok=True)
                with tar.extractfile(member) as source,path.open('xb') as dest:
                    import shutil
                    shutil.copyfileobj(source,dest)
                path.chmod(0o644)
    for name in REQUIRED:
        if not (target/name).is_file():raise RuntimeError('Missing_bundle_file_'+name.replace('.','_'))
    if sha(target/'main.dart.js')!=MAIN_SHA:raise RuntimeError('Unexpected_main_bundle')
    version=json.loads((target/'version.json').read_text())
    if version.get('version')!='1.0.11' or str(version.get('build_number'))!='14':
        raise RuntimeError('Unexpected_web_version')
    worker=(target/'firebase-messaging-sw.js').read_text()
    if 'firebase.initializeApp' not in worker or 'firebase.messaging' not in worker:
        raise RuntimeError('Firebase_worker_missing_initialization')
    return version

def run(args):
    result=subprocess.run(args,capture_output=True,text=True,timeout=120)
    if result.returncode:raise RuntimeError('Deployment_command_failed')
    return result.stdout

def fetch(path):
    request=urllib.request.Request('http://127.0.0.1:18080'+path,headers={'Cache-Control':'no-cache'})
    with urllib.request.urlopen(request,timeout=10) as response:
        return response.read(),dict(response.headers)

def check_live(candidate):
    for attempt in range(15):
        try:
            checks=[]
            for name in REQUIRED:
                payload,headers=fetch('/'+name)
                if hashlib.sha256(payload).hexdigest()!=sha(candidate/name):
                    raise RuntimeError('Served_file_mismatch')
                checks.append(name)
            for route in ('/academy','/archives','/recruitment/apply','/application-tracking'):
                payload,_=fetch(route)
                if hashlib.sha256(payload).hexdigest()!=sha(candidate/'index.html'):
                    raise RuntimeError('Spa_route_mismatch')
                checks.append(route)
            return checks
        except Exception:
            if attempt==14:raise RuntimeError('Live_web_checks_failed') from None
            time.sleep(2)

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive',required=True,type=Path)
    parser.add_argument('--archive-sha256',required=True)
    parser.add_argument('--execute',action='store_true')
    args=parser.parse_args(argv)
    report={'web_deployed':False,'backend_changed':False,'mail_routing_changed':False}
    switched=False;previous=None;failed=None;stage=None;compose=None;live=Path('/opt/enactspace/web')
    try:
        if args.archive.is_symlink() or sha(args.archive)!=args.archive_sha256.lower():
            raise RuntimeError('Archive_integrity_failed')
        container=json.loads(run(['docker','inspect','enactspace_web']))[0]
        mounts=[m for m in container['Mounts'] if m['Destination']=='/usr/share/nginx/html']
        if len(mounts)!=1 or mounts[0]['Type']!='bind' or mounts[0]['Source']!=str(live):
            raise RuntimeError('Unexpected_live_web_mount')
        if not live.is_dir() or live.is_symlink():raise RuntimeError('Live_web_directory_not_supported')
        labels=container['Config'].get('Labels') or {}
        if labels.get('com.docker.compose.project')!='enactspace' or labels.get('com.docker.compose.service')!='web':
            raise RuntimeError('Unexpected_compose_identity')
        file=labels.get('com.docker.compose.project.config_files')
        if file!='/opt/enactspace/app/deploy/docker-compose.vps.yml':
            raise RuntimeError('Unexpected_compose_file')
        compose=['docker','compose','-p','enactspace','-f',file,'up','-d','--no-deps','--force-recreate','web']
        releases=Path('/opt/enactspace/releases');releases.mkdir(exist_ok=True)
        identity=uuid.uuid4().hex
        stage=releases/('web-candidate-'+identity);stage.mkdir(mode=0o755)
        version=extract_bundle(args.archive,stage)
        report.update(status='WEB_PUBLICATION_PREPARED',version=version,main_sha256=MAIN_SHA)
        if not args.execute:
            report['candidate_directory']=str(stage)
            print(json.dumps(report,indent=2));return 0
        lock=Path('/opt/enactspace/operations/web-publication.lock')
        lock.parent.mkdir(exist_ok=True)
        handle=lock.open('a')
        os.chmod(lock,0o600);fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        previous=releases/('web-previous-'+identity)
        live.rename(previous)
        try:
            stage.rename(live);switched=True
        except Exception:
            previous.rename(live);raise
        run(compose)
        # Bundle now served through the actual web container mount.
        checks=check_live(live)
        report.update(status='WEB_DEPLOYED_LOCAL_CHECKS_PASSED',web_deployed=True,
                      checks=checks,rollback_directory=str(previous),public_https_checked=False)
        (releases/('web-publication-'+identity+'.json')).write_text(json.dumps(report,indent=2))
        print(json.dumps(report,indent=2));return 0
    except Exception as exc:
        if switched and previous and previous.exists():
            try:
                failed=live.parent/('web-failed-'+uuid.uuid4().hex)
                live.rename(failed);previous.rename(live)
                run(compose);check_live(live)
                report['rollback_completed']=True
            except Exception:
                report['rollback_completed']=False
        reason=str(exc) if isinstance(exc,RuntimeError) else type(exc).__name__
        report.update(status='WEB_PUBLICATION_FAILED',reason=reason)
        print(json.dumps(report,indent=2));return 1

if __name__=='__main__':raise SystemExit(main())
