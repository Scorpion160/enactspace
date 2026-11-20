"""Read-only fingerprint of public EnactSpace web and health endpoints.

No authentication, database access, SSH or deployment. It only downloads
publicly served assets to record what a future release must not overwrite.
"""
from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen

WEB = "https://enactspace.kerunjombor.net"
API = "https://api-enactspace.kerunjombor.net"
TARGETS = {
    "web_version": (WEB + "/version.json", 16_384),
    "web_main": (WEB + "/main.dart.js", 32_000_000),
    "web_firebase_worker": (WEB + "/firebase-messaging-sw.js", 256_000),
    "api_health": (API + "/health", 16_384),
}
OUT = Path(sys.argv[1]) if len(sys.argv) >= 2 else Path("public-production-fingerprint")
OUT.mkdir(parents=True, exist_ok=True)
results: dict = {}
issues: list[str] = []


def fetch_public(url: str, limit: int) -> tuple[bytes, str]:
    request = Request(url, headers={
        "User-Agent": "EnactSpace-Public-ReadOnly-Audit/1.0",
        "Cache-Control": "no-cache",
    })
    with urlopen(request, timeout=18) as response:
        if response.status != 200:
            raise RuntimeError(f"Unexpected HTTP status: {response.status}")
        data = response.read(limit + 1)
        if len(data) > limit:
            raise RuntimeError("Response exceeds safe public-asset size")
        return data, response.headers.get("Content-Type", "")


for key, (url, limit) in TARGETS.items():
    try:
        data, content_type = fetch_public(url, limit)
        if not data:
            raise RuntimeError("Empty public response")
        if key == "web_main" and (
            len(data) < 100_000 or data.lstrip().lower().startswith(b"<!doctype")
        ):
            raise RuntimeError("Unexpected JS bundle content")
        if key == "web_firebase_worker":
            if b"firebase.initializeApp" not in data or b"firebase.messaging" not in data:
                raise RuntimeError("The public Firebase worker lacks expected initialization")
            (OUT / "firebase-messaging-sw.js").write_bytes(data)
        if key in ("web_version", "api_health"):
            parsed = json.loads(data)
            if not isinstance(parsed, dict):
                raise RuntimeError("Unexpected JSON payload")
            if key == "web_version" and (
                not parsed.get("version") or not parsed.get("build_number")
            ):
                raise RuntimeError("Incomplete Web version metadata")
            if key == "api_health" and parsed.get("ok") is not True:
                raise RuntimeError("Public API health is not OK")
            displayed = {k: v for k, v in parsed.items()
                         if k in ("version", "build_number", "ok", "service", "environment")}
        else:
            displayed = None
        results[key] = {
            "ok": True,
            "url": url,
            "bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "content_type": content_type,
            "public_fields": displayed,
        }
    except Exception as exc:
        results[key] = {"ok": False, "url": url, "error_type": type(exc).__name__}
        issues.append(f"{key}: {type(exc).__name__}")
report = {
    "observed_at_utc": datetime.now(timezone.utc).isoformat(),
    "readonly": True,
    "production_modified": False,
    "results": results,
    "all_public_checks_ok": len(issues) == 0,
    "issues": issues,
    "notes": "This is a public external probe. It does not verify VPS filesystem, private API contracts, database or backend deployment safety.",
}
(OUT / "public_fingerprint.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps({
    "all_public_checks_ok": report["all_public_checks_ok"],
    "web": results.get("web_version", {}).get("public_fields"),
    "api": results.get("api_health", {}).get("public_fields"),
    "live_main_sha256": results.get("web_main", {}).get("sha256"),
    "worker_sha256": results.get("web_firebase_worker", {}).get("sha256"),
    "issues": issues,
}, ensure_ascii=False))
if issues:
    sys.exit(1)
