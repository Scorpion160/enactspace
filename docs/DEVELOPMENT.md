# Développement local

## Repartir d’un clone neuf

```bash
git clone --branch feature/recruitment-ui-20261101 --single-branch https://github.com/Scorpion160/enactspace.git
cd enactspace
git status --short --branch
git rev-parse HEAD
```

Travailler dans un nouveau clone. Un dossier de récupération peut contenir des fichiers locaux et une configuration propre à son poste. Le [point de reprise attesté](releases/20261103-web-1.0.25-backend-1.0.23.md) permet de retrouver le lot publié à l’octet près.

Installer Git, Python 3.12, Docker avec Compose v2, Flutter 3.47.5 et Chrome. Ajouter le SDK Android pour les essais mobiles et un Mac avec Xcode pour iOS. `flutter doctor -v` identifie les outils manquants. La chaîne de génération des documents institutionnels peut demander LaTeX. Reprendre les paquets du workflow Application CI.

## Démarrer l’API et une base locale

Depuis `backend/`, créer un environnement avec `python -m venv .venv`. Sous Windows, activer `.venv\Scripts\Activate.ps1`. Sous Linux ou macOS, activer `.venv/bin/activate`. Installer les dépendances avec `python -m pip install -r requirements.txt`.

Exemple PowerShell avec le Compose PostgreSQL éphémère du dépôt. Le port de démonstration reste sur la boucle locale. Le mot de passe est créé pour la session.

```powershell
$env:PR2B_TEST_DB_PASSWORD = python -c "import secrets; print(secrets.token_hex(32))"
$env:PR2B_TEST_DB_PORT = '55432'
$env:SECRET_KEY = python -c "import secrets; print(secrets.token_hex(48))"
$env:APP_ENV = 'development'
$env:APP_DEBUG = 'false'
$env:APP_VERSION = '0.0.0-local'
$env:AUTO_CREATE_TABLES = 'false'
$env:ENABLE_SEED = 'false'
$env:EMAIL_ENABLED = 'false'
$env:PUSH_ENABLED = 'false'
$env:MOBILE_MONEY_ENABLED = 'false'
$env:PAYMENT_PROVIDER_ENABLED = 'false'
$env:FILE_STORAGE_PATH = 'uploads'
$env:DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:55432/enactspace_pr2b_test"
docker compose -p enactspace-it-dev -f docker-compose.test.yml up -d --wait
python -m alembic heads
python -m alembic upgrade head
python -m alembic current
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

La révision attendue sur la branche est `20261031_0033`. Tester ensuite `http://127.0.0.1:8000/health` et `http://127.0.0.1:8000/docs`. La première sonde contrôle la réponse de l’application. La seconde montre les contrats de l’API. Laisser le terminal du serveur ouvert. Une nouvelle session Compose recrée une base vide. Employer les fixtures pour les tests et les comptes fictifs de la [démo](alumni_day_demo.md) pour explorer l’interface. Pour une recette API avec comptes, l’amorçage `/api/seed/initial` est réservé à une base de développement vide, en boucle locale et avec `ENABLE_SEED=true` le temps de créer un compte de test. Remettre l’option à `false` et redémarrer avant d’élargir l’accès.

## Lancer Flutter

Depuis `frontend/`, dans un second terminal :

```bash
flutter --version
flutter pub get
git diff --exit-code -- pubspec.lock
flutter run -d chrome --web-port=51833 --dart-define=ENACTSPACE_API_URL=http://127.0.0.1:8000
```

Sur l’émulateur Android, la boucle hôte est `10.0.2.2`. Sur un téléphone physique, utiliser une API de recette autorisée. Le paramètre `ENACTSPACE_API_URL` doit désigner une URL HTTPS en release. Garder `pubspec.lock` stable lors d’une modification fonctionnelle. Modifier le verrou dans une contribution de dépendances revue.

Le mode démo emprunte des écrans natifs et des gateways fictives. Une recette démo valide la navigation et la présentation. Prévoir des tests du contrat et des parcours avec l’API pour les droits, la persistance et les files.

## Modifier une fonctionnalité

1. Reproduire sur un clone et consigner scénario, rôle, navigateur ou appareil.
2. Identifier la route Flutter et le service ou `Gateway`, puis la route FastAPI et ses dépendances d’autorisation.
3. Vérifier les schémas Pydantic, modèles et contraintes SQL avant de changer un contrat ou une transaction. Garder les clients précédents compatibles durant un déploiement échelonné.
4. Tester les cas autorisés et refusés, les reprises après erreur, les tentatives répétées et la concurrence selon le risque.
5. Lancer les [contrôles de la matrice](TEST_MATRIX.md). Documenter le résultat, les commandes et la stratégie de retour arrière dans la contribution.

Pour une évolution de données, partir du head réel, créer une migration additive si possible et tester installation vide et mise à niveau sur PostgreSQL isolé. Revoir les valeurs nulles, les contraintes, les index, le temps de verrouillage et le sort des données historiques. Un retour à une ancienne image ne remet pas la base à un état antérieur.
