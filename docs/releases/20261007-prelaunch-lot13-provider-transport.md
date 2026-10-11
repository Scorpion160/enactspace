# Préproduction — lot 13 : échanges PayDunya et notifications
Date : 7 octobre 2026. Correctifs dans le dépôt de travail ; aucun déploiement ni build.

## Résultat
Les réponses du prestataire sont limitées à 1 Mio. Les redirections HTTP sont refusées pour éviter de transmettre les en-têtes d'authentification à une autre destination. Les liens de paiement doivent utiliser HTTPS, le domaine exact app.paydunya.com et le chemin de la facture correspondant au jeton retourné ; les identifiants intégrés, ports inattendus et fragments sont refusés.

Une erreur réseau lors de la vérification produit un message public clair, un statut 503 et une invitation à réessayer après 30 secondes. Le paiement reste en attente et aucune écriture comptable n'est créée. Les corps d'erreurs du prestataire et ses détails internes ne sont pas renvoyés aux utilisateurs.

Le callback PayDunya est limité à 64 Kio avant analyse, avec un quota persistant de 240 requêtes par adresse IP et par minute. Les tests vérifient notamment le refus avant lecture du corps en cas de quota dépassé ou de taille déclarée excessive, ainsi que la taille réellement reçue.

## Vérification
- SQLite : 79 tests réussis en 26,873 secondes.
- PostgreSQL : 11 tests réussis en 37,121 secondes, y compris les courses entre notifications et entre créations de facture.
- Aucun test ignoré. Les suites se recoupent : leurs nombres ne constituent pas un total de scénarios indépendants.
- Appels PayDunya simulés, données synthétiques et environnement isolé ; aucun paiement réel, courriel réel ni modification de production.
- Les conteneurs et le réseau propres à ce lot sont absents après exécution.
- Aucun build et aucun push Git.

## Limites et suite
Le délai réseau configuré est borné entre 1 et 30 secondes, avec contrôle du temps entre lectures et une limite d'attente asynchrone. Cette limite asynchrone ne tue pas instantanément un thread déjà lancé ; le délai socket et les contrôles de lecture restent nécessaires. Les tests de transport utilisent des doublures, pas un véritable serveur PayDunya.

Le paiement Mobile Money reste désactivé en production et les clés du mode test restent à configurer avant une recette réelle. La revue manuelle de l'ensemble du code n'est pas terminée. Il reste notamment la présentation client et canal de paiement, l'isolation des erreurs de rapprochement, les anciens helpers, les autres modules et rôles, les parcours Android/web, le nettoyage ciblé de la campagne de recrutement de test et la préparation finale du déploiement. La redirection des courriels de test reste en place.
