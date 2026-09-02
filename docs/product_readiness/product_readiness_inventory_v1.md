# Inventaire de préparation produit et mobile — EnactSpace V1.0.0

Audit statique du 2026-09-02 — branche `feat/product-readiness-v1`, base `ec822afc101eff217ed0ff8d7f632837909d238e`. Aucun build mobile, accès store, test matériel ou changement fonctionnel n'est inclus.

## 1. Résumé exécutif

EnactSpace couvre déjà de nombreux domaines métier et possède une documentation VPS utile, mais n'est pas publiable en l'état comme V1 mobile publique. L'inventaire compte **6 P0, 13 P1, 12 P2 et 5 P3**.

Les arrêts immédiats sont : bearer token conservé en clair, initialisation publique du premier administrateur si le seed est activé, signature Android release avec la clé debug, déclarations/capacités caméra et NFC iOS absentes, et socle légal/suppression/export inexistant malgré la création de compte et le traitement de données sensibles.

Points solides : identifiants Android/iOS cohérents (`sn.enactusesp.enactspace`), icônes de marque, version Flutter `1.0.0+1`, endpoint de profil courant, audit métier partiel, notifications internes, HTTPS/Nginx et sauvegarde/restauration documentés. La priorité est de fermer sécurité et conformité, rendre les deux projets mobiles reproductibles, puis industrialiser livraison et handover.

## 2. Bloquants P0 / P1 / P2 / P3

### P0

| ID | Constat | Preuve | Sortie attendue |
|---|---|---|---|
| P0-01 | Bearer token en clair dans `SharedPreferences` | `frontend/lib/core/auth/auth_service.dart` | Keychain/Keystore, migration et effacement vérifiés |
| P0-02 | Route de seed initial non authentifiée et `ENABLE_SEED` activé par défaut | `backend/app/api/routes/seed.py`, `backend/app/core/config.py` | Initialisation fail-closed, hors API publique ou protégée par secret one-shot |
| P0-03 | Android release signé avec la config debug | `frontend/android/app/build.gradle.kts` | Keystore release externe et AAB signé vérifié |
| P0-04 | Scanner QR sans `NSCameraUsageDescription` | `frontend/ios/Runner/Info.plist`, `mobile_scanner` | Texte localisé et test appareil |
| P0-05 | NFC sans `NFCReaderUsageDescription` ni entitlement | Info.plist, absence de `Runner.entitlements`, `nfc_manager` | Capability, entitlement, texte et test iPhone |
| P0-06 | Politiques légales et droits suppression/export absents | aucun document, modèle, endpoint ou écran dédié | Textes/URLs validés, acceptation versionnée, export et suppression opérationnels |

### P1

| ID | Constat |
|---|---|
| P1-01 | Profil et conversations mis en cache sans chiffrement et non purgés au logout |
| P1-02 | Aucun refresh token, session/appareil, révocation ; reset password n'invalide pas les jetons |
| P1-03 | Android autorise le cleartext global et le client release peut retomber sur localhost HTTP |
| P1-04 | Backup/data extraction Android non encadrés pour les préférences sensibles |
| P1-05 | Intégration plugins iOS non reproductible : pas de `Podfile`, SPM iOS signalé désactivé |
| P1-06 | Aucun `PrivacyInfo.xcprivacy` applicatif ni validation des Required Reason APIs transitives |
| P1-07 | Équipe Apple, certificats, profiles et App Store Connect non configurés |
| P1-08 | Pas de centre Réglages/profil personnel/sécurité/aide/À propos accessible |
| P1-09 | Email/push réduits à des logs ; aucun token appareil ni fournisseur effectif |
| P1-10 | Baseline Alembic basée sur `metadata.create_all`, sans évolution explicite ni test upgrade |
| P1-11 | Workflows GitHub inadaptés/cassés ; aucune CI Flutter/backend/migration représentative |
| P1-12 | Aucun contrat de version mobile minimale, mise à jour forcée ou maintenance |
| P1-13 | Comptes de test partagés documentés dans Git et identifiants de démonstration liés au seed |

### P2

