# Recrutement EnactSpace — synchronisation Web du 6 novembre 2026

## Périmètre

Cette livraison reprend **uniquement les sources utiles au Web et à l’API utilisée par le Web** depuis la version effectivement publiée sur le VPS. Elle ne modifie **aucune configuration ni aucun artefact Android**. Le dossier local de reprise comportait plusieurs centaines de modifications indépendantes ; aucune d’elles n’est copiée globalement.

La branche historique `main` renvoie vers `feature/recruitment-ui-20261101`, qui constitue la base de cette synchronisation. Intégrer les fichiers uniquement après contrôle, sans écraser les travaux non enregistrés sur le poste de développement.

## Fonctionnalités reprises de la production

- Page publique de candidature disponible sur `https://enactspace.kerunjombor.net/#/recruitment/apply`.
- Lors d’une campagne ouverte, le parcours « Créer un compte » demande si la personne veut **postuler** (redirection vers le formulaire officiel) ou est déjà **enacteur/alumni** (continuation du parcours de compte).
- Membres d’EnacChef habilités à consulter les candidatures anonymisées de la campagne.
- Membres du jury habilités à consulter et évaluer les candidatures avec **au moins trois avis distincts**, les dossiers ayant le moins d’avis apparaissant en priorité.
- Autorisations de lecture supplémentaires, limitées à une campagne et révocables, pour des enacteurs/alumni sélectionnés.
- Rubrique Membres : suppression de compte à usage administratif, avec aperçu des dépendances, confirmation explicite de l’adresse e-mail, refus lorsqu’un compte possède des rôles, candidatures ou historiques à conserver.
- Script de compilation Web `frontend/tool/build_web_production_guarded.ps1` : impose l’URL de production et vérifie la présence de l’URL dans `main.dart.js`.

## Base de données

La migration `20261106_0034_recruitment_viewer_access.py`, après `20261031_0033`, crée la table `recruitment_viewer_access` pour les nouveaux environnements. Sur une base ayant reçu le correctif SQL du 6 novembre 2026, elle **vérifie la structure existante** avant d’enregistrer la version ; elle ne doit ni effacer les autorisations ni réinitialiser la campagne.

Avant tout déploiement, examiner les contraintes et indexes de la table réellement en service. Ne jamais appliquer une migration non testée directement sur la base utilisée par les candidats.

## Construction Web uniquement

Depuis `frontend` sur Windows :

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\build_web_production_guarded.ps1
```

Le script définit `ENACTSPACE_API_URL=https://api-enactspace.kerunjombor.net` à la compilation, puis refuse de valider un build qui n’embarque pas cette URL.

**Ne pas relancer une compilation sans `--dart-define`.** L’absence de ce paramètre avait causé l’écran « Impossible de charger les campagnes » lors du premier essai de publication.

## Validation de la livraison

Avant toute nouvelle publication, effectuer l’analyse Dart, les tests des accès API, puis ouvrir dans un navigateur vierge l’URL de candidature et la page de connexion depuis l’origine HTTPS réelle. Vérifier les possibilités de création de compte, le chargement de la campagne et les permissions des jurés, et s’assurer qu’aucun dossier n’a été modifié par les tests.

## Production et retour arrière

Le VPS conserve les sources de livraison et les copies de secours dans :

- `/opt/enactspace/operations/recruitment-access-20261106/`
- `/opt/enactspace/releases/web-before-rc-v3-20261106/`

Le backend Web courant utilise `enactspace_backend_canary_v3` avec une route réversible. Les images historiques demeurent disponibles. Toute bascule doit préserver la continuité des dépôts et les fichiers de justificatifs.

Cette synchronisation GitHub est **distincte** d’une nouvelle publication : la version Web validée reste déjà accessible en production.
