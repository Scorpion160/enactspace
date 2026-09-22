"""Fail fast when a Phase 0B preflight artifact is structurally unsafe."""
from __future__ import annotations

import csv
import sys
from pathlib import Path


CATALOG = Path(__file__).resolve().parents[1]
PLAN = CATALOG / "preflight_plan.csv"
DRIVERS = CATALOG / "preflight_drivers.csv"
REQUIRED_PREFLIGHT_COLUMNS = {
    "preflight_id", "scenario_driver", "role", "test_account_alias", "viewport",
    "orientation", "data_profile", "network_profile", "initial_route",
    "expected_final_route", "setup_action", "interaction_steps", "expected_markers",
    "forbidden_markers", "teardown_action", "status",
}
REQUIRED_ROW_VALUES = {
    "preflight_id", "scenario_driver", "expected_markers", "teardown_action", "status",
}


def read_checked(path: Path, required: set[str]) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        if set(reader.fieldnames or []) != required:
            raise RuntimeError(f"{path.name}: expected exact columns {sorted(required)}; got {reader.fieldnames}")
        rows = list(reader)
    if not rows:
        raise RuntimeError(f"{path.name}: no data rows")
    for index, row in enumerate(rows, start=2):
        if None in row or None in row.values():
            raise RuntimeError(f"{path.name}:{index}: extra or unattached CSV value")
        if set(row.keys()) != required:
            raise RuntimeError(f"{path.name}:{index}: row keys differ from required schema")
        missing_values = sorted(key for key in REQUIRED_ROW_VALUES if not row[key].strip())
        if missing_values:
            raise RuntimeError(f"{path.name}:{index}: blank required values: {', '.join(missing_values)}")
    return rows


def main() -> None:
    plan = read_checked(PLAN, REQUIRED_PREFLIGHT_COLUMNS)
    with DRIVERS.open(newline="", encoding="utf-8-sig") as handle:
        drivers = list(csv.DictReader(handle))
    ready = {item["scenario_driver"] for item in drivers if item.get("runtime_ready") == "true"}
    unresolved = [item["scenario_driver"] for item in plan if item["scenario_driver"] not in ready]
    if unresolved:
        raise RuntimeError(f"preflight_plan.csv: non-runtime-ready drivers: {', '.join(unresolved)}")
    print(f"VALID preflight_plan.csv: {len(plan)} rows; 16 exact columns; 12 runtime-ready drivers")


if __name__ == "__main__":
    try:
        main()
    except RuntimeError as error:
        print(f"INVALID: {error}", file=sys.stderr)
        raise SystemExit(1)
