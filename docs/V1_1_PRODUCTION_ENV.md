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
- `MOBILE_MONEY_ENABLED`: active le parcours Mobile Money cote backend.
- `MOBILE_MONEY_PROVIDER`: `manual_proof`, `mock` ou `paydunya` en V1.1. `wave_direct` et `orange_money_direct` sont reserves.
- `PAYDUNYA_MODE`: `test` en sandbox, `live` uniquement apres activation marchand et audit VPS.
- `PAYDUNYA_MASTER_KEY`, `PAYDUNYA_PUBLIC_KEY`, `PAYDUNYA_PRIVATE_KEY`, `PAYDUNYA_TOKEN`: cles serveur PayDunya. Elles restent uniquement dans l'environnement backend.
- `PAYDUNYA_CALLBACK_URL`: endpoint IPN public. En live, utiliser obligatoirement HTTPS.
- `PAYDUNYA_RETURN_URL`, `PAYDUNYA_CANCEL_URL`: pages de retour utilisateur. Elles ne confirment jamais un paiement.
- `PAYDUNYA_ALLOWED_CHANNELS`: canaux proposes via le checkout, par exemple `wave-senegal,orange-money-senegal`.
- `PAYDUNYA_TIMEOUT_SECONDS`: timeout HTTP serveur vers PayDunya.
- `PAYMENT_CURRENCY`: `XOF` pour la V1.1.
- `PAYMENT_TRANSACTION_TTL_MINUTES`: duree de validite interne d'une transaction.
- `PAYMENT_RECONCILIATION_ENABLED`: active le rapprochement periodique.

Les vraies cles PayDunya ne doivent jamais etre commitees, affichees dans Flutter ou exposees dans une reponse API.

## Validation locale

Avant de demarrer le VPS, valider le fichier d'environnement reel sans afficher les secrets:

```bash
cd /opt/enactspace/app/backend
python -m app.scripts.validate_environment
```

Sur Windows local:

```powershell
cd C:\Users\DIOP\Documents\Enactus\enactspace\backend
python -m app.scripts.validate_environment
```

Les valeurs contenant `#`, espaces, virgules ou URL doivent etre entre guillemets dans le `.env` reel. Le script affiche uniquement les erreurs de structure et les noms de variables, jamais les valeurs sensibles.

## Pointage QR

- `ATTENDANCE_QR_ENABLED`: active ou desactive le pointage par QR.
- `ATTENDANCE_QR_SECRET`: secret HMAC dedie aux QR de presence. En production, il doit etre long, aleatoire et different de `SECRET_KEY` / `JWT_SECRET_KEY`.
- `ATTENDANCE_QR_TTL_SECONDS`: duree de validite d'un jeton QR.
- `ATTENDANCE_QR_ROTATION_SECONDS`: frequence de rotation affichee cote responsable.
- `ATTENDANCE_LATE_GRACE_MINUTES`: delai de grace avant de marquer un scan en retard.
- `ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE`: limite de scans QR par utilisateur et par minute.
- `ATTENDANCE_QR_REQUIRE_MANUAL_CONFIRMATION`: option future de confirmation responsable.
- `ATTENDANCE_QR_REQUIRE_SESSION_PIN`: option future de code session.
- `ATTENDANCE_QR_REQUIRE_LOCATION_CHECK`: option future de controle de position.

## Valeurs interdites en production

- `APP_DEBUG=true`
- `ENABLE_SEED=true`
- secrets courts ou reutilises
- `ATTENDANCE_QR_SECRET=CHANGE_ME`
- `ATTENDANCE_QR_SECRET` identique au secret JWT
- cles PayDunya dans Git ou dans l'application Flutter
- `PAYDUNYA_MODE=live` sans HTTPS public et IPN teste
- `CORS_ORIGINS=*`
- stockage dans un dossier temporaire
- base SQLite pour les donnees reelles

## Rotation des secrets

1. Generer un nouveau secret hors depot.
2. Mettre a jour `.env` sur le VPS.
3. Redemarrer le service backend.
4. Verifier `/health`.
5. Reconnecter les comptes si les tokens existants deviennent invalides.
