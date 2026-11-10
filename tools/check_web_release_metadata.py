"""Check EnactSpace Flutter Web version metadata and stage a safe build report.

By design this script does *not* deploy. It marks a build as needing the verified
Firebase messaging service worker and live backend compatibility checks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRONTEND = ROOT / "frontend"
PRODUCTION_API = "https://api-enactspace.kerunjombor.net"
REQUIRED_BUILD_FILES = ("index.html", "main.dart.js", "flutter_bootstrap.js", "version.json")
WORKER_NAME = "firebase-messaging-sw.js"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for data in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(data)
    return digest.hexdigest()


def expected_version() -> tuple[str, str]:
    pubspec = (FRONTEND / "pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec, re.MULTILINE)
    if match is None:
        raise RuntimeError("Missing/invalid Flutter pubspec version")
    version, build_number = match.groups()
    metadata = json.loads((FRONTEND / "web/version.json").read_text(encoding="utf-8"))
    if metadata.get("version") != version or str(metadata.get("build_number")) != build_number:
        raise RuntimeError("Version mismatch between pubspec.yaml and web/version.json")
    return version, build_number


def inspect_built_web(version: str, build_number: str) -> dict:
    web = FRONTEND / "build/web"
    for name in REQUIRED_BUILD_FILES:
        path = web / name
        if not path.is_file() or path.stat().st_size == 0:
            raise RuntimeError(f"Web build missing required asset: {name}")
    built_version = json.loads((web / "version.json").read_text(encoding="utf-8"))
    if built_version.get("version") != version or str(built_version.get("build_number")) != build_number:
        raise RuntimeError("Built web/version.json does not match the source")
    js = (web / "main.dart.js").read_bytes()
    if PRODUCTION_API.encode() not in js:
        raise RuntimeError("Candidate Web bundle is not configured for the intended production API")
    if b"https://example.invalid" in js:
        raise RuntimeError("Candidate Web bundle contains the CI placeholder API")

    worker = web / WORKER_NAME
    worker_present = worker.is_file()
    worker_verified = False
    worker_sha = None
    if worker_present:
        payload = worker.read_bytes()
        worker_verified = b"firebase.initializeApp" in payload and b"firebase.messaging" in payload
        if not worker_verified:
            raise RuntimeError("Existing Firebase worker is not initialized")
        worker_sha = sha256(worker)

    report = {
        "app": "EnactSpace",
        "source_commit": os.getenv("GITHUB_SHA") or "local",
        "release_version": version,
        "release_build_number": build_number,
        "production_api_url": PRODUCTION_API,
        "file_checksums_sha256": {name: sha256(web / name) for name in REQUIRED_BUILD_FILES},
        "firebase_worker_included": worker_present,
        "firebase_worker_sha256": worker_sha,
        "firebase_worker_initialized": worker_verified,
        "backend_contract_verified_in_production": False,
        "live_bundle_sha256_verified": False,
        "deployment_approved": False,
        "deploy_ready": False,
        "notes": (
            "Pre-deployment build only. Verify the actual production backend API, "
            "preserve a verified Firebase messaging worker, compare the currently "
            "served bundle fingerprint, and confirm authorized rollback readiness. "
            "Never deploy this artifact directly."
        ),
    }
    manifest = FRONTEND / "build/web_candidate_manifest.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--built", action="store_true", help="Check the compiled candidate and write a manifest")
    args = parser.parse_args()
    version, build_number = expected_version()
    print(f"RELEASE_METADATA_OK {version}+{build_number}")
    if args.built:
        report = inspect_built_web(version, build_number)
        print(json.dumps({
            "candidate_main_sha256": report["file_checksums_sha256"]["main.dart.js"],
            "firebase_worker_included": report["firebase_worker_included"],
            "deploy_ready": report["deploy_ready"],
            "production_api_url": report["production_api_url"],
        }, sort_keys=True))


if __name__ == "__main__":
    main()
