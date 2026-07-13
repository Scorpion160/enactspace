# EnactSpace V1.1 - Nginx et HTTPS

## Fichiers

- Exemple Nginx: `deploy/nginx-enactspace.conf`
- Service backend: `deploy/enactspace-api.service`

Remplacer `api.enactspace.example.com` par le domaine reel avant installation.

## Installation principe

```bash
sudo cp deploy/nginx-enactspace.conf /etc/nginx/sites-available/enactspace
sudo ln -s /etc/nginx/sites-available/enactspace /etc/nginx/sites-enabled/enactspace
sudo nginx -t
sudo systemctl reload nginx
```

Certificat HTTPS:

```bash
sudo certbot --nginx -d api.enactspace.example.com
```

## Routes publiques attendues

- `/health`
- `/api/system/status`
- `/api/recruitment/public/*`
- `/api/recruitment/track/*`
- `/api/payments/paydunya/ipn`

## WebSocket

La route `/api/realtime/` conserve les headers `Upgrade` et `Connection`.

## Uploads

La configuration exemple bloque `/uploads/` directement via Nginx. Les fichiers utilisateurs doivent etre servis par l'API avec controle d'acces, sauf future strategie de liens signes.

## Taille fichiers

`client_max_body_size 500M` correspond a la limite haute V1.1 mentionnee. Adapter uniquement apres validation stockage, sauvegardes et quotas.

## Swagger

En production, choisir une strategie:

- laisser actif temporairement pendant la recette interne;
- proteger par IP/VPN;
- ou desactiver avant lancement public.
