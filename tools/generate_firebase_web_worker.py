"""Generate the web FCM worker from deployment configuration, without printing values."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import urlsplit

CONFIG_KEYS = {
    'apiKey': 'ENACTSPACE_FIREBASE_API_KEY_WEB',
    'appId': 'ENACTSPACE_FIREBASE_APP_ID_WEB',
    'messagingSenderId': 'ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID',
    'projectId': 'ENACTSPACE_FIREBASE_PROJECT_ID',
    'authDomain': 'ENACTSPACE_FIREBASE_AUTH_DOMAIN_WEB',
    'storageBucket': 'ENACTSPACE_FIREBASE_STORAGE_BUCKET_WEB',
}
PLACEHOLDER = '__ENACTSPACE_FIREBASE_WEB_CONFIG__'
TOKEN = re.compile(r'''(?P<comment>//[^\n]*|/\*[\s\S]*?\*/)|(?P<string>"(?:\\[\s\S]|[^"\\])*"|'(?:\\[\s\S]|[^'\\])*')|(?P<other>[^/'"]+|.)''')
SDK = r'https://www\.gstatic\.com/firebasejs/(?P<version>\d+\.\d+\.\d+)/firebase-(?P<module>app|messaging)(?P<compat>-compat)?\.js'


def plain_path(path):
    for part in (path, *path.parents):
        if part.is_symlink() or (hasattr(part, 'is_junction') and part.is_junction()):
            raise ValueError('Chemin redirige : arret.')


def validate_config(config):
    if set(config) != set(CONFIG_KEYS) or any(not isinstance(v, str) or not v for v in config.values()):
        raise ValueError('Configuration Firebase web incomplete ou inattendue.')
    project = config['projectId']
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        raise ValueError('Identifiant projet Firebase invalide.')
    if not re.fullmatch(r'AIza[\w-]{35}', config['apiKey']):
        raise ValueError('Format de la cle cliente Firebase inattendu.')
    if not re.fullmatch(r'\d+', config['messagingSenderId']):
        raise ValueError('Identifiant expediteur Firebase invalide.')
    if not re.fullmatch(r'\d+:\d+:web:[a-fA-F0-9]+', config['appId']):
        raise ValueError('Identifiant application web Firebase invalide.')
    if config['appId'].split(':')[1] != config['messagingSenderId']:
        raise ValueError('Application web et expediteur Firebase incoherents.')
    if config['authDomain'] != project + '.firebaseapp.com':
        raise ValueError('Domaine Firebase a examiner avant generation.')
    if config['storageBucket'] not in {project + '.appspot.com', project + '.firebasestorage.app'}:
        raise ValueError('Bucket Firebase a examiner avant generation.')
    return config


def unique_object(pairs):
    data = {}
    for key, value in pairs:
        if key in data: raise ValueError('Propriete Firebase repetee : arret.')
        data[key] = value
    return data


def strip_comments(text):
    return ''.join(' ' if token.lastgroup == 'comment' else token.group() for token in TOKEN.finditer(text))


def parse_existing_worker(text):
    text = strip_comments(text)
    pattern = r'''\s*importScripts\(\s*(["'])(?P<app>https://[^"'\r\n]+)\1\s*\);\s*importScripts\(\s*(["'])(?P<messaging>https://[^"'\r\n]+)\3\s*\);\s*firebase\.initializeApp\(\s*(?P<config>\{[\s\S]*\})\s*\);\s*firebase\.messaging\(\s*\);\s*'''
    match = re.fullmatch(pattern, text)
    if not match:
        raise ValueError('Le worker Firebase contient une structure non examinee : aucune exclusion.')
    app, messaging = match.group('app'), match.group('messaging')
    app_sdk, message_sdk = re.fullmatch(SDK, app), re.fullmatch(SDK, messaging)
    if not app_sdk or not message_sdk or app_sdk['module'] != 'app' or message_sdk['module'] != 'messaging':
        raise ValueError('Source des scripts Firebase inattendue.')
    if app_sdk['version'] != message_sdk['version'] or app_sdk['compat'] != message_sdk['compat']:
        raise ValueError('Versions SDK Firebase incoherentes.')
    try:
        config = json.loads(match.group('config'), object_pairs_hook=unique_object)
    except (json.JSONDecodeError, TypeError):
        raise ValueError('Le bloc Firebase doit etre un objet JSON simple.') from None
    validate_config(config)
    return config, make_template(app, messaging)


def make_template(app_url, messaging_url):
    return ('// Generated with tools/generate_firebase_web_worker.py; do not embed deployment values here.\n'
            + 'importScripts(' + json.dumps(app_url) + ');\n'
            + 'importScripts(' + json.dumps(messaging_url) + ');\n\n'
            + 'firebase.initializeApp(' + PLACEHOLDER + ');\n'
            + 'firebase.messaging();\n')


def render(template, config):
    validate_config(config)
    if template.count(PLACEHOLDER) != 1:
        raise ValueError('Modele Firebase ambigu.')
    result = template.replace(PLACEHOLDER, json.dumps(config, ensure_ascii=True, indent=2))
    parsed, normalized_template = parse_existing_worker(result)
    if parsed != config or normalized_template != template:
        raise ValueError('Le modele contient des instructions non examinees.')
    return result


def load_defines(file, require_release=False):
    plain_path(file)
    try:
        defines = json.loads(file.read_text(encoding='utf-8-sig'))
    except (UnicodeError, json.JSONDecodeError):
        raise ValueError('Fichier de configuration JSON invalide ; valeurs masquees.') from None
    if not isinstance(defines, dict): raise ValueError('La configuration doit etre un objet JSON.')
    if any(name in defines for name in ('private_key', 'private_key_id', 'client_email', 'SECRET_KEY', 'DATABASE_URL', 'SMTP_PASSWORD')):
        raise ValueError('Configuration serveur refusee dans une compilation cliente.')
    if require_release:
        api_url = defines.get('ENACTSPACE_API_URL', '')
        if not isinstance(api_url, str): raise ValueError('URL API HTTPS requise pour le build web.')
        parsed = urlsplit(api_url)
        if parsed.scheme != 'https' or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError('URL API HTTPS requise pour le build web.')
        vapid = defines.get('ENACTSPACE_FIREBASE_VAPID_PUBLIC_KEY', '')
        if not isinstance(vapid, str) or not re.fullmatch(r'[A-Za-z0-9_-]{87}=?', vapid):
            raise ValueError('Cle publique VAPID requise pour les notifications web.')
        decoded = base64.urlsafe_b64decode(vapid + '=' * (-len(vapid) % 4))
        if len(decoded) != 65 or decoded[0] != 4:
            raise ValueError('Format de la cle publique VAPID invalide.')
    return validate_config({key: defines.get(define) for key, define in CONFIG_KEYS.items()})


def generate(repo, defines, require_release=False):
    repo = repo.absolute()
    plain_path(repo)
    template_path = repo/'tools/templates/firebase-messaging-sw.template.js'
    worker = repo/'frontend/web/firebase-messaging-sw.js'
    plain_path(template_path); plain_path(worker)
    config = load_defines(defines, require_release=require_release)
    content = render(template_path.read_text(encoding='utf-8'), config)
    # Same-directory atomic replacement; no partial worker on a failed write.
    descriptor, name = tempfile.mkstemp(prefix='.firebase-worker-', suffix='.tmp', dir=worker.parent)
    temp = Path(name)
    try:
        with os.fdopen(descriptor, 'w', encoding='utf-8', newline='\n') as stream:
            stream.write(content)
        os.replace(temp, worker)
    finally:
        temp.unlink(missing_ok=True)
    return {'status':'FIREBASE_WEB_WORKER_GENERATED', 'values_printed':False, 'restrictions_verified':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo',type=Path,default=Path(__file__).absolute().parents[1])
    parser.add_argument('--defines',type=Path,required=True)
    parser.add_argument('--validate-web-release',action='store_true')
    args=parser.parse_args()
    try: print(json.dumps(generate(args.repo,args.defines,require_release=args.validate_web_release)))
    except Exception as exc:
        print('ARRET: '+(str(exc) if isinstance(exc,ValueError) else type(exc).__name__)+'. Aucune valeur affichee.')
        raise SystemExit(1)
