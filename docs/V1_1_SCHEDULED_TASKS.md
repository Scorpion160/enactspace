# EnactSpace V1.1 - Taches planifiees

## Mobile Money

Fichiers systemd:

- `deploy/enactspace-mobile-money-reconcile.service`
- `deploy/enactspace-mobile-money-reconcile.timer`

Installation:

```bash
sudo cp deploy/enactspace-mobile-money-reconcile.service /etc/systemd/system/
sudo cp deploy/enactspace-mobile-money-reconcile.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now enactspace-mobile-money-reconcile.timer
sudo systemctl list-timers | grep enactspace
```

La frequence recommandee est 5 a 15 minutes. La configuration proposee utilise 10 minutes.

## Sauvegardes

Configurer une tache separee pour:

- dump PostgreSQL;
- archive `/var/lib/enactspace/uploads`;
- verification de taille et presence du fichier de backup.

Ne pas lancer backup et migration en meme temps.

## Nettoyages futurs

A prevoir apres RC1 si necessaire:

- expiration des tokens d'activation;
- suppression des fichiers temporaires abandonnes;
- rotation des exports temporaires.

## Anti-concurrence

Les timers systemd ne doivent pas lancer deux instances simultanees du meme service. Verifier:

```bash
systemctl status enactspace-mobile-money-reconcile.timer
journalctl -u enactspace-mobile-money-reconcile.service -n 100
```