| ID | Constat |
|---|---|
| P2-01 | Pas de préférences globales langue/thème/notifications |
| P2-02 | Pas d'À propos avec version/build, slogan, Chicodev 2026 et maintenance Pôle IT |
| P2-03 | 403, session expirée, réseau et erreurs non centralisés |
| P2-04 | Pas d'icône Android adaptative |
| P2-05 | Splash natif Android/iOS générique |
| P2-06 | Pas d'App Links/Universal Links |
| P2-07 | Pas de procédure Play AAB ni matrice appareils |
| P2-08 | Dart en préversion et Flutter canal `main` : toolchain release instable |
| P2-09 | Poppins via `google_fonts` sans asset local : offline/privacy à maîtriser |
| P2-10 | README racine absent, README Flutter générique, gouvernance/versioning absents |
| P2-11 | `.flutter-plugins-dependencies` suivi avec chemins locaux ; `requirements.txt` racine étranger à l'app |
| P2-12 | Métadonnées, privacy/support URLs, âge et screenshots stores dédiés absents |

### P3

| ID | Constat |
|---|---|
| P3-01 | Pas de R8/ProGuard release explicite |
| P3-02 | Orientations iPhone/iPad larges sans décision UX |
| P3-03 | Pas de crash reporting, à ajouter seulement après décision privacy |
| P3-04 | Génération PDF Impact marquée TODO côté backend |
| P3-05 | Accusés livré/lu par destinataire marqués TODO dans le chat |

## 3. Matrice des gaps backend

| Capacité | État/existant | Proposition minimale | Migration | Endpoints | Audit | Risque |
|---|---|---|---|---|---|---|
| Profil courant | Partiel : `GET/PATCH /users/me` | L'exposer dans le frontend et auditer les champs sensibles | Non | Existant | À étendre | Moyen |
| Préférences | Absent | `user_preferences` : langue, thème, UX | Oui | GET/PATCH own | Oui | Moyen |
| Préférences notifications | Absent | préférences par type/canal avec opt-in | Oui | GET/PATCH own | Oui | Élevé |
| Devices/tokens push | Absent | token, plateforme, dates, révocation, unicité | Oui | register/delete | Oui | Élevé |
| Sessions/refresh | Absent ; access JWT seul | refresh haché, rotation, révocation et appareils | Oui | refresh/list/revoke | Oui | Critique |
| Mot de passe connecté | Reset OTP public seulement | vérifier l'actuel et révoquer les autres sessions | Selon sessions | POST change-password | Oui | Élevé |
| Suppression/désactivation | Suspension admin seulement | demande, délai, anonymisation et exceptions légales | Oui | create/cancel/status | Oui | Critique |
| Export personnel | Absent | job borné, archive protégée et lien expirant | Oui | request/status/download | Oui | Critique |
| Documents légaux | Absent | versions, locale, date d'effet, URL/contenu | Oui | list/current | Oui | Élevé |
| Acceptations | Absent | user/version/date/locale/source et reconsentement | Oui | accept/list own | Oui | Élevé |
| Support/feedback | Absent | ticket minimal ou lien externe officiel, pas deux systèmes | Si interne | create/list own | Oui | Moyen |
| Release mobile | `/system/status` donne la version service seulement | latest/minimum/store URL/message par plateforme | Oui ou config | status + admin | Admin | Élevé |
| Maintenance | Santé seulement | fenêtre, message, périmètre, issue de secours | Oui ou config | public + admin | Oui | Élevé |
| Email/push | Stubs de journalisation | fournisseur, consentement, retry, idempotence, métriques | Oui pour devices/outbox | internes | Technique | Élevé |
| Audit compte/sécurité | Partiel | profil, password, sessions, légal, export/suppression | Non | API audit existe | À étendre | Élevé |
| Migrations | Baseline `create_all` | révisions explicites et tests base vide/upgrade | Oui | — | — | Élevé |

Gaps confirmés : aucun modèle/endpoint de préférences, sessions, devices, légal/acceptations, support, export/suppression personnelle, release mobile ou maintenance. Email/push ne font pas d'appel fournisseur. Le reset password ne révoque pas les jetons existants.

## 4. Matrice Android

