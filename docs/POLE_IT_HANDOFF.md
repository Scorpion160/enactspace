# Pôle IT handoff

This runbook enables a maintainer to rehearse ownership without undocumented Chicodev knowledge. Complete it with sanitized evidence; never record secret values.

## RACI by role

| Activity | Responsible | Accountable | Consulted | Informed |
| --- | --- | --- | --- | --- |
| Repository triage and dependency updates | Pôle IT maintainer | Pôle IT lead | Feature owner | Enactus ESP leadership |
| Security incident containment | Pôle IT security/operations | Enactus ESP security authority | Hosting/provider owners | Affected stakeholders |
| Database migration, backup, restore | Database/operations maintainer | Release authority | Backend maintainer | Pôle IT lead |
| Mobile signing and stores | Mobile release owner | Enactus ESP account owner | Pôle IT maintainer | Release stakeholders |
| Production deployment/rollback | Operations maintainer | Release authority | Database, security, feature owners | Enactus ESP leadership |

Named people and exact Pôle IT GitHub handles/team: **to be formally supplied**. Until then, `@Scorpion160` is only the repository fallback owner.

## Access checklist

- [ ] GitHub repository and organization role; date/reviewer:
- [ ] Hosting/VPS and reverse proxy; date/reviewer:
- [ ] PostgreSQL administration and backup store; date/reviewer:
- [ ] File storage and monitoring/log platform; date/reviewer:
- [ ] DNS/TLS; date/reviewer:
- [ ] Firebase/GCP provider ownership; date/reviewer:
- [ ] PayDunya/payment provider ownership; date/reviewer:
- [ ] Apple Developer/App Store Connect ownership; date/reviewer:
- [ ] Google Play Console ownership; date/reviewer:
- [ ] Approved secret/signing custody and break-glass process; date/reviewer:

Access evidence should identify the role and successful authorized check, never the credential.

## Environment and test checklist

- [ ] Environment inventory distinguishes development, test, staging (if any), and production.
- [ ] Database, storage, domains, provider modes, and secret ownership are mapped per environment.
- [ ] Local backend setup completed from canonical requirements.
- [ ] Isolated PostgreSQL 16 full backend suite passes without skips.
- [ ] Flutter 3.44.9 lock, analysis, full tests, web build, and Android debug build pass.
- [ ] A maintainer can explain current Alembic head `20260910_0008` and migration rules.

Evidence/date/maintainer/reviewer:

## Deployment rehearsal

Using a disposable environment, rehearse backup, environment validation, migration, application rollout, HTTPS health check, representative authorization/file flows, monitoring, and app rollback. Record duration, decision points, sanitized output, gaps, owner, and due date.

Evidence/date/maintainer/reviewer:

## Restore rehearsal

Restore a PostgreSQL backup and matching file-store snapshot into an isolated environment. Validate schema head, record counts, constraints/provenance, representative files, authentication, and application behavior. Record measured duration; RPO/RTO remain **to be approved by Enactus ESP** until formally decided.

Evidence/date/maintainer/reviewer:

## Incident rehearsal

Simulate a credential exposure or data-integrity alert. Demonstrate intake, severity, containment, private escalation, provider/key rotation path, session/provider impact assessment, evidence preservation, recovery verification, and post-incident ownership.

Evidence/date/maintainer/reviewer:

## Release rehearsal

Walk the [release checklist](RELEASE_CHECKLIST.md) without creating a tag or deploying. Verify CI evidence, review/governance, backup, rollback, version identity, artifact provenance, approvals, and exception handling.

Evidence/date/maintainer/reviewer:

## External mobile gates

- [ ] Android external release signing and physical FCM evidence.
- [ ] Apple Push Notifications capability, distribution signing/provisioning, and production entitlement.
- [ ] Signed iOS archive and physical iOS APNs/FCM evidence.
- [ ] Apple/Google store ownership, listings, privacy declarations, support contacts, and URLs.

Evidence/date/owner/reviewer for each gate:

## Acceptance

- Open administrative items:
- Risks accepted by Enactus ESP:
- Handoff accepted by:
- Date:
- Evidence location:
