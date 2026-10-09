# Lot 29 — dépendances et consolidation PostgreSQL
Date : 9 octobre 2026.

## Audit exécuté ici
pip-audit 2.10.1 a analysé l’environnement Python de tests, incluant les dépendances du backend et les outils d’audit. Le premier passage a signalé 12 entrées d’avis (certaines dupliquées) sur un seul paquet : pip 25.0.1. Le remplacement local par pip 26.2.1, déjà prévu par les sources de déploiement, a été suivi d’un second passage réussi : aucune vulnérabilité connue retournée. Aucun paquet applicatif n’a été modifié par ce lot ; Windows et la production sont inchangés. Une absence d’alerte ne constitue pas une preuve de sécurité et les dépendances résolues ici ne décrivent pas celles de l’image de production actuelle.

## Résultats PostgreSQL déjà consignés
Les contrôles PostgreSQL ne sont pas tous à refaire. Les rapports datés du 7 octobre indiquent :
- lot 9 : 51 tests, Veille et concurrence, réussis en 117,985 s ;
- lot 23 : 44 tests, Alumni et mentorat, réussis en 99,569 s ;
- lot 24 : 45 tests, première connexion, réussis en 127,004 s ;
- lot 25 : 32 tests, aide et avis, réussis en 96,837 s.

Ces éléments sont des preuves historiques lues dans le dépôt, pas de nouveaux essais exécutés le 9 octobre. Ils se recoupent et ne doivent pas être additionnés comme autant de scénarios distincts. Aucun Docker ni serveur PostgreSQL n’est disponible dans cet environnement. Un nouvel essai doit être motivé par des changements applicatifs, un doute non résolu ou la vérification de l’image finale.

## Suite
L’audit des dépendances Flutter, la revue manuelle globale, la recette Android/web, les tests de livraison des notifications et de paiement, le nettoyage ciblé des données de test et la préparation de la livraison finale restent ouverts. Aucun build, déploiement ni message réel envoyé.
