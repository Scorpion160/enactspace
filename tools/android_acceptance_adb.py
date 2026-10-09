"""Guided Android acceptance. Standard library only; no credentials or raw UI logs saved."""
import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
import unicodedata
import xml.etree.ElementTree as ET

PACKAGE = 'sn.enactusesp.enactspace'

def normalize(value):
    return ''.join(c for c in unicodedata.normalize('NFD', value.casefold()) if not unicodedata.combining(c)).strip()

def candidates(xml, labels):
    root = ET.fromstring(xml)
    wanted = {normalize(x) for x in labels}
    found = {}
    for node in root.iter('node'):
        if node.get('enabled') == 'false' or node.get('password') == 'true':
            continue
        if not any(normalize(node.get(k, '')) in wanted for k in ('text', 'content-desc')):
            continue
        match = re.fullmatch(r'\[(\d+),(\d+)\]\[(\d+),(\d+)\]', node.get('bounds', ''))
        if not match:
            continue
        x1, y1, x2, y2 = map(int, match.groups())
        if x2 > x1 and y2 > y1:
            found[(x1, y1, x2, y2)] = ((x1 + x2) // 2, (y1 + y2) // 2)
    return list(found.values())

def new_app_crashes(before, after):
    # A crash only counts if its block names this package and did not exist initially.
    def blocks(text):
        return [b.strip() for b in re.split(r'(?=--------- beginning|(?m:^.*FATAL EXCEPTION:))', text)
                if PACKAGE in b and re.search(r'FATAL EXCEPTION|Fatal signal|>>> ' + re.escape(PACKAGE), b)]
    old = collections.Counter(hashlib.sha256(b.encode()).hexdigest() for b in blocks(before))
    new = collections.Counter(hashlib.sha256(b.encode()).hexdigest() for b in blocks(after))
    return sum((new - old).values())

class Device:
    def __init__(self, serial):
        self.serial = serial
    def adb(self, *args, timeout=30, allow_missing_process=False):
        result = subprocess.run(['adb', '-s', self.serial, *args], capture_output=True,
                                text=True, encoding='utf-8', errors='replace', timeout=timeout)
        if result.returncode and not (allow_missing_process and result.returncode == 1):
            raise RuntimeError('ADB command failed: ' + ' '.join(args[:2]))
        return result.stdout
    def ui(self):
        remote = '/sdcard/enactspace-acceptance-' + str(time.time_ns()) + '.xml'
        try:
            self.adb('shell', 'uiautomator', 'dump', '--compressed', remote)
            xml = self.adb('shell', 'cat', remote)
            xml = xml[xml.index('<?xml'):] if '<?xml' in xml else xml[xml.index('<hierarchy'):]
            ET.fromstring(xml)
            return xml
        finally:
            self.adb('shell', 'rm', '-f', remote)
    def tap_label(self, labels):
        points = candidates(self.ui(), labels)
        if len(points) != 1:
            return False
        self.adb('shell', 'input', 'tap', str(points[0][0]), str(points[0][1]))
        time.sleep(.8)
        return True
    def navigate(self, labels):
        # No blind coordinates, scrolling, submit buttons or authentication controls.
        if self.tap_label(labels):
            return 'accessible_label'
        if self.tap_label(['Open navigation menu', 'Ouvrir le menu de navigation', 'Ouvrir le menu', 'Menu']):
            if self.tap_label(labels):
                return 'drawer_label'
        return 'manual_required'
    def launch(self):
        component = self.adb('shell', 'cmd', 'package', 'resolve-activity', '--brief', PACKAGE).strip().splitlines()[-1]
        if not re.fullmatch(re.escape(PACKAGE) + r'/[\w.$]+', component):
            raise RuntimeError('Launcher activity not resolved')
        self.adb('shell', 'am', 'start', '-n', component)
        time.sleep(1)
    def crashes(self):
        return self.adb('logcat', '-b', 'crash', '-d', '-v', 'brief')

# Each result is an operator observation, not inferred from a tap or an XML title.
SCENARIOS = [
 ('AUTH-01', 'Demarrage et connexion', [], 'Ouvrez l app. Authentifiez-vous vous-meme. Verifiez accueil charge, absence de crash et compte correct.'),
 ('AUTH-02', 'Identifiants invalides et retour', [], 'Si vous pouvez vous deconnecter sans perdre un acces necessaire : verifiez erreur claire pour un mot de passe incorrect, puis connexion valide. Aucun secret dans le commentaire.'),
 ('AUTH-03', 'Biometrie', ['Reglages'], 'Activez la biometrie si disponible. Mettez l app en arriere-plan puis revenez : annulez une demande, verifiez que la session reste verrouillee, puis authentifiez-vous. Echec si annulation donne acces. N utilisez pas de commande pour contourner le verrou.'),
 ('AUTH-04', 'Premier acces', [], 'Avec un compte de test de premier acces : activation, changement du mot de passe, profil obligatoire et guide. Verifiez blocage avant completion. Sinon marquez non verifie.'),
 ('PROFILE', 'Profil et apercu photo', ['Mon profil'], 'Ouvrez la photo, verifiez apercu, fermeture et retour au profil. Verifiez informations et ordre alphabetique des membres si accessible.'),
 ('ACADEMY-01', 'Academy lecture et navigation', ['Academy'], 'Ouvrez un cours autorise, Continuer puis une lecon : texte complet, illustrations, bouton Commencer entier et retour. Ne marquez pas terminee sur un compte reel.'),
 ('ACADEMY-02', 'Progression et quiz verrouilles', ['Academy'], 'Ouvrez un cours avec prerequis non termines : acces lecon/quiz bloque clairement. Verifiez quiz rapides lisibles en sombre. Pas de reponse ni soumission sur compte reel.'),
 ('ACADEMY-03', 'Lecture hors connexion', ['Academy'], 'Chargez une lecon accessible puis coupez temporairement WiFi ET donnees mobiles vous-meme. Verifiez lecture locale. Retablissez la connexion avant de repondre. Synchronisation de progression testee dans les scenarios avec ecriture.'),
 ('RECRUIT-01', 'Recrutement liste et detail', ['Recrutement'], 'Si votre role autorise : statuts lisibles, fiche, onglets Documents/Evaluation, historique, retour. Sinon utilisez N ; ne changez aucune decision.'),
 ('RECRUIT-02', 'Candidature publique', [], 'Ouvrez Postuler et Suivre ma candidature. Verifiez retour, champs lisibles et Comment avez-vous connu Enactus ESP. Pas de soumission sur compte reel ; campagne absente signifie scenario non verifie.'),
 ('TASKS', 'Taches et fichier de preuve', ['Taches'], 'Ouvrez une tache, actions selon affectation, formulaire de statut et selecteur fichier de preuve. Annulez le selecteur et le formulaire. Le workflow enregistre est reserve au compte de test.'),
 ('VEILLE', 'Veille et droits', ['Pole Veille', 'Veille'], 'Verifiez suivi personnel, details et retours ; controles de decision uniquement pour les roles autorises. Une seule session ne valide pas les droits des autres roles.'),
 ('FINANCE', 'Finance et justificatif', ['Finance'], 'Ouvrez declaration puis selection fichier, annulez sans enregistrer. Verifiez paiement manuel ; PayDunya est hors perimetre de lancement.'),
 ('SHARE', 'Partage Android vers Finance', [], 'Depuis une IMAGE FICTIVE dans Galerie/Fichiers : Partager vers EnactSpace. Verifiez reception du justificatif dans Finance puis annulez sans enregistrer. Ne partagez pas de recu personnel.'),
 ('ARCHIVES', 'Archives et minutes', ['Archives'], 'Ouvrez projet, concours et Minute de l enacteur : images, texte, dates, retour. Verifiez source Phototheque Enactus ESP et absence de messages techniques.'),
 ('IMPACT', 'Impact', ['Impact'], 'Ouvrez une fiche : illustration, details, navigation et retour. Verifiez donnees reellement chargees, pas seulement titre de page.'),
 ('PORTFOLIO', 'Poles et projets', ['Poles'], 'Ouvrez pole puis projet, presentation/documents et retour. Verifiez outils visibles selon role. Annulez toute modification.'),
 ('ALUMNI', 'Alumni et annee', ['Alumni'], 'Verifiez liste et profils connus convertis. Dans Reglages, regardez annee et suivi sans enregistrer. Passage annuel et conversion sont des scenarios avec ecriture.'),
 ('DOCUMENTS', 'Documents et hors connexion', ['Documents', 'Docs'], 'Ouvrez un document telecharge et reglement interieur. Coupez reseau vous-meme, verifiez acces local, puis retablissez reseau.'),
 ('COMMUNICATION', 'Chat et EnactMeet', ['Chat'], 'Verifiez chargement, historique, lecteur audio si disponible et piece jointe avec annulation. Ouvrez EnactMeet et parametres sans creer/envoyer/enregistrer de reunion.'),
 ('HELP', 'Guide FAQ et remarques', ['Reglages'], 'Ouvrez aide, guide, FAQ, formulaire signalement/suggestion puis annulez. Verifiez retour et absence de jargon backend.'),
 ('PUSH', 'Notification reelle', [], 'Seulement si une notification de test est deja autorisee et disponible : verifiez reception app fermee et ouverture vers destination correcte. Ne declenchez pas un envoi aux membres. Sinon N.'),
 ('DISPLAY', 'Sombre clair paysage grand texte', ['Reglages'], 'Testez clair/sombre puis texte systeme 200 pour cent et paysage : recrutement, Academy, Veille, login. Verifiez lisibilite, boutons, clavier et retour. Restaurez ensuite vos reglages initiaux.'),
 ('RESUME', 'Reprise et retour Android', [], 'Accueil puis arriere-plan/reprise, biometrie si activee, retour systeme sur details. Verifiez session et navigation. Ce scenario ne teste pas un redemarrage complet du telephone.'),
]
WRITES = [
 ('WRITE-ACADEMY', 'Progression et quiz synchronises', ['Academy'], 'COMPTE DE TEST : terminer une lecon en ligne, quiz complet, resultat et deblocage. Puis hors ligne terminer une autre lecon autorisee et remettre reseau : synchronisation, reouverture et absence de doublon.'),
 ('WRITE-TASK', 'Tache affectee et validation', ['Taches'], 'COMPTES DE TEST : affecteur cree tache ; executant A faire -> En cours -> soumission avec fichier ; affecteur valide/refuse ; comparez Veille et Taches. Verifiez refus des actions par membre non affecte. Tous les roles doivent etre reellement testes.'),
 ('WRITE-RECRUIT', 'Candidature et campagne', ['Recrutement'], 'CAMPAGNE DE TEST : questionnaire modifiable, candidature fictive avec fichier, suivi, evaluation humaine, historique et conversion autorisee. Verifiez message redirige vers adresse de test ; ne lancez pas campagne reelle.'),
 ('WRITE-ALUMNI', 'Conversion et changement annuel', ['Alumni'], 'PROFILS DE TEST : convertir enacteur en alumni, verifier annuaire et droits puis changement annuel sans conversion non desiree. Verifiez traces et absence de doublon.'),
 ('WRITE-FINANCE', 'Justificatif et validation manuelle', ['Finance'], 'COMPTE DE TEST : declaration paiement FICTIF avec fichier, revue par financier et rejet/correction, coherence soldes. Aucun paiement ni transfert reel.'),
 ('WRITE-HELP', 'Signalement et traitement', ['Reglages'], 'COMPTE DE TEST : soumettre signalement clairement marque TEST, verifier reception, traitement et retour utilisateur. Aucun destinataire reel de courriel.'),
]

def save_report(report, directory):
    directory.mkdir(parents=True, exist_ok=True)
    results = report['results']
    report['counts'] = dict(collections.Counter(x['status'] for x in results))
    report['status'] = ('FAILED' if report.get('runner_error') or any(x['status'] == 'FAIL' for x in results)
                        else 'PARTIAL' if any(x['status'] in ('NOT_VERIFIED', 'ERROR') for x in results)
                        else 'GUIDED_SCENARIOS_PASSED')
    report['updated_utc'] = dt.datetime.now(dt.timezone.utc).isoformat()
    payload = json.dumps(report, indent=2, ensure_ascii=False)
    target = directory / 'report.json'
    temp = directory / 'report.json.tmp'
    temp.write_text(payload, encoding='utf-8')
    temp.replace(target)
    lines = ['# Recette Android EnactSpace', '', 'Statut : ' + report['status'], '',
             'Les PASS manuels sont des observations de l operateur. Ce rapport ne certifie pas tous les roles, la securite du serveur ni la recette web.', '',
             '| ID | Scenario | Statut | Preuve |', '| --- | --- | --- | --- |']
    for r in results:
        lines.append('| ' + ' | '.join(str(r.get(k, '')).replace('|', '/').replace('\n', ' ') for k in ('id', 'title', 'status', 'evidence')) + ' |')
    (directory / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')

def ask_outcome():
    while True:
        answer = input('Resultat [O=verifie OK, E=echec, N=non verifie, Q=arreter] : ').strip().upper()
        if answer in ('O', 'E', 'N', 'Q'):
            return answer

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--serial', default='R83XA0BB4FK')
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--include-write-scenarios', action='store_true')
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error('Output directory must not exist (no overwrite).')
    device = Device(args.serial)
    scenarios = SCENARIOS + (WRITES if args.include_write_scenarios else [])
    report = {'serial': args.serial, 'package': PACKAGE, 'expected_version': '1.0.11+14',
              'write_scenarios_enabled': args.include_write_scenarios,
              'credentials_collected': False, 'raw_ui_saved': False, 'screenshots_saved': False,
              'build_performed': False, 'server_configuration_changed': False,
              'results': [{'id': x[0], 'title': x[1], 'status': 'NOT_VERIFIED', 'evidence': 'Not run'} for x in SCENARIOS + WRITES]}
    save_report(report, args.output)
    baseline = None
    try:
        if device.adb('get-state').strip() != 'device':
            raise RuntimeError('Device not authorized')
        package = device.adb('shell', 'dumpsys', 'package', PACKAGE)
        code = re.search(r'\bversionCode=(\d+)', package)
        name = re.search(r'\bversionName=([^\s]+)', package)
        if not code or not name or (code.group(1), name.group(1)) != ('14', '1.0.11'):
            raise RuntimeError('Installed app is not 1.0.11+14')
        report['android_sdk'] = device.adb('shell', 'getprop', 'ro.build.version.sdk').strip()
        report['preflight'] = 'PASS: ADB authorized and installed version 1.0.11+14'
        print('Version et ADB verifies. Aucun mot de passe ne sera saisi par ce script.')
        print('Les captures/UI et journaux bruts ne sont pas conserves. Commentaires sans donnees personnelles.')
        if args.include_write_scenarios:
            confirm = input('Confirmez comptes/campagne fictifs ET redirection des emails verifiee. Tapez TEST UNIQUEMENT : ')
            if confirm != 'TEST UNIQUEMENT':
                raise RuntimeError('Write scenarios not confirmed')
            report['write_safety'] = 'Operator confirmed test identities/campaign and email redirection; not independently verified'
        baseline = device.crashes()
        device.launch()
        for scenario, row in zip(scenarios, report['results']):
            print('\n' + scenario[0] + ' - ' + scenario[1])
            print(scenario[3])
            try:
                row['navigation'] = device.navigate(scenario[2]) if scenario[2] else 'manual'
            except (RuntimeError, subprocess.TimeoutExpired, ET.ParseError, ValueError):
                row['navigation'] = 'manual_required: UI unavailable'
            if row['navigation'].startswith('manual'):
                print('Naviguez vous-meme vers cet ecran. Authentifications toujours manuelles.')
            answer = ask_outcome()
            if answer == 'Q':
                break
            row['status'] = {'O': 'PASS', 'E': 'FAIL', 'N': 'NOT_VERIFIED'}[answer]
            row['evidence'] = input('Observation courte sans nom/email/mot de passe (Entree pour aucune) : ').strip()[:400]
            row['evidence_kind'] = 'operator_observation'
            after = device.crashes()
            crashes = new_app_crashes(baseline, after)
            if crashes:
                row['status'] = 'FAIL'
                row['crash_blocks_detected'] = crashes
                row['evidence'] = 'New app crash detected; ' + row['evidence']
            baseline = after
            row['app_process_alive'] = bool(device.adb('shell', 'pidof', PACKAGE, allow_missing_process=True).strip())
            # Process absence alone is not a failure: logout/external chooser can change app state.
            save_report(report, args.output)
    except KeyboardInterrupt:
        report['interrupted'] = True
    except Exception as exc:
        report['runner_error'] = type(exc).__name__ + ': ' + str(exc)[:160]
        report['preflight'] = report.get('preflight', 'ERROR')
        print('Controle interrompu : ' + report['runner_error'])
    finally:
        save_report(report, args.output)
        print('\nRapport : ' + str(args.output / 'report.md'))
        print('Retablissez WiFi/donnees mobiles et vos reglages texte/theme/orientation si modifies.')
        print('Statut : ' + report['status'])
    return 1 if report.get('runner_error') or report['status'] == 'FAILED' else 2 if report['status'] == 'PARTIAL' else 0

if __name__ == '__main__':
    sys.exit(main())
