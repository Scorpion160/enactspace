# EnactSpace — préparation de maintenance sans interruption de production

**État : correctifs préparés dans la branche `feature/safe-maintenance-20261114`. Pas de déploiement.**

La production est utilisée par les membres. **Interdictions pour ce lot de préparation :** pas de `docker compose up`, `down`, `restart`, `build` sur le VPS ; pas de mise à jour de `/opt/enactspace/web`, pas de migration, écriture SQL, fusion de comptes, envoi de courriels ou activation de paiement.

## 1. Risque de confusion des images Docker

L'application utilise des images distinctes du fichier Compose de base. Celui-ci contient un `build:` pour l'API et ne définit pas directement les trois workers. La configuration opérationnelle assemble plusieurs fichiers d'override. Un futur `docker compose up` mal ciblé pourrait redémarrer la mauvaise version.

**Correctif préparé :** `tools/verify_vps_compose_alignment.py` est un garde-fou en lecture seule, **sans import Docker ni action réseau**, qui compare deux inventaires JSON préparés à l'avance.

Pour une maintenance future, sur un poste autorisé, collecter les informations **en lecture seule** :

```bash
docker compose -p enactspace \
  -f /opt/enactspace/app/deploy/docker-compose.vps.yml \
  -f /opt/enactspace/staging/chat-mail-hotfix-20261111-46668d1f/hotfix.override.yml \
  -f /opt/enactspace/staging/chat-search-20261114/release.override.yml \
  config --format json > effective-compose.json

docker inspect enactspace_backend enactspace_email_worker \
  enactspace_push_worker enactspace_veille_worker > current-containers.json

python3 tools/verify_vps_compose_alignment.py \
  --compose-json effective-compose.json \
  --containers-json current-containers.json
```

La vérification refuse les images différentes, services absents ou arrêtés, les reconstructions implicites et les identifiants d'images divergents. Elle ne répare ni ne redémarre rien : l'alignement réel doit être établi **avant** tout futur déploiement. Le contrôle porte sur la configuration actuelle, pas sur la validité d'une candidate de version future.

## 2. Cache du Chat

Les synchronisations Chat interrogent périodiquement les discussions et messages. Auparavant, chaque résultat provoquait une écriture du cache chiffré même si les données étaient strictement inchangées.

Le service conserve à présent une représentation JSON comparable des discussions et messages. Il continue à actualiser le cache mémoire de session mais **n'écrit dans le stockage chiffré que si le contenu a changé**. Les modifications de contenu, les compteurs non lus, les réactions et les détails des discussions sont couverts par les données `toJson()` du modèle ; le format du cache chiffré demeure inchangé.

La synchronisation réseau elle-même reste inchangée. Il ne faut pas considérer ce correctif comme la solution à toute latence sans recette instrumentée en navigateur authentifié. Il réduit les écritures inutiles dans le stockage local.

## 3. Tests

- 5 tests synthétiques du garde-fou Compose.
- Tests Flutter de non-réécriture du cache sur données identiques, puis de réécriture en cas de modification.
- Vérification de la restauration du contenu après redémarrage logique de ChatService et de l'isolement du cache entre comptes.
- Tests de confidentialité et des commandes de groupe Chat existants.

**Recommandation de livraison :** fusionner cette branche uniquement après validation de la CI et planifier une fenêtre d'intervention lorsque personne n'utilise la plateforme. Vérifier ensuite le nouveau commit sur un environnement de recette, puis préparer les sauvegardes et un plan de retour arrière indépendants de la production.
