"""Verify the candidate against isolated fixtures and an already-paid sandbox invoice."""
import base64
import hashlib
import json
from pathlib import Path
import subprocess
import sys

PROBE = r'''
import asyncio, hashlib, json
from contextlib import ExitStack
from unittest.mock import patch
import test_prelaunch_mobile_money_boundaries as fixture
from app.api.routes import payments
from app.core.config import settings
from app.models.finance import ClubTransaction, Payment
from app.services.payments import PaymentProviderError
from app.services.payments.paydunya_provider import PayDunyaProvider

report = {"production_database_access": False,
          "automatic_ipn_delivery_verified": False,
          "callback_origin": "synthetic_test_replay"}
case = None
ready = False
stage = "sandbox_lookup"
try:
    assert settings.DATABASE_URL == "sqlite://"
    with ExitStack() as stack:
        for name in ("PAYDUNYA_MASTER_KEY", "PAYDUNYA_PUBLIC_KEY",
                     "PAYDUNYA_PRIVATE_KEY", "PAYDUNYA_TOKEN"):
            stack.enter_context(patch.object(settings, name, credentials[name]))
        stack.enter_context(patch.object(settings, "PAYDUNYA_MODE", "test"))
        provider = PayDunyaProvider()
        result = asyncio.run(provider.get_payment_status(provider_token="test_YiPIYKTxs6"))
        assert result.status == "successful"
        assert result.metadata["amount"] == 200
        report["real_sandbox_confirmation_passed"] = True

        stage = "isolated_fixture"
        case = fixture.MobileMoneyBoundaryTests()
        case.setUp()
        ready = True
        row = case.transaction()
        row.amount = 200
        row.provider_invoice_token = "test_YiPIYKTxs6"
        case.db.commit()
        entries = case.db.query(ClubTransaction).count()
        count = case.db.query(Payment).filter(Payment.status == "validated").count()
        stack.enter_context(patch.object(payments, "get_payment_provider", return_value=provider))

        stage = "invalid_signature"
        invalid = case.client.post("/api/payments/paydunya/ipn", data={
            "data[hash]": "0" * 128,
            "data[invoice][token]": row.provider_invoice_token})
        assert invalid.status_code == 400
        assert case.db.query(ClubTransaction).count() == entries
        report["invalid_signature_rejected"] = True

        payload = {
            "data[hash]": hashlib.sha512(credentials["PAYDUNYA_MASTER_KEY"].encode()).hexdigest(),
            "data[invoice][token]": row.provider_invoice_token,
            "data[status]": "failed", "data[invoice][total_amount]": "999999"}
        for attempt in (0, 1):
            stage = "first_callback" if attempt == 0 else "duplicate_callback"
            response = case.client.post("/api/payments/paydunya/ipn", data=payload)
            report[stage + "_http_status"] = response.status_code
            assert response.status_code == 200
            if attempt:
                assert response.json().get("duplicate") is True
            case.db.expire_all()
            assert row.status == "successful" and row.payment_id is not None
            assert float(case.account.total_paid) == 200
            assert float(case.fee.amount_paid) == 200
            assert case.db.query(ClubTransaction).count() == entries + 1
            assert case.db.query(Payment).filter(Payment.status == "validated").count() == count + 1
        report.update(status="SANDBOX_IPN_REPLAY_AND_ACCOUNTING_PASSED",
                      amount_recorded_once=200,
                      callback_claims_overridden_by_provider_confirmation=True)
except Exception as error:
    report.update(status="SANDBOX_IPN_REPLAY_BLOCKED", stage=stage,
                  error_type=type(error).__name__)
    if isinstance(error, PaymentProviderError):
        report["provider_error_code"] = error.code
finally:
    if ready:
        case.tearDown()
print(json.dumps(report))
'''


def main():
    directory = Path(sys.argv[1]).resolve()
    manifest = json.loads((directory / "manifest.json").read_text())
    for name, expected in manifest.items():
        if name not in {"paydunya_provider.py", "test_prelaunch_payment_transport.py"}:
            raise RuntimeError("Unexpected_manifest_entry")
        target = directory / name
        if hashlib.sha256(target.read_bytes()).hexdigest() != expected:
            raise RuntimeError("Candidate_integrity_failed")
        target.chmod(0o644)
    image = "enactspace-backend:release-1ccbb0a"
    inspected = json.loads(subprocess.check_output(["docker", "image", "inspect", image], text=True))[0]
    if (inspected["Config"].get("Labels") or {}).get("org.opencontainers.image.revision") != "1ccbb0ac2b8220ee8eb19d24a9114790e7bf2b95":
        raise RuntimeError("Unexpected_base_image")
    common = ["docker", "run", "--rm", "--workdir", "/app/backend",
              "-e", "APP_ENV=test", "-e", "DATABASE_URL=sqlite://",
              "-e", "SECRET_KEY=isolated-payment-tests-only",
              "-e", "EMAIL_ENABLED=false", "-e", "PUSH_ENABLED=false",
              "-e", "MOBILE_MONEY_ENABLED=false", "-e", "PAYDUNYA_MODE=test",
              "--mount", f"type=bind,source={directory}/paydunya_provider.py,target=/app/backend/app/services/payments/paydunya_provider.py,readonly",
              "--mount", f"type=bind,source={directory}/test_prelaunch_payment_transport.py,target=/app/backend/test_prelaunch_payment_transport.py,readonly",
              "--entrypoint", "python"]
    tested = subprocess.run(common + ["--network=none", image, "-m", "unittest", "-v",
                            "test_prelaunch_mobile_money_boundaries", "test_prelaunch_payment_transport"], timeout=240)
    if tested.returncode:
        raise RuntimeError("Isolated_tests_failed")
    credentials = json.loads(Path("/opt/enactspace/operations/paydunya-test-9dbf7e21a6c14f47a3c9e1af077a89d8/credentials.json").read_text())
    if credentials.get("PAYDUNYA_MODE") != "test":
        raise RuntimeError("Test_mode_required")
    encoded = base64.b64encode(json.dumps(credentials).encode()).decode()
    program = "import base64,json\ncredentials=json.loads(base64.b64decode(" + repr(encoded) + "))\n" + PROBE
    outcome = subprocess.run(common + ["--network=bridge", "-i", image, "-"],
                             input=program, capture_output=True, text=True, timeout=180)
    if outcome.returncode:
        raise RuntimeError("Sandbox_process_failed")
    report = json.loads(outcome.stdout)
    print(json.dumps(report, indent=2))
    return 0 if report.get("status") == "SANDBOX_IPN_REPLAY_AND_ACCOUNTING_PASSED" else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print(json.dumps({"status": "SANDBOX_VERIFICATION_BLOCKED", "error_type": type(error).__name__,
                          "production_services_changed": False}))
        sys.exit(1)
