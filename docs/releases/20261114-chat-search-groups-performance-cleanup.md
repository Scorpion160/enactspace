# EnactSpace — Chat, gestion des groupes et optimisation (v1.0.30+41)

## Comportements
- **Recherche des discussions** : les mots saisis sont pris en compte immédiatement, quel que soit l'ordre prénom/nom, avec une tolérance aux accents usuels. La croix efface le filtre.
- **Ajout de participants / nouvelle discussion** : recherche automatique après 320 ms de pause de frappe, sans avoir à appuyer sur Entrée ou la flèche. La dernière recherche prime sur une réponse réseau antérieure. Les pôles et projets ne sont pas redemandés à chaque frappe.
- **Gérer les participants** : accès visible dans l'en-tête des groupes pour les administrateurs et propriétaires, avec ajout/retrait et confirmation. Possibilité de nommer administrateur, puis de retirer le rôle admin, également avec confirmation. Les membres ordinaires n'obtiennent pas ces commandes ; les discussions directes restent à deux.
- **Synchronisation Chat** : suspension des interrogations périodiques quand l'application est réellement en arrière-plan ou suspendue ; la synchronisation demeure active lorsque l'écran est visible.
- **Backend** : recherche d'annuaire par tous les mots saisis, quel que soit leur ordre dans les champs prénom, nom ou e-mail ; caractères SQL spéciaux traités comme du texte.

## Dédoublonnage et données — actions hors dépôt

Audit de tous les comptes : 48 profils avant fusion. Un seul groupe de doublons exacts confirmé (même nom normalisé et même téléphone), tous les autres noms et téléphones sans répétition exacte. Une sauvegarde PostgreSQL a été créée, validée avec `pg_restore -l` et conservée hors dépôt. Les dépendances du compte historique ont été vérifiées sur toutes les colonnes FK de `users`.

La simulation transactionnelle a confirmé que les notifications, les historiques d'e-mails, les anciennes affiliations inactives et les données du compte récent pouvaient être préservés. Fusion réalisée et vérifiée ; 47 comptes restants et un seul profil pour l'identité concernée. Aucune modification des candidatures ni notification émise. La sauvegarde privée est sous `/opt/enactspace/backups/account-consolidation-20261114/`.

## Nettoyage VPS — actions hors dépôt

- Audit initial : 59 Gio utilisés sur disque 193 Gio ; 5,8 Gio sous `staging`, 3,2 Gio sous `releases`, caches BuildKit abondants.
- Un premier nettoyage ciblé a retiré 129,8 Mo d'anciens caches Docker inutilisés (âge minimum de 14 jours).
- Ensuite, suppression transactionnellement vérifiée d'**une liste exacte de 60 anciens emplacements de staging**, soit 1 508 071 077 octets : anciens lots de tests d'octobre, SDK Flutter téléchargé dans une livraison précédente et cache Pub redondant. Tous ont été vérifiés non montés dans les conteneurs en cours et non protégés.
- Fichiers de trace : `/opt/enactspace/operations/cleanup-20261114/completed-staging-prune.json`. Les bases, volumes, images Docker, répertoires `web`, `app`, `backups`, `releases` et scripts de retour arrière ont été préservés.
- API `/health` saine et Web `1.0.30+40` toujours servi après nettoyage.

## Livraison

- CI GitHub sur la branche d'intégration, tests Flutter des recherches/groupes et tests Python de recherche de contacts.
- Base Web constatée : `1.0.30+40`, empreinte SHA-256 de `main.dart.js` `e69c3282ec8c365756e13969da1e7b79b9f20053e76b7d309f9723acecc23f1e`.
- Version cible `1.0.30+41`. Aucun paiement réel ni message aux candidats ; conserver les données et la version précédente pour retour arrière.

**Éléments qui demandent encore une mesure en conditions réelles** : performance perçue de l'ouverture des fils, stabilité sur réseau mobile instable, échanges multimédias lourds, tests multiutilisateurs d'EnactMeet. Les tests de santé API et la charge CPU/mémoire ne démontrent pas à eux seuls l'absence de latence côté navigateur.
