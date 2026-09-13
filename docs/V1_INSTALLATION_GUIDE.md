# EnactSpace V1 — guide d'installation historique

> **DÉPRÉCIÉ / NON AUTORITATIF.** Ce document conserve le contexte du premier parcours V1. Pour toute installation actuelle, utiliser [Development](DEVELOPMENT.md), [Operations runbook](OPERATIONS_RUNBOOK.md), [Secrets and environments](SECRETS_AND_ENVIRONMENTS.md) et [Mobile release and push](MOBILE_RELEASE_AND_PUSH.md).

Date historique: 2026-07-03.

## Principes conservés

Le backend s'installe depuis `backend/` dans un environnement virtuel Python 3.12 avec `backend/requirements.txt`. Le client s'installe depuis `frontend/` avec Flutter 3.44.9 et le `pubspec.lock` suivi. Les migrations Alembic doivent atteindre le head courant avant le démarrage d'un environnement de production.

Le seed V1 est réservé au développement/test local avec `APP_ENV=test` ou `development` et `ENABLE_SEED=true`. Fournir à la requête de seed un mot de passe aléatoire généré pour cette exécution ou chargé depuis une variable locale ignorée. Il n'existe aucun mot de passe partagé ou par défaut; ne jamais réutiliser un secret de production. Désactiver le seed après le test.

## Configuration réseau corrigée

Une exécution de développement peut utiliser une adresse de boucle locale ou l'adresse d'émulateur adaptée à la machine, sans la documenter comme constante du projet. Une release doit recevoir une URL d'API HTTPS autorisée via `ENACTSPACE_API_URL`. Une URL HTTP/LAN ou un identifiant de terminal ne constitue jamais une configuration de release.

## Artefacts

`flutter build apk --debug` produit uniquement un artefact de développement. Il ne doit pas être distribué comme release. La distribution Android exige la signature externe et la garde de clé Enactus ESP; iOS exige les capacités, profils et certificats Apple approuvés. Consulter les gates externes dans le document mobile canonique.

## Validation actuelle

Utiliser le [test matrix](TEST_MATRIX.md) pour les commandes maintenues. Ce document historique ne doit pas servir à déduire que les tests, le déploiement, la signature ou le push physique ont été validés.
