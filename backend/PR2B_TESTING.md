# PR-2B session validation

Run from `backend` with the project's Python environment. No production database
is used. The normal developer Compose file has a fixed container name and a
persistent volume; `docker-compose.test.yml` instead uses the same PostgreSQL 16
image in a separate Compose project, a loopback-only port and disposable tmpfs.

PowerShell (generate credentials for this run; do not save or log them):

```powershell
$env:APP_ENV = 'test'
$env:AUTO_CREATE_TABLES = 'false'
$env:DATABASE_URL = 'sqlite://'
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
docker compose -p enactspace-pr2b-test -f docker-compose.test.yml up -d --wait
$env:TEST_DATABASE_URL = "postgresql+psycopg://pr2b_test:$($env:PR2B_TEST_DB_PASSWORD)@127.0.0.1:55432/enactspace_pr2b_test"
python -m unittest test_security_mobile_foundation test_account_privacy_legal test_auth_sessions test_auth_sessions_postgresql -v
python -m alembic heads
docker compose -p enactspace-pr2b-test -f docker-compose.test.yml down
Remove-Item Env:TEST_DATABASE_URL, Env:PR2B_TEST_DB_PASSWORD, Env:SECRET_KEY, Env:APP_ENV, Env:AUTO_CREATE_TABLES, Env:DATABASE_URL -ErrorAction SilentlyContinue
```

Use an unused `PR2B_TEST_DB_PORT` and adjust the URL if 55432 is occupied. Review
the named Compose project's containers before `down`; it deletes only this test
project's disposable database. The tests additionally create/drop only a randomly
named `pr2b_...` schema. They reject non-local hosts and databases without the
`enactspace_pr2b_test` prefix. Missing PostgreSQL configuration produces an explicit
skip, **not** PostgreSQL validation success.

The PostgreSQL suite applies Alembic from an empty schema to the single existing
head, reuses the lifecycle tests, checks unique/index/check constraints and runs
five rounds of three simultaneous transactions on three distinct connections.
The Alembic environment escapes percent signs for ConfigParser so URL-encoded
connection options (including the isolated schema's search path) remain intact.
Each round must have exactly one successful rotation and one surviving session
row. Additional concurrent revocation/rotation cases cover current-session,
individual-session and logout-all lock ordering, including audit foreign keys.
SQLite tests are regression coverage, not concurrency evidence.

From `frontend`:

```text
flutter analyze --no-pub
flutter test --no-pub test/auth_storage_test.dart test/auth_session_test.dart
flutter test --no-pub
```

## Security invariants and limits

- The existing opaque credential and HMAC-SHA256 storage format are unchanged.
  Rotation replaces the hash on the same session, holding database locks through
  commit. User locks precede session locks for login, refresh and revocation. A rollback
  does not consume the credential. There is no historical family-token ledger:
  replay is rejected, without revoking a legitimate winning rotation.
- Session expiry remains absolute. PR-2A's timestamp-without-time-zone fields
  store UTC; comparisons also accept aware timestamps. No schema migration is
  needed. Access JWT `sub`, `exp` and optional `sid` remain; `jti` makes separately
  issued access credentials distinct even in the same second.
- Flutter stores the pair as one secure value, preserves the PR-1 legacy-access
  migration, coordinates refresh across API clients sharing that store, and
  retries an authenticated 401 once. Public/auth-control calls and 403s do not
  trigger refresh. Buffered bodies/multipart requests are rebuilt for retry.
- A session-generation guard prevents old refresh/profile responses from
  overwriting logout or a subsequent login. Definitive refresh rejection clears
  local secrets; transport errors and temporary server failures retain them.
- A lost refresh response after the server commits cannot be recovered by
  replaying the consumed credential. The next definitive rejection requires a
  new login. This intentionally does not weaken the one-use invariant with a
  replay grace window.
- Logout waits for an already-running refresh, clears local credentials, and
  attempts revocation. Offline current-session logout cannot guarantee server
  revocation. Logout-all explicitly rotates once after an authentication
  rejection, retries revocation once, reports any remote failure, and always
  clears local secrets. Legacy access-only JWTs without `sid` retain their original
  expiry semantics; there is no existing session to revoke for those tokens.
- The PR-2A deletion-request workflow is unchanged; a request is not itself an
  account deletion. Disabled, unverified and non-active/non-alumni accounts cannot
  refresh. No impact, memory, device-installation or push feature is added.