| Sujet | État | Action minimale | Priorité |
|---|---|---|---|
| Application ID | Conforme : `sn.enactusesp.enactspace` | Réserver dans Play Console | Externe |
| Version | `1.0.0+1` | Politique monotone de versionCode | P2 |
| SDK | hérités de Flutter | Geler/documenter compile/target/min compatibles Play | P1 |
| Signature | release=debug | Keystore hors Git, injection secrète, AAB signé | P0 |
| URL API | fallback HTTP localhost | URL HTTPS obligatoire et fail-fast en release | P1 |
| Cleartext | globalement autorisé | debug/localhost uniquement | P1 |
| Token | SharedPreferences | Android Keystore | P0 |
| Backup | non encadré | exclure secrets/caches ou désactiver selon politique | P1 |
| Permissions | INTERNET/CAMERA/NFC, usages réels | garder le minimum ; notification seulement avec push | P2 |
| NFC | feature optionnelle | tester devices NFC/non-NFC et fallback QR | P1 |
| Icône | marque raster présente | adaptive foreground/background/monochrome | P2 |
| Splash | natif blanc/générique | harmoniser premier frame | P2 |
| App Links | absents | ajouter après stabilisation URLs | P2 |
| Push | absent | décider, consentir, puis Firebase/tokens | P1 produit |
| R8 | absent | activer après tests | P3 |
| Play/AAB | non démontré, docs APK/debug | internal testing, Data Safety, pre-launch report | P1 |

## 5. Matrice iOS

| Sujet | État | Action minimale | Priorité |
|---|---|---|---|
| Bundle ID | Conforme : `sn.enactusesp.enactspace` | Réserver Developer Portal | Externe |
| Version/build | variables Flutter | build number monotone | P2 |
| Target | iOS 13.0 | confirmer avec Xcode/plugins retenus | P1 |
| Signature | team/provision absents | Distribution, profiles, App Store Connect | P1 |
| Plugins natifs | Podfile absent, SPM iOS désactivé | intégration standard puis archive Mac | P1 |
| Caméra | usage description absente | texte localisé + test QR appareil | P0 |
| NFC | description/entitlement absents | Tag Reading capability + test iPhone | P0 |
| ATS | local networking uniquement | conserver HTTPS production | Conforme |
| Privacy manifest | absent/non validé | inventaire app/plugins et raisons autorisées | P1 |
| Icônes | gamme de marque opaque | valider par archive | P2 |
| Launch screen | générique | finition HIG/branding | P2 |
| Universal Links | absents | ajouter avec domaine/routes stabilisés | P2 |
| Push | APS absent | ne pas ajouter avant conception complète | P1 produit |
| Background modes | absents | rester absent sans besoin | Conforme |
| Orientations | très larges | tester ou limiter | P3 |
| TestFlight/App Store | aucun runbook/essai | archive, privacy report, TestFlight | P1 |

La certification iOS requiert un Mac/Xcode figé, un compte Apple Developer et un iPhone NFC-compatible. Cet audit Windows ne certifie ni compilation ni archive.

## 6. Matrice Réglages / Aide / Légal

| Besoin | État/existant | Manque exact |
|---|---|---|
| Réglages | Absent | route, sections, navigation mobile |
| Mon profil | API `/users/me`, dialogues manager | écran self-service et gateway update me |
| Sécurité | login/logout/reset OTP | changement connecté, sessions, révocation |
| Notifications | centre et compteurs | préférences type/canal, consentement push |
| Langue/thème | intl et thème clair statique | choix persistants et contenus localisés |
| Stockage | réglages cache chat locaux | vue globale, taille, purge logout, rétention |
| Aide/FAQ | Absent | contenu produit versionné |
| Support/feedback | Absent | canal officiel, données collectées et SLA |
| À propos | version/branding disponibles | version/build runtime, slogan, Chicodev 2026, Pôle IT |
| Privacy/CGU/charte | Absents | textes validés, URLs, versions, acceptations |
| Export/suppression | Absents | parcours initiés dans l'app et backend |
| Update/maintenance | health backend seulement | contrat mobile et écrans dédiés |

## 7. Matrice conformité vie privée / stores

| Domaine | Données constatées | Exigence avant release |
|---|---|---|
| Profil | identité, contact, études, bio, photo, réseaux | notice, correction, minimisation, rétention, export/suppression |
| Recrutement | réponses, documents, décisions | notice dédiée, accès restreint et purge |
| Finance | paiements, preuves, références | rétention légale, contrôle d'accès, redaction logs |
| Présence | événements, scans QR/NFC | information, durée, contestation et fallback |
| Communication | posts, chat, médias, notifications | modération, rétention, cache/chiffrement, suppression |
| Auth | token, OTP, traces | stockage sécurisé, révocation, rate limit, audit |
| Diagnostics | logs serveur | minimisation, durée et accès |

