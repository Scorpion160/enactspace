# Privacy disclosure worksheet

This worksheet inventories behavior visible in the V1.0.0 source at commit `36a6e572b769b275797ddc5dcd18c169b3f7cd1e`. It supports later Google Play Data Safety and Apple App Privacy decisions; it is not a legal notice or a completed store declaration. Legal basis, retention, disclosure wording, and the final answers for both stores are `TO_CONFIRM_LEGAL`.

## Mobile permissions and capabilities

| Surface | Source finding | Product use | Release status |
| --- | --- | --- | --- |
| Android network | App declares `INTERNET`; Firebase Messaging also declares network-state and wake-lock permissions in its plugin manifest | Authenticated API, WebSocket, files, payment provider through backend, and push | Release endpoint must be approved HTTPS; TO_CONFIRM_EXTERNAL |
| Android camera | App and `mobile_scanner` declare `CAMERA` | Scan attendance QR codes | Camera frames are processed by the scanner; no camera-image upload or retained capture was found |
| Android NFC | App declares `NFC`; NFC hardware is optional | Enrol and read attendance badges | Tag payload is sent to the backend, which stores a protected tag identity and audit result |
| Android notifications | App and Firebase Messaging declare `POST_NOTIFICATIONS` | Optional push notifications | User permission and physical delivery remain TO_CONFIRM_EXTERNAL |
| iOS camera | `NSCameraUsageDescription` is present | Scan attendance QR codes | Physical-device behavior remains TO_CONFIRM_EXTERNAL |
| iOS NFC | `NFCReaderUsageDescription` and the TAG reader entitlement are present | Enrol and read attendance badges | App ID capability and physical-device behavior remain TO_CONFIRM_EXTERNAL |
| iOS notifications | `remote-notification` background mode is present | Optional push notifications | No production `aps-environment` is tracked; APNs capability, signing, and delivery remain TO_CONFIRM_EXTERNAL |
| Secure storage | `flutter_secure_storage` | Access/refresh token pair, current-user representation, installation IDs | Secrets are migrated out of legacy preferences and cleared on local logout paths |
| User-selected files | `file_picker` | Member CSV import and user-selected uploads where exposed by the UI | File content leaves the device only when the user submits the relevant workflow |
| Local preferences/cache | `shared_preferences` | Appearance, chat lists/messages and pin/hide choices, media-cache preferences | Chat data is a device-local cache and has an explicit local cache-clear operation |

No runtime request or direct dependency was found for device location, contacts, photo-library selection, microphone/audio recording, advertising ID, analytics, or crash reporting. Manually entered event/interview locations and institutional-memory coordinates are application content, not evidence of device geolocation. Recheck the final resolved native build before submission.

## Code-based data inventory

