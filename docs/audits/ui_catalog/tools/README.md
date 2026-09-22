# Phase 0B local audit tools

These tools are intentionally outside application source. They create only the
isolated local Docker environment described in `../runtime_environment.md`.

- `new_ui_audit_environment.ps1` creates the ignored
  `backend/.ui_audit/.env`, starts the isolated containers and runs fixtures.
- `docker-compose.ui_audit.yml` binds only loopback ports and uses an internal
  Docker network.
- `seed_ui_audit.py` must refuse any database URL other than the exact local
  audit database before it drops or creates tables.
- `start_edge_ui_audit.ps1` starts an isolated Edge profile with CDP on port
  `9222`; `capture_pilot.py` has a preflight mode and requires `--execute` for
  any screenshot.
- `requirements.audit.txt` pins the runner-only dependency. The local audit
  venv lives in the isolated Docker volume and uses the matching dependency
  already present in the backend image; the internal audit network deliberately
  has no package-index DNS access.
- `generate_pilot_plan.ps1`, `generate_selectors_inventory.ps1`, and
  `generate_scenario_drivers.ps1` regenerate the checked audit inventories
  without modifying `frontend/lib` or `backend/app`.
- `env.ui_audit.example` documents names only. It contains no usable secret.

No tool in this directory is permitted to load a production environment file,
use a real identity, send email or push, or call a real payment provider.
