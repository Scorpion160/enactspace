# EnactSpace V1.1 - Audit pre-deploiement production

Date: 2026-07-13
Dernier commit audite: `c9ad966 Audit mobile money payment security`

## Synthese

La V1.1 est fonctionnellement complete cote code pour une Release Candidate. Le passage production doit maintenant se concentrer sur l'environnement VPS, PostgreSQL, HTTPS, migrations reproductibles, stockage persistant, import reel des membres et recette.

PayDunya est integre cote code mais reste **READY WITH CONFIGURATION** tant que les cles sandbox ne sont pas configurees et que les tests provider reels ne sont pas executes.

## Statuts

| Domaine | Statut | Notes |
| --- | --- | --- |
| Code applicatif V1.1 | READY | Analyse Flutter et compilation backend OK au dernier commit. |
| Configuration production | READY WITH CONFIGURATION | `backend/.env.production.example` existe. Le `.env` reel doit etre valide localement et sur VPS. |
| Variables d'environnement | READY WITH CONFIGURATION | Secrets JWT, QR, NFC, SMTP, PayDunya et chemins doivent rester hors Git. |
| Base de donnees | READY WITH CONFIGURATION | PostgreSQL requis sur VPS. Migration reproductible a finaliser avant production. |
| Migrations | BLOCKED | `ensure_compatibility_columns` et `create_all` existent, mais ne doivent pas etre l'unique strategie production. |
| Permissions backend | READY | Plusieurs audits role/perimetre existent et les routes sensibles utilisent des dependances d'autorisation. |
| Stockage fichiers | READY WITH CONFIGURATION | `FILE_STORAGE_PATH` doit pointer vers `/var/lib/enactspace/uploads` ou equivalent hors repo. |
| CORS | READY WITH CONFIGURATION | `CORS_ORIGINS` doit lister uniquement les domaines officiels HTTPS. |
| HTTPS | READY WITH CONFIGURATION | A gerer via Nginx/Certbot sur VPS. |
| Emails | READY WITH CONFIGURATION | Notifications internes restent disponibles si SMTP indisponible. SMTP ne doit pas bloquer les workflows. |
| Notifications push | OPTIONAL | FCM configurable, non indispensable pour RC1. |
| Logs | READY WITH CONFIGURATION | journald/Nginx et rotation a documenter; ne pas logger secrets ou payloads sensibles. |
| Sauvegardes | READY WITH CONFIGURATION | PostgreSQL et fichiers uploads doivent avoir une procedure backup/restore. |
| Taches planifiees | READY WITH CONFIGURATION | Rapprochement Mobile Money disponible via `python -m app.scripts.reconcile_mobile_money`. Timers a configurer. |
| PayDunya | READY WITH CONFIGURATION | Code sandbox/live, IPN et reconciliation disponibles; aucun test sandbox reel sans cles. |
| Paiement manuel | READY | Fallback existant conserve. |
| QR Presence | READY WITH CONFIGURATION | Secret QR dedie obligatoire en production. |
| NFC Presence | READY WITH CONFIGURATION | Secret NFC dedie obligatoire; test physique sur telephone compatible requis. |
| Recrutement | READY | Parcours public, suivi, evaluation, entretien et conversion disponibles. |
| Import membres | READY WITH CONFIGURATION | Dry-run local indique 26 lignes valides; import production exige backup + preview VPS. |
| APK Release Candidate | READY WITH CONFIGURATION | Build release a produire avec URL API HTTPS reelle. APK hors Git. |

## Actions bloquantes avant RC exploitable

1. Valider le `.env` reel sans afficher les secrets.
2. Mettre en place une strategie de migrations reproductibles.
3. Deployer PostgreSQL sur VPS avec utilisateur dedie.
4. Configurer Nginx + HTTPS.
5. Configurer stockage persistant hors repo.
6. Initialiser la production de facon idempotente.
7. Faire preview de l'import des 26 membres sur la base production.

## Actions a faire pendant la recette

1. Tester les roles reels: Admin, Team Leader, SG, Financier, chefs, adjoints, enacteurs, alumni, candidat.
2. Tester recrutement fictif de bout en bout.
3. Tester presences manuelles, QR et NFC.
4. Tester finance avec paiement manuel et provider mock.
5. Tester PayDunya sandbox uniquement apres configuration des cles.
6. Produire APK `EnactSpace-v1.1.0-rc1.apk` hors repo et calculer SHA-256.

## Donnees et secrets interdits dans Git

- `.env` reel;
- cles PayDunya;
- secrets JWT/QR/NFC;
- base PostgreSQL;
- sauvegardes;
- CSV/ODS reels;
- APK;
- captures contenant donnees personnelles.
