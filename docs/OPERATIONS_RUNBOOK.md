# Operations runbook

This is the canonical V1.0.0 production operations sequence. It records required controls, not evidence that a deployment has occurred.

## Prerequisites

- An approved release commit and completed [release checklist](RELEASE_CHECKLIST.md).
- Authorized Pôle IT operator plus a second reviewer for migration/release decisions.
- PostgreSQL 16, persistent file storage, HTTPS reverse proxy, monitoring, and restricted service accounts.
- Production environment values delivered through the approved secret store, never Git.
- A verified database backup and file-store backup tied to the same release window.

RPO and RTO are **to be approved by Enactus ESP**. Until approved, do not promise a recovery window; record actual rehearsal measurements and escalate the decision.

## Deployment sequence

1. Record commit, application version, operator, reviewer, date, and change window.
2. Confirm monitoring, free storage, database health, provider status, and rollback artifact availability.
3. Quiesce writes if the migration/release plan requires it.
4. Create and verify backups before any migration.
5. Validate environment names with the repository validator without printing values.
6. From `backend/`, confirm `python -m alembic heads` returns only `20261007_0031 (head)`.
7. Apply `python -m alembic upgrade head` before starting the new application. Keep `AUTO_CREATE_TABLES=false`.
8. Deploy the approved backend and client artifacts. The public API must use HTTPS; bind the application service to a private/loopback interface behind the proxy.
9. Run health, authentication, authorization, file-access, and representative domain smoke checks with dedicated non-production-like operator identities.
10. Observe error rate, latency, worker/push status, database connections, storage, and logs through the change window.

## Health and inspection

Check the public `/health` endpoint, expected V1.0.0 metadata, reverse-proxy TLS, database reachability, file storage read/write permissions, and background worker state. Inspect logs through the hosting platform or service manager. Sanitize evidence: never paste tokens, authorization headers, private records, SMTP/provider payloads, or environment contents.

## Rollback decision tree

- If the application fails before a migration, restore the prior application artifact and verify health.
- If a backward-compatible migration succeeded but the app fails, prefer application rollback only after confirming the prior code supports the migrated schema.
- If a migration is not backward compatible, stop writes and follow the migration-specific downgrade/data-restoration plan. Do not improvise `alembic downgrade` on production.
- If data integrity is uncertain, stop the rollout, preserve logs and backups, restrict writes, and escalate to the database owner and release authority.
- If credentials or private data may be exposed, contain access first, rotate affected values, preserve sanitized evidence, and follow `SECURITY.md`.

Database rollback can lose or reinterpret data written after migration. A successful Alembic downgrade is not proof of business-data restoration. Restore rehearsals must validate record counts, constraints, provenance, files, and application behavior.

## Backup and restore

Backups must cover PostgreSQL and persistent uploaded files, be encrypted, access-controlled, retention-approved, and restoration-tested in an isolated environment. Record backup identifier, timestamp, source release/schema, file-store snapshot, checksum where available, restore duration, validation owner, and disposal evidence. Never restore production data into an uncontrolled developer environment.

## Incident triage and escalation

1. Establish severity, affected surface, first-known time, and current user/data impact.
2. Contain unsafe writes or access without destroying evidence.
3. Notify the on-call Pôle IT maintainer, service owner, privacy/security contact, and Enactus ESP release authority as applicable.
4. Record sanitized timeline, decisions, mitigations, and validation.
5. Recover using a rehearsed path, monitor recurrence, and complete a post-incident review.

Contact names, escalation time objectives, RPO, RTO, and hosting/provider support channels are administrative fields in [Pôle IT handoff](POLE_IT_HANDOFF.md) and remain **to be approved by Enactus ESP** until supplied.

## Première connexion à l'ouverture

Le parcours source du lot 24 doit être livré avec la mise à jour backend et Flutter correspondante. Suivre [Premières connexions](FIRST_ACCESS_ONBOARDING.md) : préparation des contacts par la SG/Team Leader, activation individuelle, récupération des comptes utilisés réservée à l'administrateur, profil obligatoire et confirmation de l'année. Ne pas distribuer de mot de passe collectif ou choisi par un responsable. Les invitations de 30 minutes sont préparées après la mise à disposition de l'application. La redirection des courriels de test est conservée jusqu'à la bascule finale approuvée.

## Centre d’aide — lot 25

Suivre [Centre d’aide et traitement](HELP_SUPPORT_OPERATIONS.md). Le guide public reste accessible avant connexion ; l’accueil ouvre les demandes personnelles. Administration, Team Leader et SG actifs et habilités traitent les retours, avec réponses publiques et notes internes séparées. Livrer la migration 0031 et les versions backend/app/web compatibles ensemble. Vérifier les notifications en redirection avant la bascule approuvée ; aucun envoi réel n’a été effectué dans ce lot.

## Sauvegarde et restauration — lot 26

Restauration locale isolée vérifiée : 19 tests de protection, 111 tables et 721 lignes comparées, schéma complet contrôlé, 14 fichiers et leurs références intacts. Les modifications synthétiques de contrainte, d’index et de colonne sont détectées. La copie Windows et la récupération depuis sa clé DPAPI sont vérifiées. Restent le second secours de clé, la reprise sur un hôte neuf, la planification, la conservation et les objectifs RPO/RTO. Voir [les preuves](releases/20261008-prelaunch-lot26-backup-restore.md) et [la procédure](V1_1_BACKUP_RESTORE.md).

Sauvegardes planifiées : timer actif à 03 h 00 UTC et premier lancement systemd validé, quatre tests de garde réussis. La copie automatique hors du VPS, le secours de clé remis à un second détenteur et la reprise sur un hôte neuf restent à terminer. Voir les preuves du lot 26.
