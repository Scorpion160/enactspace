# PR-2C impact truth validation

PR-2C makes `ImpactMetric` the canonical impact claim. A realized project or
organization value is present only when the selected claim has
`claim_type=MEASURED` and `validation_status=VERIFIED`. Missing values are JSON
`null`; an explicitly verified measured zero remains numeric `0`.

The compatibility fields on `ImpactProject` remain writable and readable, but
they do not feed realized totals. Existing non-zero compatibility values are
preserved by migration as unverified `HISTORICAL_CLAIM` rows. Existing default
zeros become unknown. The dashboard no longer publishes anonymous historical
figures or synthetic impact/readiness scores.

`/impact/projects` now includes a `claims` list with semantic key, value, unit,
claim type, validation status, period, population scope, source/reference,
methodology, limitations, evidence count, authorship, validation metadata and
supersession. Its realized numeric fields are nullable. `/impact/summary` keeps
the existing realized-total keys as nullable values and adds `claim_overview`;
`historical_impact` is `null` until persisted provenance-aware historical claims
exist. CSV exports contain one typed claim per row and leave unknown values
blank.

The canonical validation lifecycle is `DRAFT`, `EVIDENCE_PENDING`,
`EVIDENCE_ATTACHED`, `UNDER_REVIEW`, `VERIFIED`, `REJECTED`, `SUPERSEDED`.
Legacy status strings remain response/input aliases. Final states can only be
reached through the dedicated validation, rejection, or supersession flow.
Validating a parent record or evidence does not validate a claim.
A replacement leaves the previous verified claim active until the replacement
itself is verified. Claim verification also requires a source reference, a
direct evidence file, or a linked impact-evidence row.

Run SQLite/backend regressions from `backend`:

```powershell
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
$env:SECRET_KEY = 'replace-with-an-ephemeral-test-secret-at-least-32-characters'
python -m unittest test_security_mobile_foundation test_account_privacy_legal test_auth_sessions test_impact_truth test_impact_truth_sqlite_migration -v
python -m alembic heads
```

Run PostgreSQL 16 acceptance using the existing loopback-only, tmpfs-backed
Compose database. The tests create and drop only random `pr2c_...` and
`pr2clegacy_...` schemas inside the explicitly named disposable PR-2B test
database:

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
python -m unittest test_auth_sessions_postgresql test_impact_truth_postgresql -v
python -m alembic heads
docker compose -p enactspace-pr2b-test -f docker-compose.test.yml down
Remove-Item Env:TEST_DATABASE_URL, Env:PR2B_TEST_DB_PASSWORD, Env:SECRET_KEY, Env:APP_ENV, Env:AUTO_CREATE_TABLES, Env:DATABASE_URL -ErrorAction SilentlyContinue
```

Run Flutter validation from `frontend`:

```text
flutter analyze --no-pub
flutter test --no-pub test/impact_truth_test.dart test/alumni_gamification_academy_impact_test.dart test/projects_portfolio_test.dart
flutter test --no-pub
```

The project aggregate deliberately selects one latest verified measured claim
per semantic key. It does not silently add population scopes or periods because
their overlap cannot be inferred safely. Explicit aggregate claims are required
when multiple measurements must be combined.
