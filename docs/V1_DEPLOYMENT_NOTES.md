# EnactSpace V1 - Notes de deploiement

Date: 2026-07-03

## Variables backend

- `APP_NAME=EnactSpace`
- `APP_ENV=production` en production.
- `APP_DEBUG=false` en production.
- `DATABASE_URL`
- `SECRET_KEY`
- `ACCESS_TOKEN_EXPIRE_MINUTES`
- `ENABLE_SEED=false` en production.
- Variables SMTP/FCM seulement si activees.

## Securite

- Desactiver `ENABLE_SEED` hors local.
- Utiliser une cle secrete forte.
- Ne pas exposer directement les fichiers; utiliser les routes `/api/files`.
- Restreindre CORS aux domaines officiels.
- Verifier les sauvegardes base + uploads.

## Frontend

- Configurer `ENACTSPACE_API_URL` pour pointer vers l'API.
- Tester sur desktop, mobile web et Android.
- Utiliser Firefox ou Edge si Chrome n'est pas disponible localement.

## Avant livraison

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\frontend
flutter analyze --no-pub

cd C:\Users\DIOP\Documents\Enactus\enactspace
python -m compileall backend/app
git diff --check
git status
```
