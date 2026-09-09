# PR-6 production readiness

This runbook describes the Android/iOS readiness gate and the external release work that must remain outside source control. Do not add real API, Firebase, signing, Apple, or store credentials to this file.

PR-6 readiness enforcement applies only to Android and iOS. Web, Windows, macOS, Linux, and other unsupported Flutter targets are explicitly `notApplicable`: they mount the normal router child immediately, perform no mobile bootstrap/store/resume work, and preserve existing auth, RBAC, and legal behavior. This bypass is a non-regression rule, not desktop production certification. The backend may continue to support `platform=web` independently; a future Web readiness policy is outside PR-6.

## Readiness decision

Every route except `/legal/privacy` and `/legal/terms` is inside one process-wide `ProductReadinessGate`. Those two legal routes are exempt from maintenance/update policy only; because their content is server-backed, they can still show their existing loading or retry state during a backend outage.

Decision precedence is:

1. A first-check transport, HTTP, or malformed-response failure is unavailable and fails closed.
2. Active maintenance blocks the application.
3. `update_required` or `force_update` blocks the application.
4. An optional update allows the application and may show a dismissible prompt.
5. Every other valid response, including `configured=false`, allows the application.

The gate never clears authentication data, performs refresh, consumes push intent, or bypasses the existing router, RBAC, legal-acceptance, and AppShell layers.

## Cold start and resume

Cold start always calls the public token-free endpoint with the real platform, package version, and build number. Until the first valid response, failures fail closed with a safe French retry screen and no raw technical details.

The last successful response and timestamp are held in memory only. No readiness state is persisted. On resume, a successful check less than five minutes old is reused; otherwise the controller rechecks. Explicit retry always bypasses the cooldown. A transient resume failure retains the last successful state, including an existing maintenance or mandatory-update block. There is no polling or timer.

## Application identity and API

- Android package ID: `sn.enactusesp.enactspace`
- iOS bundle ID: `sn.enactusesp.enactspace`
- Release API define: `ENACTSPACE_API_URL`
- Release API URL must be an absolute HTTPS URL.
- The bootstrap request has no bearer or refresh credential.
- Store launches use the external launcher, never authenticated API transport.

## Firebase define names

The PR-5 explicit `FirebaseOptions` strategy remains authoritative. Supply values only through the protected build/release environment:

- `ENACTSPACE_FIREBASE_PROJECT_ID`
- `ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID`
- `ENACTSPACE_FIREBASE_API_KEY_ANDROID`
- `ENACTSPACE_FIREBASE_APP_ID_ANDROID`
- `ENACTSPACE_FIREBASE_API_KEY_IOS`
- `ENACTSPACE_FIREBASE_APP_ID_IOS`

Do not add `google-services.json`, `GoogleService-Info.plist`, the Google Services Gradle plugin, or hardcoded Firebase values. Missing Firebase defines disable push safely and do not disable product readiness.

## Official store destinations

Android accepts only an HTTPS Google Play URL on `play.google.com`, path `/store/apps/details`, with `id=sn.enactusesp.enactspace`. Optional `hl` and `gl` query values are allowed.

iOS accepts only an HTTPS URL on `apps.apple.com` whose normal app path contains the `app` segment and ends in `id` followed by digits.

Userinfo, fragments, HTTP/custom schemes, alternate hosts, IP/localhost destinations, wrong Android package IDs, and malformed paths are rejected. The client does not invent a listing or fall back to search. A forced update with a missing or invalid URL remains blocked and offers another policy check.

## Android release gate

Release signing remains external and fail-closed. Never create or commit `key.properties`, JKS, or keystore material.

Expected unsigned security check:

    flutter build appbundle --release --no-pub --dart-define=ENACTSPACE_API_URL=https://example.invalid

Without externally supplied signing properties, packaging must refuse with `EXTERNAL_SIGNING_REQUIRED`. That refusal is the expected result. A successful signed AAB requires authorized external key material and a protected release environment.

Before production release, validate on a physical Android device:

- Firebase registration for the exact package ID.
- FCM token acquisition and foreground/background delivery.
- Notification tap and terminated-state tap after the readiness gate allows use.
- Mandatory maintenance/update behavior around deep links and push opens.

These real-device FCM checks remain pending.

## iOS macOS/Xcode gate

Windows source validation does not establish production APNs readiness. On macOS with Xcode:

1. Enable Push Notifications for the exact Apple App ID.
2. Enable/confirm Push Notifications on the Runner target.
3. Preserve Background Modes → Remote notifications.
4. Use an external Apple team and distribution provisioning profile.
5. Archive with distribution signing.
6. Inspect the signed entitlements.
7. Confirm the distribution archive has the production `aps-environment` entitlement supplied by authorized provisioning.
8. Validate APNs/FCM on a physical iOS device.

Do not manually invent or commit a team ID, profile UUID, certificate identity, APNs key, or unverified push-capability metadata from Windows. The macOS/Xcode gate and real-device iOS APNs/FCM checks remain pending.

## Version

Keep `version: 1.0.0+1` through PR-6. The build/version increment belongs to the PR-8 release-candidate flow once signed artifacts and store submissions are being produced.
