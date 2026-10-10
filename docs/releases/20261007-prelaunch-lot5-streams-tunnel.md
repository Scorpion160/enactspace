# Préparation à la mise en service — lot 5 : flux entrants et tunnel public

Date : 7 octobre 2026. Début : 11:21 UTC.

## Résultats

108 tests SQLite réussis en 45,960 secondes et 5 tests PostgreSQL réussis en 6,892 secondes. Ces suites recouvrent celles des lots précédents ; les résultats ne sont pas des totaux cumulatifs.

La protection ASGI intervient maintenant avant le traitement des formulaires et des pièces jointes. Un quota réseau épuisé ou une taille annoncée excessive refuse la demande avant lecture de son contenu. La taille réelle est également contrôlée pendant la lecture : un Content-Length absent ou mensonger ne permet pas de dépasser le plafond. Les longueurs invalides ou multiples sont refusées.

Le compteur réseau est incrémenté une seule fois par demande, malgré le contrôle complémentaire du parcours. Les réponses déjà commencées ne sont pas remplacées par une seconde réponse d'erreur.

Les candidatures multipart et JSON partagent maintenant leur quota par identifiant. Le lecteur multipart réutilise le formulaire mis en cache ; les fichiers restent traités par leurs validateurs habituels.

## Plafonds préparés

| Demande | Taille totale maximale |
|---|---:|
| Connexion, codes et suivi de candidature | 16 Kio |
| Demande d'adhésion | 64 Kio |
| Candidature JSON | 128 Kio |
| Candidature avec fichiers | 32 Mio |
| Autres écritures | 501 Mio |

Les limites propres à chaque pièce continuent de s'appliquer : le plafond de 32 Mio laisse la place aux trois pièces de 10 Mio et à l'enveloppe multipart. La limite générale préserve la limite historique de 500 Mio du stockage générique. Ces plafonds ne garantissent pas à eux seuls la résistance à un déni de service distribué.

## Vérification du tunnel

Les journaux de cloudflared-enactspace.service confirment le domaine api-enactspace.kerunjombor.net et les ports 18002 et 18080. Le backend publie son port uniquement sur loopback. Les relevés ne conservent aucun jeton de tunnel ni donnée personnelle.

Les sondes sans agent applicatif ont reçu un 403 avec des en-têtes Cloudflare. Les sondes avec un agent de navigateur et un agent Dart ont reçu un HTTP 200. Cela établit l'accessibilité du point de santé pour ces sondes, sans constituer une recette authentifiée complète du navigateur ou du téléphone. Le pair réseau observé lors de la sonde corrélée est consigné dans les preuves JSON.

## État et suite

Les sources, empreintes et résultats sont enregistrés avec le registre de revue. Aucun build, déploiement, courriel ou push réel ni suppression de données effectué. Les nouvelles protections ne sont pas encore en production.

La revue exhaustive du code, les autres permissions, l'audit des dépendances, la recette fonctionnelle complète et le nettoyage ciblé restent à terminer. Les réglages de proxy devront être contrôlés de nouveau après leur déploiement, avec l'adresse du visiteur réellement interprétée et les tentatives de falsification.
