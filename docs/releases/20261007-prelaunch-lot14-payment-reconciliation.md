# Préproduction — lot 14 : rapprochement des paiements
Date : 7 octobre 2026. Correctifs enregistrés dans le dépôt de travail, sans build ni déploiement.

## Ce qui change
Le rapprochement traite et enregistre chaque facture séparément. Une indisponibilité réseau ou une confirmation incohérente laisse la facture sans règlement et permet de vérifier les suivantes. Une erreur survenant pendant une écriture comptable annule toutes les modifications de cette facture. Les confirmations déjà enregistrées restent acquises si une facture ultérieure rencontre une erreur inattendue ; cette erreur est remontée au lieu d'être masquée.

Le bilan conserve les nombres vérifiés, confirmés, expirés, échoués et en attente. Il ajoute les annulations, remboursements et vérifications différées. Parmi ces dernières, « unavailable » correspond à une indisponibilité et « needs_review » à une confirmation incohérente ou une transaction introuvable. Ces deux valeurs détaillent « deferred » ; il ne faut pas les additionner une seconde fois au total.

Les informations client disponibles sont placées dans invoice.customer pour préremplir la page de paiement. Le choix Wave ou Orange Money est transmis dans invoice.channels, après contrôle de la configuration autorisée. Les champs facultatifs vides sont omis et la référence interne de transaction ne peut pas être remplacée par les données personnalisées.

Les sept anciens helpers du callback ont été retirés après recherche de leurs usages dans les sources backend et frontend. La route utilise le service partagé, avec ses contrôles de confirmation et ses verrous, pour éviter des traitements concurrents différents.

## Vérification
- SQLite : 95 tests réussis en 25,806 secondes.
- PostgreSQL : 16 tests réussis en 36,622 secondes.
- Neuf scénarios ajoutés : cinq sur le rapprochement et quatre sur la facture envoyée au prestataire.
- Contrôles des erreurs réseau, confirmations incohérentes, rollback après début d'écriture, conservation d'une confirmation antérieure, interdiction aux membres de lancer le rapprochement, choix du canal et référence interne.
- Les tests de courses entre callbacks et entre créations de facture restent réussis.
- Aucun test ignoré. Les suites se recoupent : les nombres ne constituent pas un total de scénarios indépendants.
- Vérification de syntaxe et git diff --check réussies sur les fichiers modifiés.
- Appels prestataire simulés, données synthétiques et environnements isolés. Les ressources Docker propres au lot sont absentes après exécution.

## Conditions de fonctionnement
Les deux appelants actuels du rapprochement — route d'administration et script dédié — lui fournissent leur session de travail. Le service effectue désormais un commit par facture : un futur appelant doit respecter ce fonctionnement et ne pas lui confier d'autres modifications non enregistrées. Le traitement reste borné à 100 factures par appel.

L'envoi des champs client et des canaux respecte la structure publiée par PayDunya : [factures HTTP/JSON](https://developers.paydunya.com/doc/FR/http_json) et [opérateurs disponibles](https://developers.paydunya.com/doc/FR/introduction). Les tests vérifient le contenu préparé, pas son acceptation par un compte réel.

## Ce qui reste ouvert
Mobile Money reste désactivé en production et les clés du mode test ne sont pas configurées pour une recette réelle. Il reste à examiner les confirmations tardives, la rotation d'une file de vérifications différées et les limites des champs retournés par le prestataire. Les autres modules et rôles, la revue intégrale du code, les tests Android/web, le nettoyage ciblé des candidatures de test et la préparation finale du déploiement restent à terminer.

Aucune modification de production, aucun paiement ni courriel réel, aucun build et aucun push Git. La redirection des courriels de test est conservée.
