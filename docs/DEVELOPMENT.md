# Development

## Configuration actuelle et continuité

La compilation utilisateur du 10 octobre a utilisé Flutter `3.47.5`. Enregistrer `flutter --version` et `python --version` pour toute nouvelle construction; ne pas mettre à jour les dépendances uniquement pour supprimer les messages « newer versions available ». Les builds livrés utilisent `--build-name=1.0.13 --build-number=16`, indépendamment de la version par défaut du pubspec.

La prochaine construction doit partir du checkpoint `b152677372ded22d63b544b1336240902613b559` ou d’un descendant contenant le correctif de première connexion. Le clone de récupération Windows comporte des modifications locales : utiliser un clone isolé pour une récupération Git; aucun reset, checkout ou pull forcé sur ce dossier.

Sous Windows PowerShell, enregistrer les programmes Python multilignes dans un fichier UTF-8 puis exécuter `python fichier.py`. Éviter `python -c $code`, qui a supprimé des guillemets lors des contrôles. Pour SSH, transmettre le programme en base64 sur stdin sans imprimer les valeurs privées.

Voir [les commandes de build et d’exploitation](releases/20261010-release-1.0.13.md).

## Procédures générales et contexte antérieur

This guide is portable. Run commands from a clone of the repository; do not copy machine-specific absolute paths, LAN addresses, or device identifiers into shared documentation.

## Required toolchain

- Python 3.12.
- PostgreSQL 16 for integration and concurrency tests.
- Flutter 3.47.5 used for the latest delivered builds; record the installed Dart version.
- Git and the Android SDK for Android debug builds.

## Backend setup

From `backend/`, create and activate a virtual environment using the syntax for your operating system, then install the canonical dependencies:

```text
python -m venv .venv
python -m pip install -r requirements.txt
```

Copy `backend/.env.production.example` only as a field-name reference. For development or test, set process-local values explicitly. Generate independent random values locally for `SECRET_KEY`, `JWT_SECRET_KEY`, `REFRESH_TOKEN_HMAC_KEY`, and any enabled feature secret. Never share a default password or reuse production credentials.

Use `DATABASE_URL=sqlite://` for the supported unit-test application engine. Use `TEST_DATABASE_URL` only for an isolated, disposable PostgreSQL 16 database whose name satisfies the repository's test guards. Keep `APP_ENV=test` and `AUTO_CREATE_TABLES=false` during the full validation suite.

Before starting the API, inspect `python -m alembic heads`; the expected single head is `20261007_0031`. Production-like PostgreSQL schemas are created with `python -m alembic upgrade head`, never by postponing migrations until after application startup.

## Flutter setup

From `frontend/`:

```text
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
```

`pubspec.lock` is authoritative. Dependency resolution must leave it unchanged unless a reviewed dependency update intentionally changes the lock file. The delivered application version is `1.0.13+16`; supply it explicitly to release builds.

Debug runs may use a loopback/emulator-specific local API URL. Release builds must use an authorized HTTPS endpoint supplied with `ENACTSPACE_API_URL`; plain HTTP and machine/LAN addresses are not release configuration. Android debug artifacts are not distributable releases.

## Build checks

The portable web build check uses a non-routable placeholder:

```text
flutter build web --release --no-pub --dart-define=ENACTSPACE_API_URL=https://example.invalid
flutter build apk --debug --no-pub
```

The Android command proves debug compilation only. External signing is required for release distribution. An optional iOS compile check may be run on an authorized macOS runner with `flutter build ios --release --no-codesign`; it does not prove signing, entitlements, APNs, archive, or device delivery.
