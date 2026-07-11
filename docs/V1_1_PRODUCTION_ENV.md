# EnactSpace V1.1 - Variables production

Ce document decrit les variables a definir sur le VPS. Ne jamais committer le fichier `.env` reel.

## Fichier de reference

Un modele sans secret est disponible dans `backend/.env.production.example`.

Copie recommandee sur le serveur:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
copy .env.production.example .env
```

Sur Linux:

```bash
cd /opt/enactspace/backend
cp .env.production.example .env
chmod 600 .env
```

## Variables obligatoires

- `DATABASE_URL`: URL SQLAlchemy de la base. Pour un VPS, utiliser PostgreSQL si possible.
- `SECRET_KEY`: secret applicatif long et aleatoire.
- `JWT_SECRET_KEY`: secret dedie aux tokens JWT. Si vide, le backend retombe sur `SECRET_KEY`.
- `CORS_ORIGINS`: domaines autorises a appeler l'API, separes par des virgules.
- `PUBLIC_API_BASE_URL`: URL publique de l'API, par exemple `https://api.enactspace.example.com`.
- `FILE_STORAGE_PATH`: dossier persistant des fichiers envoyes.

## Notifications

- `EMAIL_ENABLED`: interrupteur production simple.
- `NOTIFICATION_EMAIL_ENABLED`: ancien nom conserve pour compatibilite.
- `NOTIFICATION_EMAIL_FROM`: adresse expediteur.
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_USE_TLS`: configuration SMTP.
- `PUSH_ENABLED`: interrupteur production simple.
- `NOTIFICATION_PUSH_ENABLED`: ancien nom conserve pour compatibilite.
- `FCM_SERVER_KEY`: cle push si Firebase Cloud Messaging est active.

## Paiements

- `PAYMENT_PROVIDER_ENABLED`: active ou desactive un provider de paiement reel.
- `PAYMENT_PROVIDER`: `manual_proof`, `mock` ou nom du futur fournisseur Mobile Money.
- `PAYMENT_WEBHOOK_SECRET`: secret utilise pour verifier les webhooks paiement.

## Valeurs interdites en production

- `APP_DEBUG=true`
- `ENABLE_SEED=true`
- secrets courts ou reutilises
- `CORS_ORIGINS=*`
- stockage dans un dossier temporaire
- base SQLite pour les donnees reelles

## Rotation des secrets

1. Generer un nouveau secret hors depot.
2. Mettre a jour `.env` sur le VPS.
3. Redemarrer le service backend.
4. Verifier `/health`.
5. Reconnecter les comptes si les tokens existants deviennent invalides.
