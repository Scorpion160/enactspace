# Préproduction — lot 16 : validation des réponses PayDunya
Date : 7 octobre 2026. Correctifs dans le dépôt de travail ; aucun build ni déploiement.

## Résultat
Une confirmation doit contenir une facture structurée et le jeton exact demandé. Les jetons malformés sont refusés avant l'appel réseau. Un statut absent, inconnu ou malformé ne devient plus silencieusement un paiement en attente.

Les statuts sont limités à 100 caractères et les références à 180 caractères, conformément aux champs de stockage existants. Les valeurs d'un mauvais type ou contenant des caractères de contrôle sont refusées. Une URL de reçu n'est plus utilisée comme identifiant de transaction.

Les montants confirmés doivent être positifs, entiers, finis et compatibles avec la capacité du champ Integer existant. Le plafond technique est 2 147 483 647 FCFA ; il ne s'agit pas d'une limite publiée par PayDunya. Ce contrôle est appliqué aux réponses du prestataire, aux montants explicitement demandés et au total calculé avant création de la transaction.

Seule la référence interne utile au rapprochement est conservée dans les données personnalisées retournées. Les données client arbitraires ne sont pas recopiées. Une référence interne contradictoire interdit l'enregistrement du règlement.

Le décodage JSON refuse les clés répétées, les constantes non finies et les structures trop imbriquées. Les formes invalides de hash, jeton ou facture dans un callback sont refusées. Les erreurs publiques contrôlées et la conservation du paiement sans écriture comptable restent en place.

## Vérification
- SQLite : 111 tests réussis en 30,680 secondes.
- PostgreSQL : 24 tests réussis en 60,494 secondes.
- Dix scénarios ajoutés, avec plusieurs valeurs malformées testées dans chaque scénario.
- Vérification du jeton retourné, du statut, du montant, de la devise, des références, des données internes, du JSON ambigu et des callbacks.
- Les tests de confirmation concurrente, de reprise des erreurs, de paiements tardifs et de migration continuent à réussir.
- Aucun test ignoré. Les suites se recoupent et ne constituent pas un total de scénarios indépendants.
- Syntaxe et git diff --check réussis. Ressources Docker propres au lot absentes après exécution.
- Appels prestataire simulés et données synthétiques ; aucun paiement ni courriel réel.

## Limites et suite
La recette PayDunya reste à faire avec les clés du mode test, notamment pour confirmer les types de chaque réponse et vérifier la compatibilité des références historiques. Mobile Money reste désactivé en production. Le head source demeure 20261007_0028 ; aucune migration n'a été appliquée en production.

La prochaine priorité est la revue des droits d'accès des autres modules, puis la répétition des migrations et les parcours complets téléphone/web. Le nettoyage ciblé de la campagne de recrutement de test reste à réaliser avec sauvegarde et contrôle des liens. La revue manuelle complète du code et la documentation finale restent ouvertes. La redirection des courriels de test est conservée.

Aucun build, déploiement, push Git ou changement de production.
