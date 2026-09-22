# PR-2D institutional-memory validation

PR-2D adds a normalized, authenticated institutional-memory foundation. New
historical objects use `year`, `start_year`, `end_year`, or exact dates; they do
not extend the legacy `Season` vocabulary. A year-only event keeps
`event_date=null`.

The validation lifecycle is `HISTORICAL_REPORTED`, `EVIDENCE_PENDING`,
`EVIDENCE_ATTACHED`, `UNDER_REVIEW`, `VERIFIED`, `REJECTED`, and `SUPERSEDED`.
New facts default to `HISTORICAL_REPORTED`. Attaching an `InstitutionalSource`
does not verify a fact; verification is an explicit SG/Team Leader/admin action
and requires structured provenance.

Run SQLite and backend regressions from `backend`:

```powershell
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
$env:SECRET_KEY = 'replace-with-an-ephemeral-test-secret-at-least-32-characters'
python -m unittest test_security_mobile_foundation test_account_privacy_legal test_auth_sessions test_impact_truth test_impact_truth_sqlite_migration test_institutional_memory test_institutional_memory_migration -v
python -m alembic heads
```

Run PostgreSQL 16 acceptance with the existing loopback-only, tmpfs-backed
Compose service. Tests create and drop only random isolated schemas whose names
start with `pr2b_`, `pr2c_`, `pr2clegacy_`, or `pr2d_` inside the explicitly
named disposable `enactspace_pr2b_test` database:

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
docker compose -p enactspace-pr2b-test -f docker-compose.test.yml up -d --wait
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:55432/enactspace_pr2b_test"
python -m unittest test_auth_sessions_postgresql test_impact_truth_postgresql test_institutional_memory_postgresql -v
python -m alembic heads
docker compose -p enactspace-pr2b-test -f docker-compose.test.yml down
Remove-Item Env:TEST_DATABASE_URL, Env:PR2B_TEST_DB_PASSWORD, Env:SECRET_KEY, Env:APP_ENV, Env:AUTO_CREATE_TABLES, Env:DATABASE_URL -ErrorAction SilentlyContinue
```

The PostgreSQL test refuses non-local hosts and database names outside the
dedicated `enactspace_pr2b_test` namespace. Cleanup drops only its random
`pr2d_` schema. The Compose teardown removes only the explicitly named test
project and its disposable tmpfs database.

Run Flutter validation from `frontend`:

```text
flutter analyze --no-pub
flutter test --no-pub
```

The existing archive fixtures remain compatibility data. They are not copied
into normalized tables and are never automatically marked `VERIFIED`.
