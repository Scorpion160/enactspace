# EnactSpace V1.1 - Configuration PayDunya

## Variables backend

Les variables restent uniquement dans l'environnement serveur:

```env
MOBILE_MONEY_ENABLED=true
MOBILE_MONEY_PROVIDER=paydunya
PAYDUNYA_MODE=test
PAYDUNYA_MASTER_KEY=
PAYDUNYA_PUBLIC_KEY=
PAYDUNYA_PRIVATE_KEY=
PAYDUNYA_TOKEN=
PAYDUNYA_CALLBACK_URL=https://API_VPS/api/payments/paydunya/ipn
PAYDUNYA_RETURN_URL=https://APP_OU_WEB/payment/return
PAYDUNYA_CANCEL_URL=https://APP_OU_WEB/payment/cancel
PAYDUNYA_ALLOWED_CHANNELS=wave-senegal,orange-money-senegal
PAYDUNYA_TIMEOUT_SECONDS=15
PAYMENT_CURRENCY=XOF
PAYMENT_TRANSACTION_TTL_MINUTES=30
PAYMENT_RECONCILIATION_ENABLED=true
```

## Sandbox

1. Creer ou recuperer une application PayDunya sandbox.
2. Renseigner les quatre cles dans `.env` sur le backend.
3. Garder `PAYDUNYA_MODE=test`.
4. Demarrer le backend.
5. Creer une dette Finance.
6. Depuis l'app, lancer le paiement Mobile Money.
7. Verifier que l'URL checkout s'ouvre en HTTPS.
8. Simuler ou realiser le paiement sandbox.
9. Verifier l'IPN, le statut `successful`, le recu et la notification.

## Live

Ne passer a `PAYDUNYA_MODE=live` qu'apres:

- compte marchand active;
- domaine API public en HTTPS;
- IPN accessible depuis Internet;
- tests sandbox termines;
- backup base de donnees;
- validation du Financier et du Team Leader.

Les cles live ne doivent jamais etre committees ni envoyees au frontend.
