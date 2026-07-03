# EnactSpace V1 - Vue globale

Date: 2026-07-03

EnactSpace est la plateforme interne d'Enactus ESP. La V1 couvre la coordination quotidienne, la communication, les membres, les poles, les projets, les presences, la finance, les documents, le recrutement, les alumni, l'impact, Academy, Archives / Hall of Fame et la gamification.

## Objectif V1

- Donner une vue adaptee a chaque utilisateur.
- Proteger les donnees selon les roles.
- Simplifier le travail des Enacchefs.
- Offrir aux enacteurs et alumni une experience proche des apps sociales modernes.
- Conserver la memoire du club via Archives et Hall of Fame.

## Stack

- Frontend: Flutter.
- Backend: FastAPI.
- Base: SQLAlchemy.
- Temps reel: WebSocket interne avec fallback polling.
- Fichiers: FileStorageService et routes `/api/files`.

## Validation courante

- `flutter analyze --no-pub`
- `python -m compileall backend/app`
- `git diff --check`

## Documents V1 lies

- `docs/V1_MODULES.md`
- `docs/V1_TEST_PLAN.md`
- `docs/V1_KNOWN_LIMITATIONS.md`
- `docs/V1_DEPLOYMENT_NOTES.md`
- `docs/v1_test_accounts.md`
- `docs/v1_backend_permissions_audit.md`
- `docs/v1_navigation_audit.md`
