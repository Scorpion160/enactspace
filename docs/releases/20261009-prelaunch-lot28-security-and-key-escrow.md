# Lot 28 — récupération et tests ciblés, 9 octobre 2026

## Résultats constatés

L’utilisateur a intégré le correctif de secours de clé du commit 39142a6a4f1b87757a8a0b57cbc4c939886e360d dans son dépôt Windows après contrôle des empreintes et copie des fichiers précédents. Le résultat de l’export confirme portable_encrypted_key_created=true et secret_printed=false pour la sauvegarde 20261008T094513Z_fcf746. L’outil vérifie le déchiffrement et le contenu avant écriture du secours.

La copie du secours chiffré vers D:\EnactSpace-Secours a été vérifiée par comparaison SHA-256. Get-Partition indique C sur le disque 0 et D sur le disque 1. La clé USB E a présenté HealthStatus Warning et une copie échouée : elle ne constitue pas une copie validée. Aucun second PC Windows n’est disponible ; l’import depuis un autre profil ou poste, la remise à un second détenteur et la restauration sur hôte vierge restent en attente.

## Tests backend isolés

Le 9 octobre, 22 tests de test_prelaunch_security_boundaries et test_security_mobile_foundation ont réussi en 0,970 seconde. Un autre lot de 162 exécutions a réussi en 41,230 secondes pour :
- test_prelaunch_first_access
- test_prelaunch_task_boundaries
- test_prelaunch_alumni_boundaries
- test_veille
- test_recruitment_questionnaire
- test_recruitment_history
- test_recruitment_rubric

Les comptes incluent les tests hérités découverts par unittest et ne représentent pas nécessairement autant de scénarios distincts. Exécution Python 3.12, SQLite en mémoire, APP_ENV=test, création automatique des tables désactivée, secret éphémère et envois e-mail/push désactivés. Aucun appel de production, build ou déploiement effectué.

Un avertissement concerne la dépréciation httpx/Starlette. Un autre concerne une clé courte utilisée par un scénario de test JWT ; il ne constitue pas un contrôle de la clé de production.

## Portée et suite

Ces résultats valident les assertions des suites existantes ; ils ne prouvent pas une revue exhaustive du code ni une résistance générale aux intrusions. Restent les suites PostgreSQL, l’audit des dépendances, les contrôles de configuration de production, la recette Android/web, la livraison des notifications en test, le nettoyage des données de test et la préparation du déploiement final. La redirection des e-mails de test doit rester active jusqu’à validation de la bascule.
