# Préproduction — lot 21 : répétition des migrations

Date : 7 octobre 2026. Aucun build, déploiement ou changement de production.

## Résultat vérifié

La structure réelle de la base en révision 20261006_0025 a été exportée sans données et restaurée dans un PostgreSQL isolé. Des lignes synthétiques ont ensuite permis de vérifier les migrations jusqu'à 20261007_0028.

Les 110 tables antérieures sont contrôlées par empreintes de leurs colonnes historiques. Leur contenu est conservé après la montée de version, le retour arrière et la nouvelle montée de version. Les nouveaux champs OTP et paiement mobile sont lisibles et modifiables avec l'ORM. Les trois écritures invalides testées sont refusées par les contraintes PostgreSQL. Une erreur injectée dans une transaction de migration annule correctement ses modifications. Une répétition de la montée de version ne change pas les données.

Une seconde base entièrement vide a également atteint le head par Alembic, sans raccourci metadata.create_all dans le test. Les migrations 0026, 0027 et 0028 gèrent maintenant les objets déjà créés par le démarrage historique fondé sur les modèles actuels ; les contrôles explicites rejettent les incompatibilités qu'ils couvrent.

Les conteneurs et le réseau nommés du lot sont absents après exécution. git diff --check réussit. Aucun courriel, push ou paiement réel. Aucune ligne de production copiée.

## Limites et suite

Ce contrôle porte sur la structure réelle et des données synthétiques. Il ne remplace pas une restauration complète d'une sauvegarde des données réelles ni la recette applicative sur téléphone et web. Le retour arrière retire les nouveaux champs de sécurité ; leurs valeurs nouvelles ne survivent pas à cette suppression, tandis que les données historiques restent conservées.

La création administrative des comptes doit encore être alignée sur l'exigence réelle d'un nom d'utilisateur non nul. La revue manuelle intégrale du dépôt demeure inachevée. La production reste en révision 20261006_0025 ; aucune migration n'y a été exécutée.
