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
6. From `backend/`, confirm `python -m alembic heads` returns only `20260910_0008 (head)`.
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
