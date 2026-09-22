# PR-3 product-services validation

PR-3 adds privacy-first app installations, effective global notification
preferences, support tickets, product feedback, persisted releases and runtime
policies, and the unauthenticated `/api/product/bootstrap` decision endpoint.
It does not store push tokens or hardware identifiers and does not contact push
or app-store services.

Runtime comparisons use positive build numbers for Android, iOS, and Web;
human-readable version strings are never compared lexically.

App installations are deleted with their account. Support tickets and product
feedback use restrictive user foreign keys so account deletion must explicitly
anonymize or retain them under the existing reviewed deletion workflow rather
than silently destroying historical support records. Message authors,
assignments, release creators, and policy editors become `NULL` if a referenced
user is removed. User data export includes owned installations, tickets,
authored support messages, user-submitted feedback, and the push preference.
Feedback `admin_note` is internal moderation metadata: it is visible only to
authorized management and is omitted from ordinary user responses and exports.

Run the focused and regression suites from `backend`:

```powershell
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
$env:SECRET_KEY = 'replace-with-an-ephemeral-test-secret-at-least-32-characters'
python -m unittest test_product_services test_product_services_migration -v
python -m unittest test_security_mobile_foundation test_account_privacy_legal test_auth_sessions test_impact_truth test_impact_truth_sqlite_migration test_institutional_memory test_institutional_memory_migration test_product_services -v
python -m alembic heads
```

Run real PostgreSQL 16 acceptance with the existing loopback-only, tmpfs-backed
Compose service. The test creates and drops only a random `pr3_...` schema in
the disposable `enactspace_pr2b_test` database:

```powershell
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$secretBytes = New-Object byte[] 48
$rng.GetBytes($secretBytes)
$env:SECRET_KEY = -join ($secretBytes | ForEach-Object { $_.ToString("x2") })
$passwordBytes = New-Object byte[] 32
$rng.GetBytes($passwordBytes)
$env:PR2B_TEST_DB_PASSWORD = -join (
    $passwordBytes | ForEach-Object { $_.ToString("x2") }
)
$rng.Dispose()
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
docker compose -p enactspace-pr3-test -f docker-compose.test.yml up -d --wait
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:55432/enactspace_pr2b_test"
python -m unittest test_product_services_postgresql -v
docker compose -p enactspace-pr3-test -f docker-compose.test.yml down
Remove-Item Env:TEST_DATABASE_URL, Env:PR2B_TEST_DB_PASSWORD, Env:SECRET_KEY, Env:APP_ENV, Env:AUTO_CREATE_TABLES, Env:DATABASE_URL -ErrorAction SilentlyContinue
```

Run Flutter regression from `frontend`:

```text
flutter analyze --no-pub
flutter test --no-pub
```
