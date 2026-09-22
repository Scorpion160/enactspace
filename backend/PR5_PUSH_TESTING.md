# PR-5 push lifecycle validation

## Architecture

Notification creation writes `Notification` and eligible `PushDelivery` rows in the
same database transaction. No provider request occurs in an HTTP request. The worker
claims due rows with `FOR UPDATE SKIP LOCKED`, revalidates the account preference,
installation ownership, revocation state, feature flag, and token-hash snapshot, then
sends through the Firebase Admin adapter. Retry records contain only bounded safe error
codes.

Claims carry a five-minute database processing lease. Pending and retry rows are due by
`next_attempt_at`; abandoned processing rows become claimable only after that lease
expires. A fresh processing lease is never reclaimed. Delivery is intentionally
at-least-once: if a process crashes after FCM accepts a message but before the final
database commit, lease recovery can send a duplicate. The implementation does not claim
exactly-once provider delivery.

Push state uses one database lock order: user, user preference, installations ordered by
ID, then push deliveries. Auth flows retain their established user-to-session order and
continue into the push order. The worker holds the same user-scoped locks across its
final revalidation and provider call, so a completed disable, revoke, rotation, or
logout-all fences any send that has not already started. An already in-flight provider
call cannot be recalled.

FCM registration tokens are normalized, SHA-256 hashed for uniqueness, and Fernet
encrypted with a dedicated key. Raw tokens are excluded from response schemas, account
exports, audit values, outbox rows, and routine logs.

## Configuration

Production push requires:

- `PUSH_ENABLED=true` (or the legacy feature flag `NOTIFICATION_PUSH_ENABLED=true`)
- `FIREBASE_PROJECT_ID`
- `PUSH_TOKEN_ENCRYPTION_KEY`
- external Google Application Default Credentials, normally selected through
  `GOOGLE_APPLICATION_CREDENTIALS` without copying credential contents into the repo

`FCM_SERVER_KEY` is retained only as an unused backward-compatible environment name;
it does not power delivery. The push encryption key must differ from every JWT/auth
secret. Generate a Fernet key outside the repository:

```powershell
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Store the generated value only in the deployment secret manager/environment.

## Migration and worker

```powershell
python -m alembic upgrade 20260906_0006
python -m alembic heads
python -m app.workers.push_worker --once
```

The worker may also run continuously without `--once`. Multiple PostgreSQL workers can
claim independent batches without simultaneously claiming the same delivery.

## Automated validation

```powershell
python -m unittest test_push_lifecycle.py test_push_lifecycle_migration.py
python -m unittest discover -p "test*.py"
```

PostgreSQL 16 uses the existing isolated disposable test service:

```powershell
docker compose -p enactspace-pr5-test -f docker-compose.test.yml up -d postgres
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$env:PR2B_TEST_DB_PASSWORD@127.0.0.1:55432/enactspace_pr2b_test"
python -m unittest test_push_lifecycle_postgresql.py
docker compose -p enactspace-pr5-test -f docker-compose.test.yml down
```

Flutter fake-adapter tests, analysis, and an Android build require no Firebase client
configuration. Optional client values are supplied with `--dart-define` using:

- `ENACTSPACE_FIREBASE_PROJECT_ID`
- `ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID`
- `ENACTSPACE_FIREBASE_API_KEY_ANDROID`
- `ENACTSPACE_FIREBASE_APP_ID_ANDROID`
- `ENACTSPACE_FIREBASE_API_KEY_IOS`
- `ENACTSPACE_FIREBASE_APP_ID_IOS`

Missing values disable push without requesting permission or blocking startup.

## Logout and external prerequisites

Account-level disable clears tokens and unsent deliveries for every installation.
Logout-all additionally revokes every installation server-side. Current-device logout
performs best-effort token removal and installation revocation before the existing auth
logout; push cleanup failure never prevents local logout.

Firebase Admin credentials, Firebase project registration, Android application
registration, Apple Push Notifications capability, APNs key/certificate, signing, and
real-device checks are external deployment prerequisites. No Firebase client config or
provider credential is committed.

AUTOMATED PUSH LIFECYCLE: validated

REAL FCM/APNs DEVICE DELIVERY: pending external configured-device validation
