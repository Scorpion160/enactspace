# EnactSpace V1.1 - Checklist production Mobile Money

## VPS

- Domaine API public.
- HTTPS valide.
- PostgreSQL.
- Sauvegardes.
- `.env` serveur avec permissions strictes.
- Logs surveilles.
- Backend lance comme service.
- Nginx ou reverse proxy configure.

## PayDunya

- Compte Business active.
- Application live creee.
- Cles live renseignees uniquement sur le VPS.
- `PAYDUNYA_MODE=live`.
- `PAYDUNYA_CALLBACK_URL` en HTTPS.
- IPN teste depuis Internet.

## EnactSpace

- `MOBILE_MONEY_ENABLED=true`.
- `PAYMENT_RECONCILIATION_ENABLED=true`.
- Cron ou timer systemd:

```bash
cd /opt/enactspace/backend
python -m app.scripts.reconcile_mobile_money
```

Frequence recommandee: toutes les 5 a 15 minutes.

## Validation finale

1. Transaction reelle de faible montant.
2. Debit payeur confirme.
3. Credit compte marchand confirme.
4. IPN recu.
5. Statut EnactSpace `successful`.
6. Dette soldee.
7. Recu cree.
8. Notification envoyee.
9. Dashboard Finance coherent.
10. Backup realise apres validation.
