# EnactSpace UI Audit - Runtime Environment (Phase 0B)

## Frozen reference

| Item | Value |
| --- | --- |
| Functional reference commit | `7f0a9fd5ade92c1fbe88e9316016fab299c0005a` |
| Audit branch | `audit/ui-visual-catalog-phase0` |
| Date / timezone | 2026-07-25 / UTC |
| System locale | `en-US` |
| Flutter framework | `3.46.0-0.3.pre` (local SDK metadata) |
| Dart SDK | `3.13.0-103.1.beta` |
| Browser planned | Microsoft Edge `150.0.4078.99` |
| Docker client / Compose | `29.5.2` / `v5.1.3` |
| URL strategy | `hash_strategy` (detected without capture) |
| Visual mode | light mode; OS font size and display scale to be recorded at pilot launch |

The app source must remain at the reference commit for runtime validation. This
branch contains audit material only; no application source, production config,
or deployment material is changed.

## Isolated local topology

```text
Microsoft Edge (localhost only)
        |
        | http://127.0.0.1:18080 and http://127.0.0.1:18002
        v
enactspace_ui_audit_gateway
        |
        +---- exposure bridge (gateway only)
        |
        +---- internal Docker network ---- web / backend / postgres
```

The Compose definition is `tools/docker-compose.ui_audit.yml`. Docker is
operational and it uses four services:

- `enactspace_ui_audit_gateway`, `enactspace_ui_audit_backend`,
  `enactspace_ui_audit_postgres`, and `enactspace_ui_audit_web`;
- an `internal: true` Docker network named `enactspace_ui_audit_network`;
- only the gateway binds `127.0.0.1:18002` and `127.0.0.1:18080`; PostgreSQL,
  backend, and web publish no host port;
- distinct audit-only named volumes; and
- a local `backend/.ui_audit/.env` file, generated locally and excluded from Git.

## Isolation proof and safeguards

1. The local environment has no VPS host, production hostname, Cloudflare
   tunnel, SMTP hostname, push key, OAuth configuration, payment credential,
   webhook endpoint, analytics endpoint, or Mobile Money endpoint.
2. `APP_ENV=ui_audit`; `EMAIL_ENABLED=false`; `PUSH_ENABLED=false`;
   `PAYMENT_PROVIDER_ENABLED=false`; `MOBILE_MONEY_ENABLED=false`; and
   `MOBILE_MONEY_PROVIDER=mock` are mandatory in the local secret file.
3. The database URL is accepted by the seed script only when its host is
   `postgres` and its database name is `enactspace_ui_audit`. Any other URL
   makes the script exit before it can write.
4. Seed identities use only `@example.test`. Test passwords exist solely in
   the ignored local environment file and are never written to Markdown or CSV.
5. Docker was inspected locally: no existing containers, custom networks, or
   volumes were found in the elevated local Docker session before setup.

## Reproducible workflow (not executed as capture work)

1. Run `tools/new_ui_audit_environment.ps1` to generate the ignored local
   environment file and start the four audit containers, including the hardened
   Nginx gateway.
2. Run `tools/seed_ui_audit.py` in the backend container to reset only the
   guarded audit database and create deterministic fixtures.
3. Build the local Flutter web bundle with
   `--dart-define=ENACTSPACE_API_URL=http://127.0.0.1:18002`,
   `--pwa-strategy=none`, and output `frontend/build/ui_audit_web`; serve it
   from the audit web container. The build manifest records the exact commit,
   SDK version and SHA-256 of `main.dart.js`.
4. Run `tools/validate_preflight_artifacts.py` before any browser target is
   created. The capture-free preflight runner writes contract diagnostics only.

## Current execution status

The fresh audited web bundle is available at
`frontend/build/ui_audit_web`; no service-worker asset was generated with the
selected PWA strategy. The runner also clears caches and unregisters service
workers for every temporary Edge target.

The bundle contains the `google_fonts` runtime URL pattern for
`fonts.gstatic.com`. Audit policy is to block it with every other non-loopback
request, log it in `external_requests.csv`, and assess the local fallback font
rendering. The audit must not fetch fonts or any other external resource.

Docker and the guarded seed are ready. Browser targets created by the contract
runner stay loopback-only, block every non-local request, and never capture pixels.

## Current local state

The three internal application services and the guarded fixture seed are healthy. A
hardened Nginx gateway is the sole loopback entry point: it exposes the web on
`127.0.0.1:18080` and the API on `127.0.0.1:18002`, while backend, web and
PostgreSQL keep no published port and remain on the internal audit network.
Historical preflight outputs are archived before every new run. The active run
manifest binds its outputs to the current plan, runner, driver list, and bundle hash.

The served `main.dart.js` SHA-256 is
`FBDFD7E496163918A9032BE0A1012F2F41DC9A3DD2C4374F4FC0BC6D0002A7E6`.
No pilot capture has been run in Phase 0B preparation.
