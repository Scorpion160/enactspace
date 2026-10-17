# EnactSpace

EnactSpace is the private digital workspace for Enactus ESP. It brings membership, projects, communication, attendance, finance, impact, operational integrity, and institutional memory into one maintained platform.

Le web, l’API et l’APK Android installé sont en **1.0.13** (build clients **16**) au 10 octobre 2026. Le dernier checkpoint source est `b152677372ded22d63b544b1336240902613b559`, qui conserve le correctif backend de première connexion. Voir [l’état de release](docs/releases/20261010-release-1.0.13.md) et les [vérifications restantes](docs/RELEASE_CHECKLIST.md). La livraison technique est confirmée; toutes les validations fonctionnelles et les publications de stores ne sont pas encore terminées.

## Platform

- Flutter `3.47.5` used for the latest builds for Android, iOS, and web clients.
- FastAPI on Python 3.12 for the API and background operations.
- PostgreSQL 16 for production and concurrency-sensitive validation.
- Alembic migrations through `20261007_0031`.

Android and iOS are the primary mobile targets; web is a supported build target. Production endpoints are supplied through external build configuration. Provider credentials, signing material and secrets are never committed.

## Repository map

- `frontend/` — Flutter client and native platform shells.
- `backend/` — FastAPI service, migrations, and backend tests.
- `docs/` — canonical operations/development guidance plus historical evidence.
- `.github/` — CI, security automation, dependency updates, and contribution governance.

## Start here

- [Documentation index](docs/README.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Portable development setup](docs/DEVELOPMENT.md)
- [Test matrix](docs/TEST_MATRIX.md)
- [Operations runbook](docs/OPERATIONS_RUNBOOK.md)
- [Secrets and environments](docs/SECRETS_AND_ENVIRONMENTS.md)
- [Mobile release and push](docs/MOBILE_RELEASE_AND_PUSH.md)
- [Release checklist](docs/RELEASE_CHECKLIST.md)
- [Pôle IT handoff](docs/POLE_IT_HANDOFF.md)

## Ownership and status

V1 conçue et développée par Chicodev — 2026. Maintenance: Pôle IT — Enactus ESP. The exact Pôle IT GitHub team remains an administrative handoff item; `@Scorpion160` is the current repository fallback owner.

This is a private repository and no public open-source license is currently declared. See [NOTICE](NOTICE.md). GitHub Actions execution, protected-branch policy, organizational ownership mapping, and PR-8 mobile distribution gates must be closed before release as described in the canonical checklist.
