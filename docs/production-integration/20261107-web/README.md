# Réconciliation EnactSpace Web — 7 novembre 2026

## Objectif et provenance

Cette branche part de `main` (commit `4a4debe`) et réintègre, sans toucher au
serveur, le code nécessaire à la version Web déjà en production.

- **Flutter Web :** copie isolée des sources en service. Les neuf fichiers de
  la dernière livraison correspondent octet par octet à l'archive du VPS.
- **Backend :** code Python du backend de production, avec les corrections V2
  de présélection et V3 de gestion des membres (empreintes vérifiées).
- **Migrations :** six migrations manquantes `0032` à `0037` récupérées depuis
  l'image en service, puis migration `0038` idempotente pour les accès de lecture
  temporaires et la valeur par défaut de trois évaluations.
- **Éléments liés :** ressources Flutter, dépendances Web, tests et script
  `frontend/tool/build_web_production_guarded.ps1`.

## Vérifications réalisées

- Analyse Dart complète de `lib` et `test` : **aucune erreur**.
- **109 tests** du recrutement et des membres : **tous réussis**.
- Compilation de syntaxe Python : réussie.
- Compilation Flutter **Web release** : réussie, avec `ENACTSPACE_API_URL`.
- Empreinte SHA256 du JavaScript compilé **identique à la production** :
  `721BB91DDD55465309ACEBEF2F6F8E5F9DAC08FBC58D150CFD07C451749DCC90`.
- Analyse heuristique de secrets du code ajouté : aucun signal après exclusion
  du fichier de configuration Firebase généré.
- Aucune compilation Android, aucune opération sur les candidatures ni sur
  la base en production.

## Ressources et données à garder hors GitHub

Le dépôt GitHub est **public** : ne pas importer de `.env`, de secrets SMTP,
de jetons, de clés de signature, d'exports PostgreSQL ou de fichiers candidats.

Le fichier `frontend/web/firebase-messaging-sw.js` est généré avec des
identifiants du projet Firebase ; il doit rester fourni par la configuration
de déploiement, et non enregistré tel quel dans ce dépôt.

Le backend en production possède aussi des contenus métiers JSON propres au
serveur, dont certains concernent les évaluations. Ceux-ci ne sont pas inclus
sans validation de leur caractère public. La procédure de déploiement devra
les provisionner en dehors du dépôt.

## Avant fusion dans `main`

1. Exécuter les vérifications GitHub Actions et les tests Flutter complets.
2. Tester l'API contre une **base isolée**, en particulier les permissions,
   les trois évaluations et la suppression sécurisée de comptes.
3. Vérifier la chaîne Alembic jusqu'à `0038` ; **ne pas exécuter de migration
   de test sur la base en production**.
4. Tester un dépôt de candidature, son suivi et ses courriels sur une
   installation de test.
5. Vérifier la présence des ressources métier privées et le service worker
   Firebase lors d'une future livraison.
6. N'autoriser la fusion qu'après revue ; le Web actuellement publié ne doit
   pas être redéployé automatiquement depuis cette branche.

La PR est une **intégration en brouillon** : les sources sont réunies et les
tests ciblés passent, mais les vérifications finales doivent encore être
terminées. Aucun build Android n'est prévu.

## Restauration de l'écran « Campagne en chiffres » (7 novembre 2026)

- La route protégée `/recruitment/statistics` réutilise l'API existante `GET /api/recruitment/statistics` (lecture seule, sans données personnelles).
- Visible par tous les enacteurs et alumni validés ; les dossiers et les évaluations restent soumis aux permissions des jurés et d'EnacChef.
- Cinq ventilations : département, année, niveau, promotion, canal de découverte.
- Les deux comptes créés par erreur ont été supprimés en production à la demande de l'administration ; leurs courriels d'orientation ont été envoyés. Ne jamais reproduire ces actions sur une base de test ou lors du déploiement.
- 136 tests ciblés Flutter réussis. Formulaire public vérifié dans un navigateur vierge sur une prévisualisation HTTPS, sans candidature fictive.
- Version Web publiée : `b8773cad16cd0b53b698ead0d52696573e5ea958df3782ab3f60c12940f4cf4d` SHA256 de `main.dart.js`.
- Retour arrière VPS : `/opt/enactspace/releases/web-before-campaign-stats-20261107`.
- **Aucun build Android, aucune migration ou modification du backend** lors de cette restauration.
