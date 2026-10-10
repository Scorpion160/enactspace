# Architecture

## État de production — 10 octobre 2026

Le client web, l’APK installé et l’API déclarent `1.0.13`; les clients portent le build `16`. Le schéma PostgreSQL est à `20261007_0031`. Quatre services partagent l’image backend : API, email-worker, push-worker et veille-worker. Le dernier correctif de première connexion est conservé dans le checkpoint `b152677372ded22d63b544b1336240902613b559`.

Les membres et leurs statistiques concernent les enacteurs, séparément des alumni. Les profils alumni internes précréés restent consultables selon les permissions de l’annuaire sans exiger leur activation. Les conversations directes avec soi-même sont refusées. Le parcours disciplinaire distingue proposition, approbations et exécution datée, avec révocation des accès et conservation de l’historique.

Voir [l’état détaillé de la release](releases/20261010-release-1.0.13.md).

## Procédures générales et contexte antérieur

## System boundary

EnactSpace consists of a Flutter client, a FastAPI backend, PostgreSQL 16, persistent file storage, and external notification/payment providers. The repository contains application code and safe templates; production infrastructure, secrets, signing identities, and provider consoles remain outside source control.

## Client

The Flutter application targets Android, iOS, and web from `frontend/`. It uses a configured HTTPS API base URL for release builds. Authentication credentials use the platform's protected storage path, with legacy storage migration retained by the product implementation. Network retry and refresh behavior is bounded and must preserve single-use refresh rotation semantics.

## Backend

FastAPI routes in `backend/app/api/routes/` delegate to services and SQLAlchemy models. The service exposes health/system endpoints, OpenAPI metadata, account and session functions, project/member operations, files, notification channels, and the product-readiness domains. Background push delivery is separated from request handling.

Authentication uses short-lived access tokens and rotating, single-use refresh sessions. Refresh-token material is represented server-side using HMAC-derived storage; raw refresh credentials must not be logged, placed in URLs, or persisted outside approved client storage. Session revocation and logout semantics remain security boundaries.

## Data and migrations

PostgreSQL 16 is the production database and the authority for concurrency-sensitive behavior. SQLite is used only for safe application-engine unit tests where supported. Alembic owns production schema evolution. The current single head is `20261007_0031`; production starts with `AUTO_CREATE_TABLES=false`, and migrations run before application rollout.

The migration chain covers account/privacy/legal controls, impact truth and provenance, institutional memory, product services, push lifecycle, operational integrity, and memory/heritage operational capture. Do not infer data provenance or verification from presentation-layer values.

## Files and push

Uploaded files reside in configured persistent storage and are served through credential-aware API paths. Backups must cover both PostgreSQL and the file store consistently. Push registrations and delivery lifecycle are backend-controlled; provider credentials are external secrets. Android/iOS provider configuration and physical-device evidence remain release gates.

## Deployment boundaries

The reverse proxy terminates public HTTPS and forwards only to a loopback-bound backend. PostgreSQL and file storage are not public services. CI uses disposable synthetic credentials and a disposable PostgreSQL service; it does not deploy or sign applications. Production deployment, database backup, signing, provider configuration, and store submission require authorized operators and evidence.

No secret values belong in this document or elsewhere in the repository.
