# Préproduction — lot 19 : rôles et changement d'année

Date : 7 octobre 2026. Correctifs dans le dépôt de travail ; aucun build ni déploiement.

## Résultat

La gestion générale des rôles relit et verrouille désormais le compte de l'auteur, le membre concerné et les titulaires actuels des responsabilités exclusives Team Leader et SG. Les utilisateurs sont verrouillés dans l'ordre de leurs UUID, puis les rôles exclusifs dans un ordre stable. Un compte Alumni, suspendu, non vérifié ou avec un profil incohérent ne peut pas gérer les rôles grâce à une ancienne responsabilité conservée. Les autorisations sont recalculées après cette relecture.

Si un nouveau titulaire de responsabilité exclusive apparaît pendant la préparation des verrous, la modification est refusée avec une invitation à actualiser et réessayer. La protection du dernier administrateur reste testée, y compris lors de deux retraits simultanés.

La création d'un rôle absent utilise une insertion qui accepte le conflit de nom sur PostgreSQL et SQLite, puis relit le rôle obtenu. Deux créations simultanées donnent le même rôle, sans doublon. Les affectations de pôles et projets utilisent cette fonction commune.

La création et l'activation des années exigent un compte opérationnel actif et vérifié. Le contexte de l'interface ne présente plus la gestion des années comme disponible pour un Alumni conservant un ancien rôle. Les identifiants d'activation doivent être des UUID.

## Correction du profil académique

La confirmation académique prenait auparavant le verrou de changement d'année avant celui de l'utilisateur. La gestion des années prend désormais le verrou utilisateur avant celui de l'année : l'ordre inverse présent dans la confirmation pouvait donc produire un blocage réciproque. La confirmation suit maintenant le même ordre et exige un compte Enacteur ou Enactrice actif et vérifié. Les Alumni conservent leur consultation ; la confirmation d'un cursus pour l'année courante leur est refusée.

Le test PostgreSQL engage une création d'année et une confirmation académique par le même SG pendant qu'un verrou de changement d'année est détenu par une troisième transaction. Après libération de ce verrou, les deux opérations aboutissent.

## Fonctionnement du changement d'année

La direction prépare une année puis l'active en précisant l'année courante affichée. Si celle-ci a changé entretemps, l'activation est refusée. La bascule archive l'ancienne année et conserve une seule année courante. Les chevauchements de dates, retours vers une année archivée et noms d'années dupliqués restent refusés.

Les tâches, leurs responsables, les appartenances aux pôles et projets et les profils académiques restent conservés. Une deuxième activation de la même année ne recrée pas les notifications. Chaque membre confirme ensuite son cursus pour la nouvelle année ; son historique conserve les confirmations précédentes et distingue progression, redoublement et changement de cursus. Une confirmation portant sur l'ancienne année ou une seconde confirmation pour la même année est refusée.

La bascule d'année ne fait pas passer automatiquement un membre en Alumni. Ce parcours reste une action distincte. Les tests existants vérifient le passage des profils Enacteur et Enactrice dans l'annuaire Alumni, la conservation des préférences de confidentialité et l'absence de profils en double.

## Vérification finale

- SQLite : **76 tests réussis en 29.265 secondes**.
- PostgreSQL : **30 tests réussis en 95.74 secondes**.
- Huit scénarios portables ajoutés et quatre scénarios de concurrence ajoutés sur PostgreSQL.
- Les suites finales couvrent aussi les règles opérationnelles, tâches, rôles, progression académique et les tests existants Alumni, années et catalogues.
- Quatre concurrences nouvelles : création initiale de rôle, activations d'années, suspension pendant une affectation de rôle, création d'année avec confirmation académique.
- Les nombres des suites se recoupent et ne sont pas cumulables comme des scénarios indépendants. Aucun test ignoré dans les suites finales.
- Syntaxe et git diff --check réussis ; conteneurs et réseau propres au lot absents après exécution.
- Données synthétiques, tests isolés, courriels et push désactivés. Le premier passage de 80 tests SQLite et 28 tests PostgreSQL a été suivi d'une vérification finale après la correction de l'ordre des verrous ; seuls les résultats finaux sont mis en avant.

## Limites et suite

Les autres routes de cycle de vie et les interactions de verrous avec les autres modules nécessitent encore une revue. Les tests backend ne remplacent pas la recette du parcours sur téléphone et web. La revue manuelle intégrale du dépôt reste inachevée.

La répétition complète des migrations depuis le head de production 20261006_0025 vers 20261007_0028, le nettoyage ciblé des données de recrutement de test, la recette Android/web et la documentation finale restent ouverts. Aucune nouvelle migration dans ce lot. La redirection des courriels de test reste en place.

Aucun build, déploiement, changement de production, paiement réel, courriel réel ou push Git.
