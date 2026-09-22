# PR-6.5 operational integrity validation

PR-6.5 centralizes operational lifecycle reconciliation, enforces explicit
project/task/attendance/recruitment transitions, fences identity invariants in
revision `20260909_0007`, and serializes high-risk mutations with PostgreSQL row
locks. Test data must remain isolated from production and development data.

## Portable backend validation

Run from `backend`:

```powershell
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
$env:SECRET_KEY = 'replace-with-an-ephemeral-test-secret-at-least-32-characters'
python -m unittest test_operational_integrity test_operational_integrity_migration -v
python -m unittest discover -v
python -m compileall -q app
python -c "from app.main import app; schema = app.openapi(); assert schema['openapi']; print(len(schema['paths']))"
python -m alembic heads
```

The only expected Alembic head is `20260909_0007`.

## Disposable PostgreSQL 16 acceptance

The existing Compose service is loopback-only and stores PostgreSQL data on a
temporary filesystem. The test creates and drops a random `pr65_...` schema.
Use a PR-6.5-specific Compose project so unrelated containers and networks are
not modified.

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
$env:PR2B_TEST_DB_PORT = '55465'

docker compose -p enactspace-pr65-test -f docker-compose.test.yml up -d --wait
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:$($env:PR2B_TEST_DB_PORT)/enactspace_pr2b_test"
python -m unittest test_operational_integrity_postgresql -v
docker compose -p enactspace-pr65-test -f docker-compose.test.yml down

Remove-Item Env:TEST_DATABASE_URL, Env:PR2B_TEST_DB_PASSWORD, Env:PR2B_TEST_DB_PORT, Env:SECRET_KEY, Env:APP_ENV, Env:AUTO_CREATE_TABLES, Env:DATABASE_URL -ErrorAction SilentlyContinue
```

### Portable PostgreSQL 16 on Windows

Docker Compose is optional for this acceptance suite. A portable PostgreSQL 16
runtime on Windows is also accepted and does not require installing or starting
a Windows service, or restarting Docker. Bind it only to `localhost` or
`127.0.0.1` and use a dedicated disposable database whose name starts with
`enactspace_pr2b_test`.

Set `TEST_DATABASE_URL` only to that dedicated test database and generate a new
ephemeral `SECRET_KEY` for the validation process. The suite creates a random
isolated `pr65_*` schema, migrates and tests only inside it, and drops that schema
after completion. Never place a real password, connection string, or generated
secret in this document or in Git.

The PostgreSQL suite covers these committed-state races:

1. global Team Leader assignment;
2. pole leader assignment;
3. project leader assignment;
4. concurrent attendance close;
5. concurrent attendance penalty creation;
6. QR/NFC/manual attendance identity;
7. double manual payment validation;
8. payment validation versus rejection;
9. Mobile Money IPN versus refresh finalization;
10. refresh versus reconciliation finalization;
11. duplicate provider event;
12. concurrent candidate conversion;
13. duplicate campaign/email application;
14. last event seat;
15. role assignment versus suspension.
16. Enactrice and Alumni lifecycle preservation;
17. conversion versus application deletion;
18. conversion versus campaign deletion;
19. cross-campaign case-insensitive user conversion;
20. concurrent active Mobile Money initiation and terminal retry.

If a test is interrupted, its class cleanup normally drops only its random
schema. The Compose `down` command above removes only the dedicated PR-6.5
container/network; the database uses `tmpfs`, so no persistent volume is
created.

## Flutter validation

Run from `frontend`:

```powershell
flutter test --no-pub test/operational_integrity_test.dart
flutter test --no-pub test/dashboard_tasks_test.dart test/poles_management_test.dart test/poles_portfolio_test.dart test/projects_management_test.dart test/projects_portfolio_test.dart test/projects_team_test.dart test/recruitment_campaigns_test.dart test/recruitment_conversion_test.dart test/recruitment_internal_test.dart test/recruitment_public_test.dart test/events_documents_test.dart
flutter analyze --no-pub
flutter test --no-pub
```

The full Flutter total must exceed the 595-test PR-6 baseline and every test
must pass.
