"""Package a Web release candidate without publishing it.

Run only after generating build/web with the correct API URL and copying the
verified, pinned *public* production Firebase worker into build/web.
The resulting archive is checked using the same extractor as the VPS publisher.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tarfile
import tempfile
from pathlib import Path

from check_web_release_metadata import expected_version, inspect_built_web, sha256
from publish_web_release import extract_bundle

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "frontend/build/web"
OUT = ROOT / "frontend/build/release-candidate"
REQUIRED = ("index.html", "main.dart.js", "flutter_bootstrap.js", "firebase-messaging-sw.js", "version.json")


def validate_sha(s: str) -> str:
    if not re.fullmatch(r"[a-f0-9]{64}", s.lower()):
        raise ValueError("A 64-character SHA256 is required")
    return s.lower()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--worker-sha256", required=True)
    parser.add_argument("--live-main-sha256", required=True)
    parser.add_argument("--live-version", required=True)
    parser.add_argument("--live-build", required=True)
    args = parser.parse_args()

    pinned_worker = validate_sha(args.worker_sha256)
    observed_live = validate_sha(args.live_main_sha256)
    version, build = expected_version()
    inspection = inspect_built_web(version, build)
    worker = WEB / "firebase-messaging-sw.js"
    if not inspection["firebase_worker_initialized"] or sha256(worker) != pinned_worker:
        raise RuntimeError("Firebase worker differs from the verified public production worker")
    for name in REQUIRED:
        if not (WEB / name).is_file():
            raise RuntimeError(f"Missing Web release file: {name}")

    OUT.mkdir(parents=True, exist_ok=True)
    archive = OUT / f"enactspace-web-{version}-build{build}-candidate.tar.gz"
    if archive.exists():
        raise FileExistsError("Candidate archive exists; refusing to overwrite")

    source_files = sorted(p for p in WEB.rglob("*") if p.is_file())
    for path in WEB.rglob("*"):
        if path.is_symlink():
            raise RuntimeError("Unsafe symlink inside Web candidate")
    with tarfile.open(archive, mode="w:gz") as tar:
        for path in source_files:
            tar.add(path, arcname=path.relative_to(WEB).as_posix(), recursive=False)

    main_digest = sha256(WEB / "main.dart.js")
    with tempfile.TemporaryDirectory(prefix="enactspace-web-archive-check-") as temp:
        # This is the very same extraction/version/worker validator that the
        # production publisher uses, but without any VPS or Docker operations.
        extract_bundle(archive, Path(temp), (version, build, main_digest))

    archive_digest = sha256(archive)
    (OUT / "archive.sha256").write_text(
        f"{archive_digest}  {archive.name}\n", encoding="ascii"
    )
    manifest = {
        "release_version": version,
        "release_build": build,
        "release_main_sha256": main_digest,
        "release_archive_sha256": archive_digest,
        "archive_filename": archive.name,
        "worker_sha256": pinned_worker,
        "worker_matches_public_production": True,
        "extract_bundle_preflight_passed": True,
        "observed_live_version": args.live_version,
        "observed_live_build": args.live_build,
        "observed_live_main_sha256": observed_live,
        "backend_contract_verified_on_live_server": False,
        "predeployment_database_backup_verified": False,
        "predeployment_backend_image_smoke_passed": False,
        "live_release_rechecked_at_switch": False,
        "web_deployed": False,
        "deploy_ready": False,
        "source_commit": os.getenv("GITHUB_SHA") or "local",
        "warning": (
            "This is a preflight-validated candidate, not an approval to deploy. "
            "Confirm the actual VPS Web fingerprint, live backend contracts, "
            "PostgreSQL backup, and backend rollback before using --execute."
        ),
    }
    (OUT / "release_candidate_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "archive": archive.name,
        "archive_sha256": archive_digest,
        "release_main_sha256": main_digest,
        "worker_sha256": pinned_worker,
        "staging_archive_selfcheck": "OK",
        "deploy_ready": False,
    }, sort_keys=True))


if __name__ == "__main__":
    main()
