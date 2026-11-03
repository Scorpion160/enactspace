# Secrets et environnements

## État attesté

Le contrôle backend du [3 novembre](releases/20261103-web-1.0.25-backend-1.0.23.md) a vérifié les quatre services et la configuration attendue du lot. La configuration de référence maintient les e-mails et push actifs, sans redirection de test, avec le paiement Mobile Money désactivé. Tester la réception séparément. Les restrictions effectives des clés clientes Firebase se vérifient dans la console du fournisseur.

Les valeurs des services, les fichiers Firebase natifs, les clés de signature et la clé de déchiffrement des sauvegardes sont confiés à un coffre institutionnel. Les defines web distribués sont des paramètres clients, visibles dans les artefacts. Ils ne doivent contenir aucune clé privée, donnée de connexion base ou identifiant d’administration fournisseur. Générer le worker Firebase web à partir de paramètres clients autorisés lors de la compilation.

## Inventaire et séparation

This document names configuration classes only. Never add values, fingerprints, private URLs, credentials, provider files, or signing material to Git, CI YAML, tickets, or review bundles.

| Names / class | Purpose and environment | Responsible role and storage | Rotation and exposure response |
| --- | --- | --- | --- |
| `SECRET_KEY`, `JWT_SECRET_KEY`, `REFRESH_TOKEN_HMAC_KEY` | Application signing and refresh-token protection; distinct values in production | Pôle IT security/operations; approved production secret manager | Rotate on schedule and after suspected exposure; revoke sessions as required and coordinate safe key transition |
| PostgreSQL username/password and `DATABASE_URL` | Database authentication; per environment | Database/operations owner; platform secret manager | Rotate on personnel/provider change and incident; restrict role, revoke old credential, inspect access |
| `SMTP_USERNAME`, `SMTP_PASSWORD` and SMTP provider credential | Email delivery | Communications/service owner with Pôle IT; provider secret store | Rotate per provider policy or exposure; revoke provider token and inspect delivery logs |
| `PUSH_TOKEN_ENCRYPTION_KEY` | Encrypt stored device push tokens | Pôle IT security; application secret manager | Plan data re-encryption before routine rotation; on exposure disable push access and rotate with incident review |
| `FIREBASE_PROJECT_ID`, `FCM_SERVER_KEY`, Firebase service-account/provider credential names | Firebase routing/authentication for enabled environments | Mobile/provider owner; Firebase/GCP secret store, never provider JSON in Git | Rotate/revoke in provider console; audit sends and device registrations |
| `PAYDUNYA_MASTER_KEY`, `PAYDUNYA_PUBLIC_KEY`, `PAYDUNYA_PRIVATE_KEY`, `PAYDUNYA_TOKEN`, `PAYMENT_WEBHOOK_SECRET` | Payment API and webhook verification; test/live separated | Finance service owner plus Pôle IT; provider/platform secret store | Rotate under dual control and on exposure; disable affected integration, reconcile transactions, notify finance authority |
| `ATTENDANCE_QR_SECRET`, `ATTENDANCE_NFC_HASH_SECRET` | QR signing and NFC identifier hashing | Attendance feature owner plus Pôle IT; application secret manager | Keep distinct from auth and each other; rotate after exposure and invalidate/re-enrol affected material as designed |
| Android upload/release key, keystore, aliases, passwords, `android/key.properties` | Android distribution signing | Before release, confirm the Enactus ESP release owner and approved offline/managed signing custody | Follow store/key-custody policy; report loss/exposure immediately and use store recovery process |
| Apple distribution certificate/private key, provisioning profile, App Store Connect credential, APNs key (`.p8`) | iOS signing, distribution, and push | Before release, confirm the Enactus ESP Apple account/release owner and approved signing vault | Rotate/revoke in Apple consoles, rebuild profiles, assess distributed builds and push access |

## Environment separation

Development, test, staging (if approved), and production use separate databases, secrets, provider projects/modes, storage, and test identities. Local test secrets are generated per process or supplied through an ignored local environment file. There is no shared/default password. Production credentials are never reused for tests.

Only sanitized `*.example` templates may be tracked. Real `.env` files, `google-services.json`, `GoogleService-Info.plist`, private keys, keystores, and signing properties are prohibited. CI uses synthetic disposable database credentials and generates `SECRET_KEY` at runtime without printing it.

## Exposure response

Treat a suspected disclosure as real until disproved: restrict access, identify affected environment and scope, revoke/rotate at the authority, invalidate sessions or provider access where relevant, review sanitized logs, verify recovery, and document the incident. Deleting a committed secret is not remediation; rotation is mandatory.
