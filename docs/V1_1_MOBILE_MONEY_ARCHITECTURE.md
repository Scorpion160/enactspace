# EnactSpace V1.1 - Architecture Mobile Money

## Principe

Le backend est la source de verite. Flutter ne transmet jamais le montant final, ne stocke aucune cle PayDunya et ne valide jamais un paiement localement.

## Flux principal

1. Le membre choisit une ou plusieurs dettes Finance.
2. `POST /api/finance/mobile-money/initiate` verifie le proprietaire, recalcule le reste a payer et cree une transaction interne.
3. Le provider cree une facture checkout PayDunya et renvoie une URL HTTPS.
4. L'utilisateur paie sur le checkout externe.
5. PayDunya appelle `POST /api/payments/paydunya/ipn`.
6. Le backend verifie le hash, le montant, la devise et l'idempotence.
7. Le backend cree un `Payment` valide, alloue les dettes, cree le recu et notifie le membre.
8. Le refresh ou le rapprochement peut confirmer une transaction si l'IPN est retarde.

## Statuts internes

- `created`
- `pending`
- `processing`
- `successful`
- `failed`
- `cancelled`
- `expired`
- `refunded`

## Tables principales

- `mobile_money_transactions`: transaction provider avant validation Finance.
- `mobile_money_transaction_events`: journal d'audit provider, doublons, erreurs, confirmations.
- `payments`: paiement Finance cree seulement apres confirmation backend.
- `payment_allocations`: repartition sur les dettes selectionnees.

## Providers

- `manual_proof`: fallback historique par preuve manuelle.
- `mock`: tests locaux sans provider reel.
- `paydunya`: checkout heberge PayDunya sandbox/live.
- `wave_direct` et `orange_money_direct`: reserves pour une future integration directe.
