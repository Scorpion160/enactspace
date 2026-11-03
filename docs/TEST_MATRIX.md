# Matrice de tests

## Dernière preuve de livraison

Le [lot du 3 novembre](releases/20261103-web-1.0.25-backend-1.0.23.md) atteste 1 146 tests Flutter et 115 tests sur l’image backend isolée. Les nombres sont datés. Utiliser les cas ci-dessous et les workflows pour valider une prochaine modification.

| Surface | Cas à couvrir |
| --- | --- |
| Comptes et droits | Anonyme, rôle autorisé, rôle insuffisant, ressource d’un autre périmètre, révocation et rotation concurrente |
| Recrutement | Ouverture/clôture à la limite Dakar, doublons, suivi après fermeture, questionnaire, jury, fichier privé, conversion et reprise |
| Académie, tâches, Veille | Progression, concurrence, nouvelle tentative, cohérence des statuts et des récompenses |
| Finance et fichiers | Accès et visibilité, justificatifs, preuves, états fournisseur, absence de doublon |
| Messages et accès | Modèle, liens, horaires, reprise de session, file, tentative, réception contrôlée et désinscription push |
| Interface | Clair/sombre, petit écran, clavier et taille de texte, états vide/chargement/erreur |
| Publication | Provenance, empreinte, sauvegarde, migration si applicable, santé, quatre services et retour arrière |

## Backend et PostgreSQL

Depuis `backend/`, avec l’environnement Python de [développement](DEVELOPMENT.md) :

```bash
python -m compileall -q app
python -c "from app.main import app; assert app.openapi().get('paths')"
python -m alembic heads
python -m unittest ops_checks.backup_integrity_checks -v
python -m unittest discover -v
```

Pour la suite complète, utiliser `APP_ENV=test`, `AUTO_CREATE_TABLES=false`, `DATABASE_URL=sqlite://`, une clé éphémère, un répertoire fichiers isolé, et les fournisseurs e-mail, push et paiement désactivés. Garder les deux variables de tests PostgreSQL distinctes des paramètres applicatifs. Les deux peuvent désigner la même base locale jetable dont le nom commence par `enactspace_pr2b_test_`. Le suffixe est nécessaire à certaines suites Veille et de reprise.

Exemple PowerShell pour créer cette base dans un projet Compose de test distinct. Le mot de passe est généré pour cette session et le port reste en boucle locale.

```powershell
$env:PR2B_TEST_DB_PASSWORD = python -c "import secrets; print(secrets.token_hex(32))"
$env:PR2B_TEST_DB_PORT = '55433'
docker compose -p enactspace-it-tests -f docker-compose.test.yml up -d --wait
docker compose -p enactspace-it-tests -f docker-compose.test.yml exec -T postgres createdb -U pr2b_test enactspace_pr2b_test_it
$env:APP_ENV = 'test'
$env:APP_DEBUG = 'false'
$env:SECRET_KEY = python -c "import secrets; print(secrets.token_hex(48))"
$env:DATABASE_URL = 'sqlite://'
$env:AUTO_CREATE_TABLES = 'false'
$env:ENABLE_SEED = 'false'
$env:EMAIL_ENABLED = 'false'
$env:PUSH_ENABLED = 'false'
$env:MOBILE_MONEY_ENABLED = 'false'
$env:PAYMENT_PROVIDER_ENABLED = 'false'
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:55433/enactspace_pr2b_test_it"
$env:VEILLE_TEST_POSTGRESQL_URL = $env:TEST_DATABASE_URL
python -m unittest discover -v
```

Lancer le bloc dans un terminal de test neuf. Vérifier la présence de `pdflatex` et GnuPG pour les suites documentaires et de sauvegarde. Après la recette, arrêter le projet jetable avec `docker compose -p enactspace-it-tests -f docker-compose.test.yml down` et fermer ce terminal. Tout test ignoré doit être expliqué et rejoué pour la recette concernée. SQLite seul ne valide ni PostgreSQL ni les courses concurrentes. Le head attendu est `20261031_0033` sur cette branche.

## Flutter et publication

```bash
flutter pub get
git diff --exit-code -- pubspec.lock
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub --dart-define=ENACTSPACE_API_URL=https://example.invalid
flutter build apk --debug --no-pub
```

Ces compilations utilisent une configuration de test. Pour publier, appliquer [Firebase web](FIREBASE_WEB_DEPLOYMENT.md), [livraison mobile](MOBILE_RELEASE_AND_PUSH.md) et [checklist](RELEASE_CHECKLIST.md). Les tests physiques, la réception réelle et la restauration restent des preuves distinctes. Vérifier le workflow du commit concerné dans Actions et consigner son résultat ou l’écart.
