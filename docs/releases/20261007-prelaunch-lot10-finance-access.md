# Préproduction — lot 10 : accès Finance et annulations
Date : 7 octobre 2026. Changements locaux, non déployés.

## Corrections
Le contrôle partagé de gestion Finance exige maintenant un statut actif, un compte activé, un e-mail vérifié et un rôle financier autorisé. Il s'applique aux accès de gestion ainsi qu'aux contrôles des paiements, reçus, transactions Mobile Money et justificatifs qui utilisent ce contrôle. Un ancien rôle administrateur, Team Leader ou financier conservé sur un compte Alumni ne suffit plus.

Les destinataires des alertes de paiement sont filtrés avec les mêmes conditions de compte actif et vérifié. Les Alumni conservent leurs frais, compte, statistiques personnelles et paiements. Ils peuvent déclarer un paiement pour eux-mêmes, annuler leur déclaration non validée et consulter leur reçu après validation.

Les identifiants des routes Finance sont typés UUID. Un identifiant mal formé produit une réponse de validation 422 avant la requête SQL. Le helper de lecture d'un paiement renvoie 404 pour un identifiant invalide.

L'annulation d'un frais verrouille maintenant sa ligne. Un frais déjà annulé est retourné sans nouvelle réduction du solde, sans nouvelle notification et sans nouvelle inscription d'annulation dans son descriptif. L'annulation d'un frais payé reste refusée.

## Vérification
- 63 tests de régression sur SQLite : réussite, 18,182 secondes, aucun test ignoré.
- 14 tests sur PostgreSQL 16 : réussite, 45,366 secondes, aucun test ignoré.
- Les 12 scénarios spécifiques Finance sont exécutés sur les deux bases ; les résultats ne doivent pas être présentés comme 77 scénarios fonctionnels distincts.
- Deux scénarios PostgreSQL supplémentaires lancent des requêtes simultanées : double annulation d'un frais et double validation d'un paiement. Le solde est réduit une seule fois dans le premier ; un seul paiement comptabilisé et une seule entrée de caisse sont constatés dans le second.
- Les tests couvrent le refus des droits de gestion aux Alumni malgré un ancien rôle, les accès personnels conservés, les responsables actuels, le refus d'auto-validation du financier, les destinataires des alertes, les transactions et preuves privées, les identifiants invalides et les annulations répétées.
- Contrôle des différences Git sans erreur d'espacement. Les ressources PostgreSQL et réseau temporaires nommées du lot ont été contrôlées absentes.

Les tests utilisent des données synthétiques, une base jetable et des notifications simulées. Les mails et push sont désactivés. Aucun build, déploiement, push Git ou nettoyage des données réelles n'a été effectué.

## Relecture et limites
Les routes Finance, les dépendances d'accès et les nouveaux tests ont été relus. La relecture globale du dépôt n'est pas terminée. Cette suite serveur ne valide pas encore l'interface Finance sur téléphone et navigateur.

La revue Finance doit encore approfondir les pièces jointes liées aux paiements, les exports CSV, la validation des montants et références, les créations de compte simultanées et les déclarations simultanées avec preuves ou références identiques. Les restrictions de test des mails en production restent conservées jusqu'au basculement final validé.
