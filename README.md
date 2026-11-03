# EnactSpace

EnactSpace est l’espace numérique d’Enactus ESP. L’application réunit les membres, les projets, les pôles, la communication, la présence, les finances, le recrutement, l’Academy et la mémoire du club.

## Reprendre le projet

Le code de reprise et la documentation à jour se trouvent sur [la branche `feature/recruitment-ui-20261101`](https://github.com/Scorpion160/enactspace/tree/feature/recruitment-ui-20261101). Le [guide de passation du pôle IT](https://github.com/Scorpion160/enactspace/blob/feature/recruitment-ui-20261101/docs/POLE_IT_HANDOFF.md) donne l’ordre de prise en main. La [fiche de publication du 3 novembre 2026](https://github.com/Scorpion160/enactspace/blob/feature/recruitment-ui-20261101/docs/releases/20261103-web-1.0.25-backend-1.0.23.md) atteste le web 1.0.25 (28), le backend 1.0.23 et le schéma Alembic `20261031_0033`.

La branche `main` contient le code et les procédures de la base historique V1.0.0. Les références ci-dessous décrivent cette base.

## Platform at the V1.0.0 checkpoint

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

No public open-source license is currently declared. See [NOTICE](NOTICE.md). The checklist on this branch records the original V1.0.0 release gates.
