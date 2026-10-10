# Préparation à la mise en service — lot 4 : limites des accès publics

Date : 7 octobre 2026. Début : 10:57 UTC.

## Point d'entrée

Un service spécifique cloudflared-enactspace.service est présent en mode de configuration distante. Le fichier cloudflared/config.yml examiné auparavant appartient au service HydroPilot : son absence de routes EnactSpace ne caractérise donc pas l'API EnactSpace. Aucun jeton de tunnel, contenu de variable secrète ou identifiant personnel n'a été conservé dans les relevés.

Le backend publie son port uniquement sur 127.0.0.1:18002. Sa passerelle Docker actuelle est 172.20.0.1. Le paramètre FORWARDED_ALLOW_IPS préparé dans Compose limite la confiance à cette passerelle et aux adresses loopback. La confirmation du pair réellement observé par une requête publique reste obligatoire avant déploiement : la sonde publique de ce lot n'a pas abouti. Aucune configuration de production n'a été modifiée.

## Protections préparées

Les compteurs PostgreSQL sont partagés entre processus. Ils sont incrémentés de manière atomique et enregistrés indépendamment de la transaction métier : une réponse d'échec ne remet pas le compteur à zéro.

| Parcours | Limite par adresse réseau | Limite par identifiant normalisé |
|---|---:|---:|
| Connexion JSON ou formulaire | 60 par minute | 20 par 15 minutes |
| Demande d'un nouveau code | 20 par minute | 4 par 15 minutes |
| Confirmation du code | 30 par minute | 20 par 15 minutes, plus 5 erreurs par code |
| Demande d'adhésion | 60 par minute | 4 par 15 minutes |
| Dépôt de candidature | 60 par minute | 4 par 15 minutes pour JSON |
| Suivi de candidature | 60 par minute | 30 par 15 minutes |

Les dépôts multipart avec fichiers sont limités par adresse ; ils ne sont pas limités par identifiant dans ce lot. Les limites réseau ont été choisies pour laisser plusieurs étudiants candidater derrière une connexion partagée. Le dimensionnement devra être confirmé par la recette de charge.

Les identifiants et adresses réseau sont représentés par une empreinte HMAC : ils ne sont pas conservés en clair dans la table des compteurs. Un nettoyage borné supprime les compteurs expirés. Les accès limités renvoient 429 avec Retry-After et un message lisible. Une indisponibilité du stockage refuse l'accès sensible avec une réponse 503, sans erreur technique exposée.

La migration 20261007_0027 ajoute la table de compteurs et son index. Elle reste à appliquer après 20261007_0026 lors du déploiement final.

## Tests

La suite SQLite complète et les tests PostgreSQL sont consignés dans le fichier JSON de preuves associé après réussite. Ils couvrent les échecs répétés, la persistance du compteur, l'expiration, le nettoyage, les identifiants normalisés, le partage du quota entre connexion JSON et formulaire et les en-têtes falsifiés. Le test PostgreSQL lance vingt demandes simultanées pour un quota de cinq : cinq sont autorisées et quinze refusées. Les migrations sont vérifiées dans une base jetable.

Les premiers essais ont détecté une lecture répétée du flux du formulaire ; le code utilise maintenant le formulaire mis en cache par FastAPI. Le test de proxy utilise une application ASGI avec un cycle de vie valide.

## Limites et suite

Ces limites ne constituent pas une protection complète contre un déni de service distribué. Le contrôle par dépendance intervient après certaines étapes de parsing de FastAPI : les limites de taille et de débit avant parsing restent à vérifier au point d'entrée. La confiance proxy, les campagnes massives derrière une même adresse et les seuils de charge doivent encore être validés en conditions réelles.

Aucun build, déploiement, courriel ou push réel, nettoyage de campagne ni changement des destinataires de test effectué. La revue complète du code reste en cours.

Références techniques :
- https://www.postgresql.org/docs/current/sql-insert.html
- https://www.uvicorn.org/settings/
- https://developers.cloudflare.com/fundamentals/reference/http-headers/

Résultat final : 100 tests SQLite et 5 tests PostgreSQL réussis. git diff --check : 0 (0 = réussi).
