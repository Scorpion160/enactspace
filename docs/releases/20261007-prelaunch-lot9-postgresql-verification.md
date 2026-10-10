# Préproduction — lot 9 : vérification PostgreSQL
Date : 7 octobre 2026. Aucun déploiement, build ou push.

## Résultat
Les 51 tests PostgreSQL ont réussi, sans test ignoré, en 117,985 secondes. Le code applicatif des lots précédents a été chargé dans le conteneur de test ; le service de production n'a pas été remplacé.

La suite couvre les protections de réinitialisation de mot de passe, les quotas, la conservation du dernier administrateur actif, les parcours de Veille et les écritures concurrentes. Les validations concurrentes, la création simultanée d'un blocage et la modification concurrente des paramètres acceptent une écriture et refusent l'autre avec un conflit. Le test de réplica vérifie le verrou transactionnel du planificateur.

## Diagnostic du délai dépassé
Le premier essai a dépassé sa limite de 180 secondes alors que les tests continuaient à progresser. L'observation de la base temporaire montrait une création de table active, sans processus bloquant à cet instant. Le schéma complet était recréé pour chaque scénario. Cette observation ne constitue pas une preuve d'absence de tout blocage possible dans l'application.

La préparation crée maintenant un schéma aléatoire une seule fois par classe de tests. Toutes ses tables sont vidées entre les scénarios, avec des noms qualifiés par le schéma. Les mêmes utilisateurs de test et parcours sont reconstruits à chaque scénario. Les tests hérités et les quatre scénarios spécifiques de concurrence ont été conservés. Le schéma est supprimé en fin de classe.

## Isolation et limites
PostgreSQL 16 fonctionne dans un conteneur jetable et un réseau interne dédiés. Les URL de test refusent les bases qui ne sont pas locales et dont le nom ne porte pas le préfixe réservé aux tests. Les mails et notifications push sont désactivés. Les délais sont bornés : verrou 8 secondes, requête SQL 15 secondes et suite 180 secondes. Les journaux progressifs et les sorties partielles en cas de délai dépassé sont conservés.

Les conteneurs et réseaux nommés des deux essais du lot 9 ont été contrôlés absents après exécution. Aucune candidature, campagne ou donnée réelle du club n'a été supprimée.

SQLAlchemy émet un avertissement de tri concernant les dépendances croisées des tables attendance_records et fees. Cet avertissement concerne la préparation du test : toutes les tables du schéma sont transmises ensemble à TRUNCATE CASCADE. Il n'a empêché aucun des 51 scénarios de réussir.

## Relecture et suite
La préparation PostgreSQL, les parcours de test Veille et le planificateur ont été relus. La revue du module finance reste partielle ; le contrôle des anciens rôles après une transition Alumni doit être renforcé et testé dans le prochain lot. La relecture manuelle de l'ensemble du dépôt n'est pas terminée.

Le délai dépassé signalé au lot 8 dispose désormais d'un résultat PostgreSQL complet dans ce rapport. Les résultats précédents restent datés dans leurs rapports respectifs. Ces tests serveur ne remplacent pas les essais sur téléphone et navigateur.

Restent également les autres contrôles d'accès, les parcours réels Android/web, le nettoyage ciblé des données de test, la documentation finale et la préparation du déploiement. La redirection des mails de test est conservée jusqu'au basculement final validé.
