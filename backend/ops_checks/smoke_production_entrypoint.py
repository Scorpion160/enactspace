"""Smoke-test real Uvicorn startup in a production-like *isolated* environment.

Never connects to production: requires the disposable PostgreSQL CI database,
disables email, payments, push, attendance secrets and table creation, and uses
random dummy credentials. This does not replace a VPS/DB backup and staging test.
"""
from __future__ import annotations

import json
import os
import secrets
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

from sqlalchemy.engine import make_url


def main() -> None:
    test_database_url = os.environ.get("TEST_DATABASE_URL", "").strip()
    if not test_database_url:
        raise RuntimeError("A disposable TEST_DATABASE_URL is required")
    url = make_url(test_database_url)
    if (
        url.host not in ("localhost", "127.0.0.1")
        or "_ci" not in (url.database or "")
        or not url.drivername.startswith("postgresql")
    ):
        raise RuntimeError("Refusing to use anything except the local disposable CI PostgreSQL")

    with tempfile.TemporaryDirectory(prefix="enactspace-uvicorn-ci-") as tmp:
        env = dict(os.environ)
        env.update({
            "APP_ENV": "production",
            "APP_DEBUG": "false",
            "APP_VERSION": "1.0.30",
            "DATABASE_URL": test_database_url,
            "AUTO_CREATE_TABLES": "false",
            "ENABLE_SEED": "false",
            "FILE_STORAGE_PATH": str(Path(tmp) / "uploads"),
            "SECRET_KEY": secrets.token_hex(48),
            "JWT_SECRET_KEY": secrets.token_hex(48),
            "REFRESH_TOKEN_HMAC_KEY": secrets.token_hex(48),
            "MEET_SERVER_URL": "https://meet.ci.invalid",
            "MEET_REQUIRE_JWT": "true",
            "MEET_JWT_APP_ID": "ci-test-enactmeet",
            "MEET_JWT_SECRET": secrets.token_hex(48),
            "MEET_JWT_SUBJECT": "meet.ci.invalid",
            "PUSH_ENABLED": "false",
            "NOTIFICATION_PUSH_ENABLED": "false",
            "EMAIL_ENABLED": "false",
            "NOTIFICATION_EMAIL_ENABLED": "false",
            "MOBILE_MONEY_ENABLED": "false",
            "PAYMENT_RECONCILIATION_ENABLED": "false",
            "ATTENDANCE_QR_ENABLED": "false",
            "ATTENDANCE_NFC_ENABLED": "false",
            "CORS_ORIGINS": "https://enactspace.kerunjombor.net",
        })
        port = 18103
        command = [
            sys.executable, "-m", "uvicorn", "app.main:app",
            "--host", "127.0.0.1", "--port", str(port), "--no-access-log",
        ]
        log = Path(tmp) / "uvicorn.log"
        with log.open("w", encoding="utf-8") as stream:
            process = subprocess.Popen(
                command,
                env=env,
                cwd=Path(__file__).resolve().parents[1],
                stdout=stream,
                stderr=subprocess.STDOUT,
            )
            success = False
            try:
                endpoint = f"http://127.0.0.1:{port}/health"
                for _ in range(80):
                    if process.poll() is not None:
                        break
                    try:
                        with urlopen(endpoint, timeout=0.8) as response:
                            payload = json.load(response)
                        if (
                            response.status == 200 and payload.get("ok") is True
                            and payload.get("environment") == "production"
                            and payload.get("version") == "1.0.30"
                        ):
                            success = True
                            break
                    except (URLError, TimeoutError, ValueError, OSError):
                        time.sleep(0.25)
                if not success:
                    raise RuntimeError("Isolated production-like API failed to start or pass health")
                print("PRODUCTION_MODE_UVICORN_HEALTH_SMOKE_OK (disposable CI PostgreSQL)")
                print("PRODUCTION_DATABASE_TOUCHED false")
                print("EMAIL_OR_NOTIFICATIONS_SENT false")
            finally:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                if not success:
                    # Never print environment variables or dummy secrets.
                    print("STARTUP_LOG_TAIL:", file=sys.stderr)
                    print("\n".join(log.read_text(encoding="utf-8").splitlines()[-18:]),
                          file=sys.stderr)


if __name__ == "__main__":
    main()
