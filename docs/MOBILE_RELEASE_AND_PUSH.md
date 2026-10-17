# Mobile release and push

## Livraison constatée — Android 1.0.13+16

L’APK release a été compilé puis installé avec `adb install -r` sur un Samsung SM_A065F le 10 octobre. Android indique `versionName=1.0.13` et `versionCode=16`. Cela confirme cette installation, sans constituer une publication Play Store ni une validation complète FCM.

Si ADB indique `unauthorized`, déverrouiller le téléphone, accepter le débogage USB puis vérifier `adb devices -l`. Ne pas désinstaller pour résoudre l’autorisation USB. Vérifier le SHA256 avant installation et contrôler la version après.

Aucune livraison iOS ni publication de store n’est attestée. Les contrôles physiques de permissions, réception en arrière-plan, rotation des tokens et déconnexion restent à terminer. Voir [les identifiants d’artefacts](releases/20261010-release-1.0.13.md).

## Procédures générales et contexte antérieur

Repository builds prove compilation and automated behavior; they do not prove distribution signing, provider entitlement, store ownership, or physical-device delivery.

## Shared release rules

- Keep the application/bundle identifier `sn.enactusesp.enactspace`.
- The delivered Flutter identity is `1.0.13+16`; increment build numbers for subsequent distributed artifacts.
- Release API configuration must be an authorized HTTPS endpoint.
- No keystore, private key, provisioning profile, provider JSON/plist, APNs key, or password belongs in Git or ordinary CI artifacts.
- Android debug signing is never valid release evidence. `EXTERNAL_SIGNING_REQUIRED` remains enforced.

## Android external gates

- Before release, confirm that Enactus ESP controls the Play Console application and the approved release-signing/upload-key custody.
- The release owner supplies external signing configuration through the approved secure process.
- Build and verify a signed release artifact outside default PR CI.
- Validate Firebase configuration and FCM delivery on a physical Android device.
- Confirm notification permission, token rotation, logout/account deletion, deep links, background/terminated delivery, and provider failure behavior.
- Approve store listing, privacy declarations, support contact, and final store URL ownership.

## iOS external gates

- Enable the Apple Push Notifications capability for the correct App ID.
- Use an approved distribution certificate, provisioning profile, and production `aps-environment` entitlement.
- Build and validate a signed distribution archive on authorized macOS/Apple infrastructure.
- Validate APNs/FCM registration and delivery on a physical iOS device, including foreground/background/terminated paths and token changes.
- Confirm App Store Connect ownership, privacy declarations, support contact, listing, and store URL.

An optional `flutter build ios --release --no-codesign` check on macOS can detect compilation problems only. It does not close any signing, entitlement, archive, provider, physical-device, or store gate.

## Evidence

For every external gate, record date, release commit/version, platform/device and OS, operator/reviewer, provider environment, sanitized result, artifact identifier/checksum where safe, and follow-up owner. Do not attach credentials, full tokens, private member data, or provider configuration files.
