# Exploitation EnactSpace

La [fiche de publication du 3 novembre 2026](releases/20261103-web-1.0.25-backend-1.0.23.md) donne le dernier état attesté. Vérifier l’état en service avant toute intervention et obtenir l’accès auprès du pôle IT.

## Contrôles en lecture seule

```powershell
Invoke-RestMethod 'https://enactspace.kerunjombor.net/version.json'
Invoke-RestMethod 'https://api-enactspace.kerunjombor.net/health'
$calendar = Invoke-RestMethod 'https://api-enactspace.kerunjombor.net/api/recruitment/campaigns/timeline'
$calendar.campaigns | Select-Object title, start_date, end_date
```

Comparer ces réponses au reçu de publication. Contrôler aussi l’état des quatre conteneurs applicatifs et leurs identifiants d’image dans le contexte Compose autorisé. Lire les journaux ciblés par service et intervalle. Conserver des preuves expurgées avec l’heure UTC, la version et l’identifiant d’opération. Une réponse 200 de `/health` atteste le processus API. La base, les fichiers, les droits et les workers exigent des contrôles dédiés.

## Préparer et publier une version

1. **Figer la source.** Noter commit, révisions source client/backend, versions, build, révision Alembic, empreintes et opérateur. Vérifier les suites pertinentes, les accès et la place disque. Obtenir une revue indépendante.
2. **Répéter.** Construire le bundle web et l’image candidate à partir des sources identifiées. Tester hors production avec une base et des fournisseurs isolés. Valider le plan Compose résolu sans imprimer les valeurs. Vérifier l’ancien artefact et l’effet attendu d’un retour arrière.
3. **Sécuriser la bascule.** Acquérir le verrou de publication. Vérifier une sauvegarde récente de PostgreSQL et du volume des pièces jointes. Appliquer le plan de maîtrise des écritures pour une capture cohérente. Conserver le Compose précédent et les artefacts vérifiés.
4. **Décider de la migration.** Comparer le head livré et le schéma en service. Si une migration est nécessaire, évaluer compatibilité et verrous, la répéter, puis l’exécuter dans la fenêtre prévue avant de démarrer le code qui en dépend. Garder `AUTO_CREATE_TABLES=false`. La publication du 3 novembre a conservé la révision 0033.
5. **Basculer et contrôler.** Publier le bundle, vérifier la version et l’empreinte des octets servis. Pour une évolution du backend, recréer les quatre services avec le même identifiant d’image prévu. Vérifier état, schéma, santé et parcours sensibles selon le changement. Observer latence, erreurs, files et stockage.
6. **Clore.** Archiver preuves, portée fonctionnelle, écarts et décision de sortie de fenêtre. Mettre à jour la fiche de publication et conserver les chemins précis du retour arrière dans le dossier d’exploitation restreint.

Les lanceurs datés sous `tools/` épinglent leurs sources, versions et manifestes. Le lot e-mail utilise `release_email_windows.ps1`, `publish_web_release.py` et `publish_interface_copy_backend.py`. Relire les contrôles et préparer de nouveaux manifestes pour un autre lot. Le Compose Git sert de modèle. Le Compose effectif du VPS est la référence opérationnelle et contient la sélection des artefacts en service.

## Suivre une opération en cours

Le lanceur Windows émet un identifiant d’unité systemd pour la bascule backend. Interroger l’unité par `systemctl show` et `journalctl -u`. Lire le reçu `deployment.json` dans le dossier d’opération communiqué par le lanceur. L’attente d’un reçu depuis Windows peut se poursuivre pendant que le travail serveur suit son cours. Vérifier l’état et le reçu avant de décider d’une reprise. Pour le lot e-mail, `-Resume` reprend la publication à partir de l’opération locale dont le reçu de préparation et l’archive correspondent aux empreintes.

## Retour arrière et données

| Situation | Décision |
| --- | --- |
| Régression web | Utiliser le dossier web précédent vérifié, puis contrôler `version.json`, l’empreinte et les routes. |
| API ou workers défaillants, schéma compatible | Rétablir la configuration et l’image précédentes, recréer les quatre services et contrôler leur état. |
| Migration incompatible ou données incertaines | Stabiliser les écritures et conserver les preuves. Avec le responsable base, choisir un correctif en avant ou une restauration validée. |
| Candidatures ou autres écritures après la sauvegarde | Inventorier puis réconcilier les écritures avant toute restauration de données. |

Une restauration associe PostgreSQL et les fichiers cohérents avec la même capture. Restaurer d’abord dans un environnement isolé. Vérifier révision, contraintes, comptages, pièces jointes représentatives, sessions et parcours. Contrôler que la copie hors site et l’accès au déchiffrement sont disponibles, puis mesurer la durée de récupération. Faire valider par Enactus ESP les objectifs de perte de données (RPO) et de durée de rétablissement (RTO). Voir [le compte rendu de restauration](releases/20261008-prelaunch-lot26-backup-restore.md).

## Incidents courants

| Symptôme | Premiers éléments à vérifier |
| --- | --- |
| Web ancien après publication | Version publique, empreinte du bundle, service worker et caches |
| API 5xx ou indisponible | Version API, conteneur, proxy HTTPS, connexions PostgreSQL, dernières erreurs expurgées |
| 401 récurrent ou 403 | Session et révocation pour le 401. Rôle, ressource et portée pour le 403. |
| Candidature impossible | Fenêtre de campagne côté serveur en heure de Dakar, éligibilité, version des questions, pièces et limites |
| E-mail ou push absent | File, tentatives, état du worker, configuration, résultat du fournisseur et réception réelle. Voir [le diagnostic](MESSAGING_TROUBLESHOOTING.md). |
| Fichier manquant | Métadonnées, droits d’accès, volume, espace et cohérence avec la sauvegarde |

Pour chaque incident, dater l’impact et les décisions, protéger les preuves et signaler l’incident selon [SECURITY](../SECURITY.md). Le responsable de publication décide du rétablissement avec les responsables métier, données et sécurité.
