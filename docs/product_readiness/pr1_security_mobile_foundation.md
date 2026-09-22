# PR-1 — Security & Mobile Foundation

Date de validation : 2026-09-02
Branche : `feat/product-readiness-v1`
Version produit : EnactSpace `1.0.0+1`

## Périmètre

PR-1 ferme les fondations de sécurité et de configuration mobile identifiées dans l'inventaire : stockage auth, exposition du seed administrateur, signature/réseau/backup Android et usages caméra/NFC iOS. Aucun réglage produit, écran légal, support, push, export/suppression, release backend ou changement métier n'est ajouté.

## Problèmes corrigés

| Sujet | Avant | Après |
|---|---|---|
| Access token | `enactspace_token` en clair dans `SharedPreferences` | `flutter_secure_storage` derrière `AuthStorage` ; Keystore Android et Keychain iOS |
| Cache utilisateur courant | JSON de profil dans `SharedPreferences` | même stockage sécurisé centralisé |
| Logout | suppression des deux clés SharedPreferences | suppression des secrets sécurisés et de toutes les copies historiques |
| Seed initial | route toujours enregistrée ; activation par défaut ; valeurs de credentials par défaut | activation par défaut `false`, route absente hors `development`/`test`, activation explicite requise, aucun mot de passe/administrateur par défaut |
| Seed démo | mot de passe par défaut et renvoyé dans la réponse | mot de passe obligatoire fourni par l'opérateur et jamais renvoyé |
| Android release | signature debug | signature release externe seulement ; erreur `EXTERNAL_SIGNING_REQUIRED` si absente |
| Android réseau | cleartext global et fallback localhost possible en release | cleartext refusé dans main/release ; localhost seulement dans le manifest debug ; URL HTTPS obligatoire en release |
| Android backup | stratégie implicite | `android:allowBackup="false"` |
| iOS caméra | description absente | description française liée au scan QR de présence |
| iOS NFC | description/capability absentes | description française, entitlement `TAG`, `CODE_SIGN_ENTITLEMENTS` sur Debug/Profile/Release |

## Stockage auth et migration

`AuthStorage` est l'unique abstraction des secrets d'authentification. L'implémentation native utilise `FlutterSecureStorage`, donc Android Keystore et iOS Keychain. `SharedPreferences` reste réservé aux préférences non sensibles hors de ce stockage.

Migration one-shot :

1. lire d'abord la nouvelle clé sécurisée ;
2. si elle est absente, lire l'ancienne clé SharedPreferences ;
3. écrire la valeur dans le stockage sécurisé ;
4. supprimer l'ancienne valeur seulement après succès de l'écriture ;
5. aux lectures suivantes, supprimer toute copie historique résiduelle sans réécrire le secret.

Une écriture sécurisée en échec laisse volontairement l'ancienne valeur en place afin de ne pas déconnecter irrémédiablement un membre. Le prochain lancement retente la migration. Aucun token n'est journalisé. Aucun refresh token n'existe dans la V1 actuelle.

Le cache JSON de l'utilisateur courant suit la même migration. Les caches de conversations restent un sujet P1 distinct et hors du périmètre de ce lot.

## Seed administrateur

Le P0 provenait de la combinaison suivante : endpoint `/api/seed/initial` non authentifié, route montée dans toutes les configurations et `ENABLE_SEED=true` par défaut. Sur une base vide mal configurée, un appel public pouvait donc créer le premier administrateur.

Après PR-1, `ENABLE_SEED=false` par défaut et `register_seed_routes` ne monte aucune route si l'environnement n'est pas exactement `development` ou `test`. Même une valeur `ENABLE_SEED=true` en production ne réactive pas la route. En développement/test, l'opérateur doit activer explicitement le seed et fournir tous les champs administrateur et mots de passe. Les utilisateurs de production et la base n'ont pas été modifiés.

## Android

### Signature

`android/key.properties` est ignoré par Git. `key.properties.example` décrit uniquement les noms de propriétés attendus : `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Le build release n'utilise jamais `signingConfigs.debug`. Sans les quatre valeurs externes, les tâches `assembleRelease`, `bundleRelease` et `packageRelease` s'arrêtent avec `EXTERNAL_SIGNING_REQUIRED`.

### Réseau et backup

Les manifests main et profile imposent `android:usesCleartextTraffic="false"` et la base réseau refuse le cleartext. Seul l'overlay `src/debug` autorise `localhost`, `127.0.0.1` et `10.0.2.2`. `ApiClient` exige une `ENACTSPACE_API_URL` absolue HTTPS en release ; les fallbacks locaux n'existent qu'en mode non-release. Le backup applicatif est désactivé pour éviter l'export de caches et préférences sensibles.

Les permissions conservées sont INTERNET, CAMERA et NFC, toutes utilisées. `POST_NOTIFICATIONS` n'a pas été ajouté.

### Identité

Le namespace et l'application ID Android restent `sn.enactusesp.enactspace`. Debug, Profile et Release héritent du même `defaultConfig` ; aucun suffixe incohérent n'est présent.

## iOS

`Info.plist` contient maintenant :

- `NSCameraUsageDescription` pour le scan des QR codes de présence ;
- `NFCReaderUsageDescription` pour l'enregistrement des badges et l'émargement.

Le code lit des tags via les options ISO 14443, ISO 15693 et ISO 18092 et n'utilise pas un flux NDEF applicatif. L'entitlement NFC demandé est donc uniquement `com.apple.developer.nfc.readersession.formats = TAG`. `Runner.entitlements` déclare aussi `keychain-access-groups` avec un tableau vide, requis par `flutter_secure_storage` pour persister réellement les secrets dans le Keychain. Aucun entitlement push ou Background Mode n'a été ajouté.

`CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` est configuré pour Debug, Profile et Release. Le bundle ID reste `sn.enactusesp.enactspace` dans les trois configurations ; les tests utilisent le suffixe `.RunnerTests`, attendu.

Statut : `MACOS_XCODE_VALIDATION_REQUIRED`. Une archive réelle exige un Mac, Xcode, Apple Developer, la capability NFC activée sur l'App ID, un provisioning profile actualisé et un iPhone NFC-compatible.

## Toolchain et dépendance

L'environnement réellement utilisé est Flutter `3.44.9` avec Dart `3.12.2`. La contrainte précédente `^3.13.0-103.1.beta` ne pouvait pas être résolue. Elle est remplacée par `^3.12.0`, stable et compatible avec l'environnement. Le nom de package reste `frontend` car les imports `package:frontend/...` sont nombreux. La description placeholder est remplacée et la version reste `1.0.0+1`.

Nouvelle dépendance directe : `flutter_secure_storage: ^10.0.0`, résolue en `10.3.1`. Aucun upgrade majeur global n'a été lancé ; les ajustements transitifs du lockfile proviennent du résolveur compatible Dart 3.12.

## Secrets et comptes externes requis

Aucun secret n'est versionné. La publication nécessitera :

- un Android upload keystore institutionnel et ses quatre valeurs dans un coffre ;
- un compte Apple Developer Organization, certificats Distribution et provisioning profiles ;
- l'accès App Store Connect ;
- une URL API HTTPS de production injectée par `ENACTSPACE_API_URL` ;
- un Mac/Xcode et des appareils QR/NFC réels.

## Validation et limitations

Tests PR-1 disponibles : migration/échec/purge du stockage, refus d'URL release non HTTPS, absence du seed en production et contrôle explicite en développement/test.

La compilation APK debug a été tentée à trois reprises. Gradle franchit la configuration et ne remonte aucune erreur de source PR-1, mais le disque C: sature pendant `mergeDebugNativeLibs`/copie des assets. État : `ENVIRONMENT_DISK_SPACE_REQUIRED`. Le build doit être relancé avec plusieurs gigaoctets supplémentaires. L'avertissement Flutter sur la future migration Built-in Kotlin des plugins reste à planifier sans upgrade massif dans PR-1.

Aucune migration DB produit n'est introduite. La migration Alembic existante doit seulement être vérifiée par les contrôles backend.

### Classification du scan sécurité

- aucun token d'authentification n'est journalisé ou conservé dans `SharedPreferences` après migration réussie ;
- aucun fallback de signature Android vers la clé debug ne subsiste ;
- les seules autorisations cleartext restantes sont confinées à la variante Android Debug et aux hôtes locaux de développement ;
- les identifiants présents dans `backend_smoke_test.py` sont exclusivement des données de test suivies comme dette P1 ; aucune valeur par défaut n'est exposée par la route seed ;
- les occurrences `CHANGE_ME` restantes sont des placeholders documentaires ou des garde-fous de configuration, pas des secrets intégrés.

## P0/P1 restant après PR-1

### P0 code traité

- P0-01 stockage token : corrigé et testé ;
- P0-02 seed administrateur : corrigé et testé ;
- P0-03 signature debug : supprimée ; signature externe encore requise ;
- P0-04 caméra iOS : configuration statique corrigée ; validation Mac/appareil requise ;
- P0-05 NFC iOS : configuration statique corrigée ; capability/provisioning et validation appareil requis.

### P0 restant hors scope

- P0-06 : socle légal complet, acceptations, export et suppression utilisateur.

### P1 restant

- caches de chat non chiffrés et cycle sessions/refresh/révocation ;
- intégration/compilation native iOS et privacy manifest applicatif ;
- signature/provisioning Apple externes ;
- Réglages/profil/sécurité/aide/À propos ;
- email/push réels ;
- migrations explicites et CI représentative ;
- contrôle release/maintenance ;
- comptes de test partagés documentés.

Les P1 Android cleartext/fallback API et backup sont corrigés par PR-1. L'APK debug reste non certifié uniquement pour manque d'espace disque local.
