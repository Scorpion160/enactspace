# V1.0.0 release checklist

This checklist is for PR-8/release execution. PR-7 does not create a tag, release, signed artifact, deployment, or merge to `main`.

## Repository and governance

- [ ] Release commit and scope approved; no unrelated changes.
- [ ] Replacement application CI has at least one successful GitHub run, or the repository owner records an explicit exception to the billing/execution gate.
- [ ] Security workflow and dependency audit pass.
- [ ] `main` review/check/force-push/deletion policy is enforced, or capability limitations and the approved manual fallback are recorded.
- [ ] Formal Pôle IT GitHub handles/team are mapped in CODEOWNERS and maintainer records.
- [ ] One merge strategy and stale-branch cleanup responsibility are approved.

## Application and data

- [ ] Backend compile, OpenAPI import, and full tests pass without PostgreSQL suite skips.
- [ ] PostgreSQL 16 migration/reversal/concurrency evidence is current.
- [ ] Exactly one Alembic head: `20260910_0008`.
- [ ] Flutter lock file is unchanged; analysis and full tests pass.
- [ ] Web release and Android debug compile checks pass.
- [ ] Backup is complete and restore rehearsal evidence is accepted.
- [ ] Deployment and database rollback decisions are reviewed.

## Security, privacy, and operations

- [ ] No credentials, private keys, signing/provider files, real environment files, private URLs, or member data are present in source or artifacts.
- [ ] Production secrets are independently generated, stored, access-reviewed, and rotation-ready.
- [ ] Privacy/legal content and account-deletion behavior are approved.
- [ ] Monitoring, logging, incident contacts, escalation, and change window are ready.
- [ ] RPO/RTO are approved by Enactus ESP or explicitly accepted as open risk.

## Mobile and push external gates

- [ ] Android release is externally signed and verified; debug signing is not used.
- [ ] Physical Android FCM lifecycle evidence is accepted.
- [ ] Apple Push Notifications capability is enabled for the production App ID.
- [ ] iOS distribution signing/provisioning and production `aps-environment` are verified.
- [ ] Signed iOS distribution archive is accepted.
- [ ] Physical iOS APNs/FCM lifecycle evidence is accepted.
- [ ] Store listings, privacy declarations, support contacts, and store URL ownership are approved.

## Release decision

- [ ] Release identifier/date:
- [ ] Commit/tag to create only after approval:
- [ ] Release authority:
- [ ] Operations owner:
- [ ] Security/privacy reviewer:
- [ ] Evidence location:
- [ ] Remaining exceptions, owner, expiry:
- [ ] Go / no-go decision and timestamp:
