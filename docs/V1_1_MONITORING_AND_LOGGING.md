# EnactSpace V1.1 - Monitoring et logs

## Sources logs

- Backend: `journalctl -u enactspace-api`
- Nginx: `/var/log/nginx/access.log` et `/var/log/nginx/error.log`
- PostgreSQL: logs service PostgreSQL
- Timers: `journalctl -u enactspace-mobile-money-reconcile.service`

## Donnees interdites dans les logs

- mots de passe;
- JWT complet;
- secrets QR/NFC;
- cles PayDunya;
- token d'activation;
- payload sensible PayDunya complet;
- preuve de paiement complete;
- documents personnels.

## Verification minimale

```bash
systemctl status enactspace-api
journalctl -u enactspace-api -n 100 --no-pager
curl -fsS https://API_REELLE/health
curl -fsS https://API_REELLE/api/system/status
```

## Alertes recommandees

- backend down;
- PostgreSQL inaccessible;
- stockage uploads non accessible;
- espace disque faible;
- erreurs HTTP 5xx;
- echecs PayDunya;
- echecs sauvegardes;
- timer de reconciliation inactif.

## Rotation

Utiliser journald et logrotate Nginx par defaut. Verifier la retention:

```bash
journalctl --disk-usage
```

Adapter `/etc/systemd/journald.conf` si necessaire.
