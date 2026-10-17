# Changelog

## 1.0.13+16 — 2026-10-10

- Web publié et APK Android installé; API 1.0.13 déployée avec le schéma 20261007_0031.
- Conversations avec soi-même refusées; séparation membres/alumni pour les listes et statistiques.
- Annuaire alumni interne et gestion des profils admin/SG corrigés; parcours disciplinaire avec approbations et exécution datée.
- Aide : mot de passe personnel. Recrutement : photo Haffé 2022 et accueil amélioré. Connexion : photo de terrain, logo translucide et accroche approuvée.
- Mails/push activés sans redirection de test; Mobile Money reste désactivé.
- Correctif ciblé de première connexion administratrice ajouté après la release, conservé dans b152677; validation réelle en attente.
- Documentation alignée sur les comptes rendus opérateur; voir [preuves et limites](docs/releases/20261010-release-1.0.13.md).

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