| Data category | Functional source | Purpose | Local / backend storage | Possible third party | Deletion / retention finding | Required or optional | Google Play | Apple App Privacy |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Account identity and credentials | Login, join, member administration | Authentication, authorization, membership | Auth tokens and current-user representation in secure local storage; name, e-mail, password hash and account state in backend | E-mail provider if enabled: TO_CONFIRM_EXTERNAL | Local credentials can be cleared; backend account deletion is a reviewed request, not immediate erasure; retention TO_CONFIRM_LEGAL | Name/e-mail/password required for account; other fields vary | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Profile and affiliation | Member/alumni profile | Directory, roles, poles, alumni support | Phone, gender, profile type, department, study level, promotion, photo URL, biography and professional links in backend | Hosting/file provider: TO_CONFIRM_EXTERNAL | Account workflow may delete, anonymize, or retain according to an unapproved policy | Mostly optional after core identity | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Recruitment and candidacy | Public/internal recruitment | Application review and candidate conversion | Identity/contact, gender, education, skills, motivation, status, reviews and interview details in backend | E-mail provider if enabled: TO_CONFIRM_EXTERNAL | Retention and deletion rules TO_CONFIRM_LEGAL | Core application fields required; supplemental fields optional | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Organizational activity | Poles, projects, tasks, events, Academy, gamification | Collaboration, learning, recognition and operations | Memberships, assignments, contributions, event participation, progress, badges and points in backend | Hosting provider: TO_CONFIRM_EXTERNAL | Domain retention and account anonymization rules TO_CONFIRM_LEGAL | Depends on chosen feature and assigned role | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Attendance and QR | Attendance sessions and QR check-in | Verify attendance and lateness | QR token transiently scanned; attendance record, timestamps, eligibility and audit state in backend | Hosting provider: TO_CONFIRM_EXTERNAL | Operational retention TO_CONFIRM_LEGAL | Optional app feature; required data when checking in | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| NFC badge identity | NFC enrolment and check-in | Associate a badge with a member and verify attendance | Raw device read is submitted; backend protects the tag identity and exposes masked audit values | Hosting provider: TO_CONFIRM_EXTERNAL | Revoke/replace flows exist; retention after revocation TO_CONFIRM_LEGAL | Optional app feature | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Communications and user content | Posts, comments, reactions, chat | Internal collaboration | Backend stores content, membership and media metadata; device may cache thread/message JSON and pin/hide choices in preferences | Hosting/file provider: TO_CONFIRM_EXTERNAL | Message/thread operations and local cache clear exist; durable retention TO_CONFIRM_LEGAL | Optional | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Files, media and evidence | Documents, chat uploads, task/impact/payment proof | Collaboration, verification and audit | Selected content and filename/type/size/checksum/visibility metadata in backend file storage; cached message metadata locally | Hosting/file provider: TO_CONFIRM_EXTERNAL | Temporary/ephemeral metadata exists; final schedules and deletion rules TO_CONFIRM_LEGAL | Optional unless a workflow requires proof | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Finance and payments | Fees, payment proof, receipts, mobile money | Internal dues, reconciliation and receipts | Amount, currency, method, status, reference, proof/receipt and allocations in backend | When enabled, PayDunya receives customer name, e-mail, phone and transaction data: TO_CONFIRM_EXTERNAL | Financial/audit retention TO_CONFIRM_LEGAL | Optional unless the member uses a payment workflow | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Impact and institutional memory | Impact claims, archives, memory/heritage | Measurement, provenance and institutional continuity | Submitted measures, evidence, contributors, places/coordinates, visibility, review and provenance in backend | Hosting/file provider: TO_CONFIRM_EXTERNAL | Historical integrity may require retention or anonymization; policy TO_CONFIRM_LEGAL | Optional by role/workflow | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Preferences and legal acceptance | Settings and legal gate | User experience, consent/version evidence | Locale/theme/notification choices and immutable acceptance version/source/time in backend; appearance also local | Hosting provider: TO_CONFIRM_EXTERNAL | Acceptance integrity and retention TO_CONFIRM_LEGAL | Preferences optional; required acceptance depends on approved policy | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Support and product feedback | Help tickets and feedback | User support and product improvement | Subject, messages, category, rating, platform, app/build version and administration state in backend | Support/hosting provider: TO_CONFIRM_EXTERNAL | Ticket/feedback retention TO_CONFIRM_LEGAL | Optional | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Session, security and audit metadata | Auth sessions and audit logs | Security, revocation, accountability | Refresh-token hash, platform, user agent, session times; audit actor/action/IP and change metadata in backend | Hosting/logging provider: TO_CONFIRM_EXTERNAL | Session revocation exists; security/audit retention TO_CONFIRM_LEGAL | Generated during authenticated/security operations | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Push installation and delivery | Firebase push lifecycle | Optional notifications and delivery control | Random installation key and server installation ID in secure local storage; backend stores platform, app/build, locale, encrypted token, token hash and delivery state. Current client sends null OS version/device model. | Firebase Cloud Messaging / Apple Push Notification service when configured: TO_CONFIRM_EXTERNAL | Token deletion/revocation paths exist; provider and delivery-log retention TO_CONFIRM_LEGAL | Push is optional | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |
| Runtime font request metadata | `google_fonts` Poppins theme usage | Application typography | Library-managed device cache; no EnactSpace backend record identified | Google font endpoint may receive network metadata because no bundled Poppins asset or runtime-fetch disablement was found: TO_CONFIRM_EXTERNAL | Cache/provider handling TO_CONFIRM_LEGAL | Generated when a runtime font fetch occurs | TO_CONFIRM_LEGAL | TO_CONFIRM_LEGAL |

The backend personal-data export intentionally excludes passwords, JWTs, tokens, secrets, internal credentials, and other users' private data. The draft privacy policy states that a deletion request opens a review workflow and that deletion, anonymization, retention categories, and periods require institutional approval.

## Third-party packages relevant to store review

Resolved versions are from `frontend/pubspec.lock`.

| Package | Version | Review relevance |
| --- | --- | --- |
| `firebase_core` | `4.14.0` | Firebase initialization; provider project remains external |
| `firebase_messaging` | `16.6.0` | FCM/APNs token and message delivery |
| `flutter_secure_storage` | `10.3.1` | Keychain/secure platform storage |
| `mobile_scanner` | `7.2.0` | Camera-based QR scanning |
| `nfc_manager` | `4.2.1` | NFC tag access |
| `file_picker` | `10.3.10` | User-selected files |
| `shared_preferences` | `2.5.5` | Device preferences and chat cache |
| `package_info_plus` | `9.0.1` | Application version/build discovery |
| `google_fonts` | `8.1.0` | Font loading/caching behavior must be checked in the final release build |
| `http` / `web_socket_channel` | `1.6.0` / `3.0.3` | API and realtime network transport |
| `url_launcher` | `6.3.2` | Opens approved external destinations |
| `uuid` | `4.6.0` | Locally generated random installation key; not a hardware identifier |

## iOS Privacy Manifest assessment

No app-level `PrivacyInfo.xcprivacy` or iOS `Podfile` is tracked. The resolved Flutter package cache contains privacy manifests for `firebase_messaging`, `shared_preferences_foundation`, `flutter_secure_storage_darwin`, `file_picker`, `mobile_scanner`, `package_info_plus`, and `url_launcher_ios`; the first two declare UserDefaults required-reason API use, and the inspected package manifests declare no tracking or collected-data types.

This inspection does not prove what a future resolved native iOS build will contain. The resolved native iOS/Firebase dependencies, manifest aggregation, required-reason API report, final Xcode archive, and store declarations must be verified on the authorized macOS build environment: `TO_CONFIRM_EXTERNAL`. No app-level manifest is added by this repository-only audit because the current evidence does not justify arbitrary declarations. Legal/store characterization of collected data remains `TO_CONFIRM_LEGAL`.