Avant stores : textes validés par le responsable compétent ; URLs HTTPS privacy/support ; acceptations versionnées ; suppression initiable dans l'app et export ; formulaires Play Data Safety et Apple App Privacy fondés sur l'inventaire réel ; classification d'âge, notes de review, comptes temporaires et screenshots store. Aucun analytics/ads/crash SDK n'est présent : ne pas les déclarer ni les ajouter sans nouvelle revue. Une bannière cookies n'est pas justifiée à ce stade ; documenter le stockage web et réévaluer si traceurs/cookies sont ajoutés.

## 8. Matrice dépôt / documentation

| Élément | État/action |
|---|---|
| README racine/backend | Absents ; créer quickstart canonique, architecture, migrations/tests |
| README frontend | Template Flutter générique à remplacer |
| CONTRIBUTING, SECURITY, SUPPORT | Absents |
| CHANGELOG/ROADMAP | notes V1 dispersées ; pas de standard ni roadmap |
| CODE_OF_CONDUCT, AUTHORS/CREDITS, LICENSE | Absents ; décision de licence requise |
| CODEOWNERS, issues/PR templates | Absents |
| CI Flutter | Absente |
| CI backend | workflow conda générique requérant `environment.yml` absent |
| Workflow PyPI | Inapproprié : pas de package Python à publier |
| CI migrations/sécurité/dépendances | Absente |
| Exploitation | VPS, Nginx, backup, restore, logs et env bien couverts mais dispersés |
| Mobile | Android interne/debug seulement ; iOS absent |
| Secrets | env/keystores ignorés ; comptes de test partagés encore suivis |

## 9. Matrice handover

| Capacité Pôle IT | État | À fermer |
|---|---|---|
| Local backend/frontend | Partiel | retirer chemins/IP spécifiques et tester sur poste vierge |
| Production VPS/HTTPS | Documenté | réconcilier anciennes instructions seed/create_tables avec Alembic |
| Backup/restore | Documenté | exercice daté, RPO/RTO |
| Logs/services | Documenté | alertes, SLO, escalade incident |
| Migrations | Fragile | révisions et CI |
| Android | Interne | signing, AAB, Play, versioning |
| iOS | Absent | Mac, signing, archive, TestFlight/App Store |
| Release/rollback | Absent | checklist, tags, artefacts, approbateurs, rollback applicatif |
| Secrets/comptes | Partiel | coffre, rotation, secours, offboarding |
| Ownership | Absent | CODEOWNERS/RACI Pôle IT/fournisseurs |
| Reprise autonome | Non démontrée | exercice sans Chicodev |

Critère de handover : un membre Pôle IT non développeur initial doit pouvoir, sans secret oral, restaurer, déployer, produire AAB/archive iOS, diagnostiquer et rollbacker.

## 10. Dépendances et sécurité

| Constat | Recommandation |
|---|---|
| `shared_preferences` contient token, utilisateur, chat | `flutter_secure_storage` pour secrets ; minimiser/chiffrer/purger les caches |
| JWT access seul, minimal (`sub`,`exp`) | sessions, refresh haché, rotation/révocation ; `jti` et politique issuer/audience si utile |
| Reset sans invalidation | révoquer sessions et auditer |
| SDK beta/canal main | épingler Flutter stable/FVM |
| Poppins non embarquée | inclure l'asset licencié |
| `package_info_plus` absent | l'ajouter seulement avec About |
| Firebase/connectivity/app-links/device-info/crash SDK absents | ne les ajouter que si besoins et privacy validés ; connectivity reste optionnel |
| QR/NFC natifs | matrice permissions/capabilities et tests matériels |
| fichier plugins généré suivi | retirer du suivi et régénérer |
| requirements racine hors sujet | supprimer/clarifier ; garder backend canonique |
| seed activé par défaut | fail-closed et procédure one-shot |

Aucun registre de packages n'a été interrogé : l'audit ne certifie ni versions à jour ni absence de CVE. Ajouter lockfiles, scan de dépendances et revue en CI.

## 11. Phases proposées

