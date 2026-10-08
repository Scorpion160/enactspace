"""Windows GnuPG diagnostic with synthetic data only; never read a recovery key."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
from datetime import datetime,timezone
GPG=Path(r'C:\Program Files\Git\usr\bin\gpg.exe')
HELPER_SHA='37fd0532802b3d998eb0c155a6d930f71f459533448846a2dc6ab01f5ec562cb'
PHRASE='synthetic phrase for diagnostic testing only'
PAYLOAD=b'EnactSpace synthetic diagnostic payload, no production key'


def classify(stderr):
    text=stderr.decode('utf-8',errors='replace').lower()
    if 'socket' in text and ('not permitted' in text or 'permission denied' in text):return 'SOCKET_CREATION_DENIED'
    if 'passphrase' in text and ('no such file' in text or 'cannot open' in text or "can't open" in text):return 'PASSPHRASE_FILE_UNAVAILABLE'
    if 'agent' in text and ('failed to start' in text or "can't connect" in text or 'no agent running' in text):return 'AGENT_START_OR_CONNECTION_FAILED'
    if 'invalid option' in text or 'unknown option' in text:return 'UNSUPPORTED_OPTION'
    return 'GPG_OPERATION_FAILED'


def arguments(mode,home,passfile):
    if mode=='windows_absolute':return str(home),str(passfile)
    if mode=='msys_absolute':
        if not home.drive or not passfile.drive:raise ValueError('Windows drive required')
        return '/'+home.drive[0].lower()+home.as_posix()[2:],'/'+passfile.drive[0].lower()+passfile.as_posix()[2:]
    if mode=='relative_workspace':return 'gpg','passphrase'
    raise ValueError('Unknown diagnostic mode')


def attempt(mode,root,private):
    work=root/('work-'+secrets.token_hex(6));work.mkdir(exist_ok=False)
    home=work/'gpg';result={'mode':mode,'roundtrip_passed':False,'temporary_workspace_removed':False}
    environment=os.environ.copy();environment['LC_ALL']='C'
    try:
        private(work);private(home)
        passfile=work/'passphrase';passfile.write_bytes(PHRASE.encode())
        homedir,phrase_file=arguments(mode,home,passfile)
        command=[str(GPG),'--no-options','--homedir',homedir,'--batch','--yes','--no-tty',
                 '--no-symkey-cache','--pinentry-mode','loopback','--passphrase-file',phrase_file,'--output','-']
        encrypted=subprocess.run(command+['--cipher-algo','AES256','--symmetric'],cwd=work,input=PAYLOAD,capture_output=True,env=environment,timeout=45)
        if encrypted.returncode:
            result.update(stage='encrypt',error=classify(encrypted.stderr));return result
        decoded=subprocess.run(command+['--decrypt'],cwd=work,input=encrypted.stdout,capture_output=True,env=environment,timeout=45)
        if decoded.returncode:
            result.update(stage='decrypt',error=classify(decoded.stderr));return result
        result['roundtrip_passed']=decoded.stdout==PAYLOAD
        if not result['roundtrip_passed']:result['error']='SYNTHETIC_PAYLOAD_MISMATCH'
        return result
    except subprocess.TimeoutExpired:
        result.update(error='GPG_TIMEOUT');return result
    finally:
        configuration=GPG.with_name('gpgconf.exe')
        try:
            if configuration.is_file() and home.exists():
                homedir,_=arguments(mode,home,work/'passphrase')
                subprocess.run([str(configuration),'--homedir',homedir,'--kill','all'],cwd=work,capture_output=True,env=environment,timeout=10)
        finally:
            shutil.rmtree(work)
            result['temporary_workspace_removed']=not work.exists()


def execute(repo):
    if os.name!='nt':raise ValueError('Diagnostic prevu sur Windows.')
    helper=repo/'tools/prelaunch_offsite_recovery.py'
    if hashlib.sha256(helper.read_bytes()).hexdigest()!=HELPER_SHA:
        raise ValueError('Source de protection Windows differente du checkpoint : arret.')
    spec=importlib.util.spec_from_file_location('escrow_private_access',helper)
    windows=importlib.util.module_from_spec(spec);spec.loader.exec_module(windows)
    if not GPG.is_file():raise ValueError('GnuPG de Git introuvable.')
    root=Path(os.environ['LOCALAPPDATA'])/'EnactSpace/EscrowDiagnostics'
    windows.private_directory(root)
    results=[attempt(mode,root,windows.private_directory) for mode in ('windows_absolute','msys_absolute','relative_workspace')]
    report={'status':'SYNTHETIC_GPG_DIAGNOSTIC_COMPLETED','attempts':results,
            'production_key_read':False,'dpapi_used':False,'real_key_exported':False,
            'secret_output':False,'build_performed':False,'deployment_performed':False,
            'working_modes':[r['mode'] for r in results if r['roundtrip_passed']],
            'all_temporary_workspaces_removed':all(r['temporary_workspace_removed'] for r in results)}
    target=root/('masked-diagnostic-'+datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S-%f')+'.json')
    with target.open('x',encoding='utf-8') as file:file.write(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--repo',type=Path,required=True)
    args=parser.parse_args()
    try:execute(args.repo)
    except Exception as exc:
        print('ARRET: '+(str(exc) if isinstance(exc,ValueError) else type(exc).__name__)+'. Aucune cle reelle lue.')
        raise SystemExit(1)
