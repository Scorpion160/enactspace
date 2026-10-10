# V1.0.0 release checklist

This checklist governs EnactSpace V1.0.0 release execution. It does not by itself create a tag, GitHub Release, signed artifact, deployment, or merge.

Record gate evidence in the [release evidence index](RELEASE_EVIDENCE_INDEX.md). Store preparation uses [store release metadata](STORE_RELEASE_METADATA.md), the [privacy disclosure worksheet](PRIVACY_DISCLOSURE_WORKSHEET.md), and [artifact provenance](ARTIFACT_PROVENANCE.md). These records do not close a gate by themselves.

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
- [ ] Exactly one Alembic head: `20261007_0031`.
- [ ] Flutter lock file is unchanged; analysis and full tests pass.
- [ ] Web release and Android debug compile checks pass.
- [ ] Backup is complete and restore rehearsal evidence is accepted.
- [ ] Deployment and database rollback decisions are reviewed.

## Security, privacy, and operations

- [ ] No credentials, private keys, signing/provider files, real environment files, private URLs, or member data are present in source or artifacts.
- [ ] Vendored third-party components have documented provenance and all required license/notices are included in source and distributed artifacts.
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

## Première connexion — lot 24, source non déployée

- [x] Activation individuelle, profil obligatoire, parcours Alumni et confirmation de l'année implémentés et testés sur données synthétiques.
- [x] Migration 0030 répétée sur schéma isolé ; anciens états et historique d'accueil conservés.
- [ ] Confirmer individuellement les contacts manquants et les situations d'accès avec la SG et les membres.
- [ ] Recette réelle Android/web du build final : activation, accueil, consentement légal, récupération et accès selon les rôles.
- [ ] Vérifier invitation et notifications avec la redirection de test, puis examiner la file avant toute bascule des destinataires.
- [ ] Après validation de la mise en service et livraison cohérente backend/app/web, préparer les invitations individuelles au moment de l'ouverture.

Guide : [Premières connexions](FIRST_ACCESS_ONBOARDING.md). Preuves : [Lot 24](releases/20261007-prelaunch-lot24-first-access.md).

## Centre d’aide — lot 25, source non déployée

- [x] Guide, FAQ, aide pendant l’accueil et traitement sécurisé implémentés.
- [x] 88 tests SQLite, 32 PostgreSQL et 105 Flutter réussis ; migration 0031 répétée.
- [ ] Recette finale téléphone/web : aide pendant l’accueil, envoi, réponse, suivi, droits, mode sombre et textes agrandis.
- [ ] Vérifier la réception des alertes en redirection et le lien de navigation sur téléphone.
- [ ] Confirmer les personnes chargées du traitement à l’ouverture et contrôler leurs accès actifs.

Guide : [Centre d’aide](HELP_SUPPORT_OPERATIONS.md). Preuves : [Lot 25](releases/20261007-prelaunch-lot25-help.md).

## Sauvegarde et restauration — lot 26

Restauration locale isolée vérifiée : 19 tests de protection, 111 tables et 721 lignes comparées, schéma complet contrôlé, 14 fichiers et leurs références intacts. Les modifications synthétiques de contrainte, d’index et de colonne sont détectées. La copie Windows et la récupération depuis sa clé DPAPI sont vérifiées. Restent le second secours de clé, la reprise sur un hôte neuf, la planification, la conservation et les objectifs RPO/RTO. Voir [les preuves](releases/20261008-prelaunch-lot26-backup-restore.md) et [la procédure](V1_1_BACKUP_RESTORE.md).

Sauvegardes planifiées : timer actif à 03 h 00 UTC et premier lancement systemd validé, quatre tests de garde réussis. La copie automatique hors du VPS, le secours de clé remis à un second détenteur et la reprise sur un hôte neuf restent à terminer. Voir les preuves du lot 26.
