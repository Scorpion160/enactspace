# EnactSpace documentation

Use this page to distinguish maintained operating instructions from historical evidence.

## Canonical

These documents define the current V1.0.0 target and should be updated with operational changes:

- [Repository overview](../README.md)
- [Architecture](ARCHITECTURE.md)
- [Development](DEVELOPMENT.md)
- [Test matrix](TEST_MATRIX.md)
- [Operations runbook](OPERATIONS_RUNBOOK.md)
- [First access and onboarding](FIRST_ACCESS_ONBOARDING.md)
- [Secrets and environments](SECRETS_AND_ENVIRONMENTS.md)
- [Mobile release and push](MOBILE_RELEASE_AND_PUSH.md)
- [Release checklist](RELEASE_CHECKLIST.md)
- [Store release metadata](STORE_RELEASE_METADATA.md)
- [Privacy disclosure worksheet](PRIVACY_DISCLOSURE_WORKSHEET.md)
- [Release evidence index](RELEASE_EVIDENCE_INDEX.md)
- [Artifact provenance](ARTIFACT_PROVENANCE.md)
- [Pôle IT handoff](POLE_IT_HANDOFF.md)

Repository governance also lives in [CONTRIBUTING](../CONTRIBUTING.md), [SECURITY](../SECURITY.md), [MAINTAINERS](../MAINTAINERS.md), [NOTICE](../NOTICE.md), and [CHANGELOG](../CHANGELOG.md).

## Historical / audit evidence

Files under `docs/audits/`, `docs/product_readiness/`, `docs/security/`, review bundles, test reports, design captures, and dated implementation records preserve evidence from a specific point in time. They may mention old versions, counts, branches, limitations, or deployment experiments. Treat them as evidence, not as current operating instructions.

All non-canonical `V1_*` and `v1_*` documents are retained for historical context, including dated Android/LAN/build records. The eight legacy operational guides reviewed for PR-7 contain prominent redirects to current canonical procedures. Other dated V1 records are evidence only, even when they contain commands. A historical filename does not define the current product version.

## Deprecated

`V1_INSTALLATION_GUIDE.md`, `V1_RELEASE_NOTES.md`, `V1_KNOWN_LIMITATIONS.md`, `v1_test_accounts.md`, and operational `V1_1_*` guides are deprecated as authoritative instructions. They remain only to explain earlier decisions and must not override the canonical documents above.

If documents conflict, stop and use the canonical V1.0.0 documentation. Record any unresolved operational decision in the release checklist instead of guessing.

- [Centre d’aide et traitement des retours](HELP_SUPPORT_OPERATIONS.md)

- [Sauvegarde et restauration des données](V1_1_BACKUP_RESTORE.md)

- [Copie chiffrée et récupération Windows](BACKUP_RECOVERY_WINDOWS.md)

## Continuité après sauvegarde GitHub — 8 octobre 2026

- [Checkpoint et vérifications du lot 27](releases/20261008-prelaunch-lot27-github-continuity.md)
- [Configuration et génération du worker Firebase web](FIREBASE_WEB_DEPLOYMENT.md)
