# Préparation à la mise en service — lot 7
Date : 2026-10-07T12:07:53.458838+00:00

## Corrections vérifiées
- La modification globale des rôles ne peut plus retirer le dernier administrateur disponible. La suppression directe utilise le même contrôle.
- Les deux actions se sérialisent sur la même ligne de rôle PostgreSQL. Les comptes inactifs, désactivés ou non vérifiés ne servent pas à contourner la protection.
- Les responsabilités du Team Leader, de la SG et des membres restent limitées : un membre ne peut pas se nommer administrateur, le Team Leader ne peut pas attribuer le rôle administrateur, la SG ne peut pas attribuer le rôle Team Leader.
- Les identifiants utilisateur mal formés renvoient 404 au lieu de provoquer une erreur SQL dans les accès utilisateur et les actions utilisant lock_user.
- Annuaire trié par nom de famille, puis prénom, sans différence de casse ; identifiant stable pour départager.
- Annuaire : nom utilisateur, cursus et spécialité existants désormais renvoyés. Le champ année d'adhésion n'existe pas dans le modèle User : aucune année n'a été inventée ni nouvelle migration introduite pour cela.

## Tests exécutés
- 126 tests backend PASS, réseau désactivé : 115 régressions précédentes et 11 nouveaux tests de rôles/annuaire.
- 6 tests PASS sur PostgreSQL 16 isolé, comme la version majeure en service.
- Retraits simultanés, un par édition globale et un par suppression directe : un succès, un refus 409, un administrateur conservé.
- Régressions PostgreSQL de quotas, consommation unique du code de réinitialisation et migrations également réussies.
- Conteneur et réseau PostgreSQL de test supprimés par le runner ; aucune base réelle utilisée.

## Dépendances
- Résolution neuve sous Linux/Python 3.12 à partir des requirements modifiés, installée uniquement dans le conteneur d'audit éphémère.
- 83 paquets audités, dépendances backend et outils d'audit inclus ; pip-audit 2.10.1 en mode strict, aucune vulnérabilité connue retournée.
- Les versions exactes sont conservées dans 20261007-prelaunch-lot7-resolved-dependency-audit.json. Les plages des requirements ne constituent pas encore un verrouillage complet reproductible : résolution à figer ou vérifier de nouveau lors de l'image finale.
- Le réseau a servi uniquement à télécharger et auditer des paquets publics. Aucun code applicatif, identifiant de production ou base de données n'était monté dans le conteneur d'audit.
- Deux premiers essais de l'environnement d'audit ont échoué sur les permissions du tmpfs puis du cache. Corrections limitées au conteneur éphémère, audit final réussi.
- Premier essai PostgreSQL de concurrence : fixture sans rôle Enacteur de base, correction de la fixture puis résultat final réussi.

## Lecture et limites
Lecture intégrale de users.py, deps.py, roles.py, schemas/user.py et operational_integrity.py ; registre de relecture mis à jour. La relecture manuelle de l'ensemble du dépôt reste inachevée.

Serveur public inchangé ; aucun push GitHub, build, déploiement, message réel ou nettoyage des données du club. Restent les permissions des autres modules, les parcours fonctionnels sur téléphone/web, le nettoyage ciblé de la campagne de test et la documentation finale avant la bascule.