1. **PR-0 — P0** : seed fail-closed, stockage/purge, signature/HTTPS/backup Android, permissions/capabilities/intégration iOS, décisions légales. Sortie : tests sécurité, AAB signé interne, archive iOS diagnostic.
2. **PR-1 — Compte et droits** : préférences, profil, password, sessions, légal/acceptations, export/suppression, Settings/Security/Privacy/Help/About. Sortie : tests API/gateway/audit.
3. **PR-2 — Stores/natif** : adaptive icons, splash, privacy manifest, Data Safety/App Privacy, métadonnées, QR/NFC/appareils/offline. Sortie : Play Internal et TestFlight.
4. **PR-3 — Contrôle release** : minimum/forced update/maintenance ; email/push/devices seulement si approuvés ; deep links si URLs stables.
5. **PR-4 — Industrialisation/handover** : CI, migrations, scans, docs, versioning, sauvegarde/restauration, déploiement/rollback, exercice Pôle IT.
6. **PR-5 — V1.0.0** : fermer tous P0/P1, accepter les P2 différés, publier sur tracks fermés, surveiller puis promouvoir ; archiver hashes/SBOM/approvals.

## 12. Fichiers probablement modifiés par phase

| Phase | Fichiers/aires probables |
|---|---|
| PR-0 | `frontend/pubspec.yaml`, auth/chat services, Gradle/manifests/network config, Info.plist/projet Xcode, seed/config backend ; nouveaux secure storage adapter, backup rules, `Runner.entitlements`, `PrivacyInfo.xcprivacy`, intégration pods/SPM |
| PR-1 | router/AppShell, services user/auth/audit ; nouvelles features settings/profile/security/legal, modèles/schemas/routes/migrations/tests |
| PR-2 | assets/manifests/plist/pubspec/thèmes/localisation ; store metadata, privacy worksheets et tests devices |
| PR-3 | system/config/notifications/router ; modèles/routes release/maintenance/devices, migrations et écrans dédiés |
| PR-4 | `.github/workflows`, `.gitignore`, docs/tests/requirements ; README, CONTRIBUTING, SECURITY, SUPPORT, CHANGELOG, LICENSE, CODEOWNERS, templates/update bot |
| PR-5 | version pubspec/config backend, release notes, checklist et manifeste d'artefacts |

## 13. Comptes, credentials et matériel externes

| Besoin | Propriétaire/usage |
|---|---|
| Google Play Console institutionnel | Enactus ESP/Pôle IT : app ID, Data Safety, tracks |
| Clé Android upload sauvegardée | Pôle IT, double contrôle |
| Apple Developer Organization/App Store Connect | bundle, capabilities, signing, TestFlight/review |
| Mac + Xcode figé | pods/SPM, archive, privacy report/upload |
| iPhone NFC et Android NFC/non-NFC | QA caméra/QR/NFC/fallback |
| Domaine/DNS/TLS et URLs privacy/support | organisation |
| Coffre de secrets | DB, JWT, mail, paiement, push, signing |
| Fournisseur mail, puis Firebase/APNs si approuvé | transactionnel et push |
| Conseil légal/privacy | textes, bases, rétention, déclarations stores |
| Comptes paiement sandbox/prod | Finance + Pôle IT |
| Comptes review temporaires | Product owner ; expiration après review |

Aucun credential, certificat, clé ou mot de passe réel ne doit entrer dans Git. La rotation et la récupération doivent être testées.

## 14. DO NOT IMPLEMENT YET

Ne pas implémenter avant décision explicite :

- push/Firebase, analytics, crash reporting ou tracking avant privacy/consentement/contrat ;
- biométrie, empreinte appareil ou géolocalisation sans besoin validé ;
- App/Universal Links avant domaine et routes stables ;
- bannière cookies sans traceurs/cookies réels ;
- suppression physique ignorant conservation comptable, sécurité et audit ;
- thème sombre/langues multiples sans contenus maintenables ;
- background modes iOS, notifications Android ou capabilities inutilisées ;
- R8/obfuscation avant tests et symbolication ;
- forced update sans cache, disponibilité et issue de secours ;
- données fictives, secrets ou comptes permanents pour une review store ;
- nouvelle logique métier pendant le chantier readiness sans phase, tests et propriétaire.

Ce document est uniquement un inventaire et n'autorise aucune implémentation.
