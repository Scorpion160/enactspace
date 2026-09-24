# Test matrix

CI and release evidence are based on behavior families, not fixed test counts.

| Family | Primary evidence | PostgreSQL required |
| --- | --- | --- |
| Auth and refresh sessions | Backend unit, rotation, revocation, logout, concurrent refresh | Yes for rotation/concurrency |
| Account, privacy, and legal | Backend policy and lifecycle tests | Where migration/constraints apply |
| Impact truth and provenance | Claim state, canonical totals, provenance, migration tests | Yes |
| Institutional memory | Visibility, validation, lifecycle, migration tests | Yes |
| Product services | Domain behavior, constraints, migration tests | Yes |
| Push lifecycle | Token protection, delivery state, retries, migration tests | Yes |
| Operational integrity | State transitions, authority, migration tests | Yes |
| PR-6.6 memory/heritage | Capture provenance, final-state authority, 0007↔0008 round trip | Yes |
| Flutter regression | Widget/unit/service tests and static analysis | No |
| Build checks | Web release compile and Android debug compile | No |

## Shared backend gate

Run backend compilation, OpenAPI generation, assert the single Alembic head `20260913_0009`, and run `python -m unittest discover -v` with the safe split configuration: SQLite application engine plus an isolated PostgreSQL 16 `TEST_DATABASE_URL`. PostgreSQL-dependent suites must not skip because the test URL is absent or invalid.

## Shared Flutter gate

Run `flutter pub get`, verify `frontend/pubspec.lock` is unchanged, then run `flutter analyze --no-pub`, `flutter test --no-pub`, the release web build against `https://example.invalid`, and the unsigned Android debug build.

The last observed pre-PR-7 baseline was 204 backend tests and 604 Flutter tests. These counts are informational snapshots only and must never be hard-coded as CI pass conditions; suites may grow.

Physical Android FCM, physical iOS APNs/FCM, signed mobile archives, store metadata, backup restoration, and production smoke tests are separate evidence gates in the release checklist.
