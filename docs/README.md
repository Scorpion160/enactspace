# Documentation EnactSpace

## Parcours de prise en main

1. Lire la [passation du pôle IT](POLE_IT_HANDOFF.md), la [fiche de publication du 3 novembre](releases/20261103-web-1.0.25-backend-1.0.23.md) et la [carte d’architecture](ARCHITECTURE.md).
2. Préparer l’[environnement de développement](DEVELOPMENT.md), puis exécuter la [matrice de tests](TEST_MATRIX.md).
3. Avant tout changement en service, utiliser le [guide d’exploitation](OPERATIONS_RUNBOOK.md), la [checklist](RELEASE_CHECKLIST.md) et le [registre des preuves](RELEASE_EVIDENCE_INDEX.md).

## Procédures par domaine

| Sujet | Guide |
| --- | --- |
| Confidentialité et configuration | [Environnements et secrets](SECRETS_AND_ENVIRONMENTS.md), [politique de sécurité](../SECURITY.md) |
| Activation et support | [Première connexion](FIRST_ACCESS_ONBOARDING.md), [centre d’aide](HELP_SUPPORT_OPERATIONS.md) |
| E-mail et notifications | [Diagnostic des messages](MESSAGING_TROUBLESHOOTING.md), [Firebase web](FIREBASE_WEB_DEPLOYMENT.md) |
| Android, iOS et publication en boutique | [Livraison mobile](MOBILE_RELEASE_AND_PUSH.md), [métadonnées de store](STORE_RELEASE_METADATA.md), [confidentialité](PRIVACY_DISCLOSURE_WORKSHEET.md) |
| Campagne 2026 | [Préparation](RECRUITMENT_CAMPAIGN_READINESS_202611.md), [jury et questionnaire](RECRUITMENT_CAMPAIGN_2026_JURY_AND_QUESTIONNAIRE.md), [guide du jury](recruitment-jury-guide.md) |
| Sauvegarde et restauration | [Exploitation](OPERATIONS_RUNBOOK.md), [répétition de restauration](releases/20261008-prelaunch-lot26-backup-restore.md), [copie de secours Windows](BACKUP_RECOVERY_WINDOWS.md) |
| Identification des artefacts | [Provenance](ARTIFACT_PROVENANCE.md), [preuves de release](RELEASE_EVIDENCE_INDEX.md) |

## Gouvernance et archives

La [contribution](../CONTRIBUTING.md), la [maintenance](../MAINTAINERS.md), les [droits d’usage](../NOTICE.md) et le [journal des versions](../CHANGELOG.md) se lisent à la racine du dépôt.

Les dossiers d’audit, rapports `V1_*`, captures et fiches de release datées conservent le contexte des décisions. Pour une intervention, partir de la procédure active et de la fiche correspondant à la version réellement servie. Vérifier les paramètres de l’environnement auprès de son responsable si les documents divergent.
