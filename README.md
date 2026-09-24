# EnactSpace

EnactSpace is the private digital workspace for Enactus ESP. It brings membership, projects, communication, attendance, finance, impact, operational integrity, and institutional memory into one maintained platform.

The current release target is **V1.0.0** (`1.0.0+1` for the Flutter application). This repository does not claim that V1.0.0 is deployed or publicly released; the remaining release and external mobile gates are tracked in the [release checklist](docs/RELEASE_CHECKLIST.md).

## Platform

- Flutter `3.44.9` / Dart `3.12.2` for Android, iOS, and web clients.
- FastAPI on Python 3.12 for the API and background operations.
- PostgreSQL 16 for production and concurrency-sensitive validation.
- Alembic migrations through `20260913_0009`.

Android and iOS are the primary mobile targets; web is a supported build target. Production URLs, push providers, mobile signing, and store distribution are external environment/release concerns and are never embedded in the repository.

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
