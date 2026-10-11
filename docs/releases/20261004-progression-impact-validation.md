# EnactSpace 1.0.3+4 — Academy progressive et Impact illustré

Date : 4 octobre 2026.

## Résultat livré

Les cours Academy possèdent des prérequis persistants et modifiables. Une formation préalable doit avoir toutes ses leçons terminées et ses quiz publiés réussis. Le serveur contrôle l’accès au démarrage, à la validation des leçons et aux quiz, et masque les contenus verrouillés dans le catalogue. L’interface explique les prérequis et permet d’ouvrir leurs fiches. Le bouton Continuer choisit une formation accessible à poursuivre. Les apprentissages déjà engagés restent accessibles ; les nouvelles formations dépendantes conservent leur exigence de réussite.

La configuration initiale contient 24 cours, dont 23 avec des dépendances. Pour un nouveau membre, Découvrir Enactus ouvre le parcours ; les branches se débloquent selon les acquisitions utiles au sujet. Le choix administratif d’une liste vide est préservé et n’est pas réécrit par l’initialisation.

Les illustrations Academy utilisent 16 dessins Canvas, sans dépendance aux glyphes d’une police d’icônes. Chaque leçon propose des illustrations et une photo du club. Les photos peuvent être agrandies avec zoom et retour. Les légendes des images Aquatus et SHERY décrivent leur contexte sans attribuer un prototype à une photographie de personnes. Les polices Poppins sont embarquées, avec licence OFL et provenance, afin d’éviter le téléchargement à l’ouverture.

Impact présente quatre récits illustrés, des fiches de projet structurées et une lecture adaptée aux petits écrans, aux grands caractères et au mode sombre. Les chiffres historiques gardent leur période et ne sont pas ajoutés aux résultats actuels. Les tâches validées comptent parmi les livrables réalisés ; les retards sont calculés à partir de la date d’échéance et excluent les tâches terminées, validées ou annulées.

Le Pôle Veille fait l’objet d’un document de cadrage à discuter. Aucun nouveau tableau d’évaluation, barème ou flux disciplinaire Veille n’est intégré dans cette livraison.

## Vérifications

- Flutter : 704 tests réussis, suite complète ; flutter analyze sans anomalie.
- Serveur : 269 tests recensés, 261 exécutés avec succès et 8 ignorés ; suite complète dans une base SQLite éphémère, indépendante de la production.
- Les nouveaux tests vérifient notamment les prérequis, les tentatives de contournement, la séparation des progressions entre membres, les cours déjà engagés, les quiz, les cycles de dépendances et la conservation du choix administratif.
- 19 tests visuels vérifient les dessins, les photos et les quatre récits Impact à 360, 768 et 1440 pixels, avec mode sombre et texte agrandi. Les captures finales ont été examinées après chargement des polices et des images.
- Les compilations web et Android release sont terminées avec succès. Les avertissements de simulation Wasm et de migration Kotlin des plugins n’empêchent pas ces builds ; une compilation Wasm n’est pas livrée.
- Migration PostgreSQL appliquée : 20261004_0020 → 20261004_0021. Les empreintes des contenus, identifiants, quiz, questions, progressions, tentatives et certificats ont été comparées avant et après la configuration. Aucun de ces éléments n’a été modifié.
- Initialisation des prérequis : 24 cours, 23 cours dépendants, un cours accessible à un nouveau membre ; seconde initialisation sans modification.
- Catalogue du serveur déployé contrôlé en lecture : contenus des 23 cours verrouillés masqués et accès direct refusé. Aucun compte de test n’a été ajouté en production.
- Web, version.json, health, police embarquée et photo testée : HTTP 200. Catalogue Academy sans authentification : HTTP 401 attendu.
- Backend et web en bonne santé ; workers email et push actifs, sans redémarrage après livraison. Empreinte du JavaScript public identique à celle du build et Cache-Control sans cache.

## Livraison et traçabilité

- Web : https://enactspace.kerunjombor.net/
- API : https://api-enactspace.kerunjombor.net/
- Version : 1.0.3, build 4.
- Image serveur : enactspace-backend:progression-impact-20261004.
- Image SHA-256 : f3551309c032e5b2feed10fd93b7f6be8a5e76cf45b56248aeecd30101ff7215.
- main.dart.js SHA-256 : 434ea9ee1a9aaf1b39062aebe4161fda90f9c34da4e0e740bcfa65ed7d1548fe.
- APK : C:\Users\DIOP\Downloads\EnactSpace-1.0.3-release-20261004-progression-impact.apk.
- APK SHA-256 : ce632dd29084532020fcacc2b7791b4c21b4d441f098ce4c8cc13899bff00483.
- Application Android : sn.enactusesp.enactspace ; versionCode 4, versionName 1.0.3 ; arm64-v8a, armeabi-v7a et x86_64.
- Signature APK vérifiée ; certificat SHA-256 identique à la version précédente : 38e8274a7b63174cbf06f5d5b15e68b623fdb9fae92538ad9b7f470611e484d5.

## Sauvegarde et retour arrière

Sauvegardes avant migration : /opt/enactspace/backups/progression-impact-20261004, dossier restreint au propriétaire. Archive PostgreSQL contrôlée avec pg_restore --list sur une copie dans le conteneur, sources backend et ancien web sauvegardés. Le fichier PostgreSQL possède un en-tête PGDMP valide.

- database.dump SHA-256 : 396870b61d63d39624fd729179a2e67fca2b2c7bb0d63b8fc3420cdd9a77da0a.
- backend-source.tar.gz SHA-256 : 97a6b5deceaa56bf9e8a60d0bb52d1e12675d2ac224c36fb680fd9602b6ad2d6.
- web.tar.gz SHA-256 : 7bac60b24486c7a4839f6f7ea105e4196e8af4d7df2176d8c2e4615456f07866.

L’ancienne image enactspace-backend:academy-school-final-20261004 est conservée. Le retour aux anciens exécutables peut conserver la nouvelle colonne nullable, que les anciens modèles ignorent ; ne pas restaurer la base complète sans examiner les nouvelles données produites depuis la sauvegarde. Pour retirer la colonne, utiliser le downgrade Alembic dans une fenêtre de maintenance après sauvegarde, ce qui supprime les réglages de prérequis. La restauration web utilise l’archive de cette livraison.

## Limites des vérifications

Aucun appareil Android physique n’était connecté à ADB. L’installation sur téléphone, l’authentification biométrique physique et une navigation complète avec un compte réel n’ont pas été vérifiées dans cette livraison. Les contrôles fonctionnels des écrans sont automatisés ; les contrôles de production décrits ci-dessus ne remplacent pas cette recette sur appareil. Le dépôt n’est pas poussé à distance dans cette étape. Le fichier de sauvegarde préexistant email_worker.py.before-model-registration-fix reste hors du commit.
