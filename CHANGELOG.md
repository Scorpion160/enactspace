# Changelog

All notable release changes should be recorded here. Dates represent repository milestones, not proof of deployment.

## [Unreleased]

### Repository operations

- Replace obsolete Python template workflows with application CI for FastAPI, PostgreSQL 16, Flutter, web, and Android debug builds.
- Add dependency and repository-material security checks plus Dependabot coverage.
- Move the direct `cryptography` constraint to the fixed 50.x line after the dependency audit identified 48.x advisories.
- Add governance, maintainer, operations, release, and Pôle IT handoff documentation.
- Align backend application metadata with the V1.0.0 release target.
- Remove obsolete reusable demo credentials from tracked documentation.

### External closure gates

- Obtain at least one successful replacement GitHub CI run after Actions billing/execution is restored, unless the repository owner documents an exception.
- Establish protected `main` governance and required checks when repository capability permits, or document the approved manual fallback.
- Map formal Pôle IT GitHub handles/team.
- Complete PR-8 mobile signing, provider, physical-device, and store-release gates.

## [1.0.0] - Unreleased

V1.0.0 remains the release target. No tag or production-release claim is made by this changelog entry.
