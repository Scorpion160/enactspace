# Préproduction — lot 15 : confirmations tardives et reprise des vérifications
Date : 7 octobre 2026. Correctifs dans le dépôt de travail ; aucun build ni déploiement.

## Résultat
L'actualisation interroge le prestataire même si le délai local de la facture est dépassé. Cette date ne suffit plus à déclarer un échec. Une confirmation réussie, avec montant et référence cohérents, reste enregistrée une seule fois. Une réponse « pending » conserve le paiement en attente.

Une nouvelle initiation portant sur les mêmes dettes et le même montant réutilise la facture active, même après son délai local, tant que son statut n'a pas été clarifié. Cela évite de créer une seconde facture encore susceptible d'être réglée.

Le rapprochement reprend les transactions actives sans règlement et les factures récentes marquées expirées, annulées ou échouées lorsqu'elles possèdent un jeton prestataire. La fenêtre de reprise est de sept jours par défaut. Les factures plus anciennes restent vérifiables par actualisation ciblée et par callback ; elles ne sont pas parcourues automatiquement dans cette fenêtre.

Une date de tentative, last_verification_attempt_at, est distincte de last_verified_at. Après une erreur, seules les informations de tentative sont enregistrées : aucune vérification réussie ni écriture comptable n'est inventée. Le rapprochement attend soixante secondes par défaut avant de reprendre cette facture et donne priorité à celles jamais tentées, puis aux tentatives les plus anciennes. Une facture indisponible ne monopolise donc plus les appels suivants.

## Configuration et migration
- PAYMENT_RECONCILIATION_LOOKBACK_DAYS : 7 par défaut, autorisé entre 1 et 365.
- PAYMENT_RECONCILIATION_RETRY_SECONDS : 60 par défaut, autorisé entre 1 et 3 600.
- Au plus 100 factures par appel ; le rapprochement reste déclenché par la route d'administration ou le script existant. Ce lot n'ajoute aucun ordonnanceur en production.
- Migration source 20261007_0028 après 20261007_0027 : colonne nullable et index, sans réécriture des transactions existantes. Le nouveau champ de lecture est facultatif.
- La CI attend le nouveau head unique. Les migrations 0026 à 0028 restent à appliquer lors du déploiement final après répétition complète depuis la version actuellement déployée.

## Vérification
- SQLite : 101 tests réussis en 29,443 secondes.
- PostgreSQL : 22 tests réussis en 54,349 secondes.
- Six scénarios ajoutés : confirmation après délai local, attente réelle malgré ce délai, récupération des factures récentes fermées sans callback, rotation et délai de reprise, réutilisation de facture active et migration aller-retour conservant les autres données.
- Le head unique 20261007_0028 a été vérifié dans l'environnement isolé.
- Aucun test ignoré ; les suites se recoupent et ne constituent pas un total de scénarios indépendants.
- Syntaxe et git diff --check réussis sur les fichiers modifiés. Ressources de test Docker absentes après exécution.
- Données synthétiques, appels PayDunya simulés, courriels et push désactivés dans les tests.

## Limites et travaux restants
La recette avec PayDunya reste à réaliser après configuration des clés du mode test ; Mobile Money demeure désactivé en production. Les champs retournés par le prestataire nécessitent encore une revue de leurs limites de type et de longueur. Le fonctionnement visuel et la reprise de paiement sur téléphone et web restent à vérifier avec la version finale.

La revue manuelle de l'ensemble du code n'est pas terminée. Les autres modules et rôles, la répétition complète des migrations depuis la version déployée, le nettoyage ciblé des candidatures de test et la préparation du déploiement restent ouverts. La redirection des courriels de test est conservée.

Référence du fonctionnement prestataire : [documentation PayDunya HTTP/JSON](https://developers.paydunya.com/doc/FR/http_json). La validation comptable dépend de la confirmation serveur, pas d'une date locale.

Aucune modification de production, aucun paiement ni courriel réel, aucun build et aucun push Git.
