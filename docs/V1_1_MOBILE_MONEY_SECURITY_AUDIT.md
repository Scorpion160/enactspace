# EnactSpace V1.1 - Audit securite Mobile Money

## Protections implementees

- Aucun secret PayDunya dans Flutter.
- Configuration PayDunya lue uniquement cote backend.
- Montant recalcule depuis `fees`.
- Devise normalisee et limitee a XOF.
- Dette payable seulement par son membre, sauf assistance Finance/Admin/Team Leader.
- Hash IPN PayDunya compare en temps constant avec SHA-512 de la Master Key.
- `return_url` ne confirme jamais un paiement.
- Creation de `Payment` uniquement apres confirmation backend.
- Idempotence: une transaction `successful` avec `payment_id` ignore les callbacks dupliques.
- Journal `mobile_money_transaction_events`.
- Timeout HTTP provider.
- Reconciliation serveur disponible.
- References provider masquees dans le recu.

## Points de vigilance

- La verification IPN depend du protocole PayDunya actif. Revalider avec la documentation officielle avant le live.
- Les remboursements automatiques restent desactives en V1.1.
- Les tests sandbox reels necessitent des cles PayDunya non committees.
- Les tables sont creees par `Base.metadata.create_all`; pour une production PostgreSQL mature, prevoir des migrations explicites.

## Reponse incident

1. Desactiver `MOBILE_MONEY_ENABLED`.
2. Garder le fallback preuve manuelle.
3. Exporter les transactions Mobile Money concernees.
4. Comparer PayDunya, `mobile_money_transactions`, `payments` et `payment_allocations`.
5. Corriger uniquement avec motif, audit et validation Finance/Admin.
