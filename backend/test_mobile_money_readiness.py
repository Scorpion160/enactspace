import unittest
from types import SimpleNamespace

from app.services.payments.readiness import get_mobile_money_readiness


def settings(**overrides):
    values = dict(
        MOBILE_MONEY_ENABLED=True,
        MOBILE_MONEY_PROVIDER="paydunya",
        PAYDUNYA_MODE="test",
        PAYDUNYA_MASTER_KEY="dummy-master",
        PAYDUNYA_PUBLIC_KEY="dummy-public",
        PAYDUNYA_PRIVATE_KEY="dummy-private",
        PAYDUNYA_TOKEN="dummy-token",
        PAYDUNYA_CALLBACK_URL="https://payments.school.org/api/payments/paydunya/ipn",
        PUBLIC_API_BASE_URL=None,
        PAYMENT_CURRENCY="XOF",
        PAYMENT_RECONCILIATION_ENABLED=True,
        paydunya_allowed_channels_list=["wave-senegal", "orange-money-senegal"],
    )
    values.update(overrides)
    return SimpleNamespace(**values)


class MobileMoneyReadinessTests(unittest.TestCase):
    def test_sandbox_ready_does_not_claim_live_enabled(self):
        status = get_mobile_money_readiness(settings())
        self.assertTrue(status["configuration_ready"])
        self.assertFalse(status["ready_for_live_test"])
        self.assertEqual(
            status["allowed_channels"], ["orange-money-senegal", "wave-senegal"]
        )
        self.assertNotIn("dummy-master", repr(status))
        self.assertNotIn("dummy-token", repr(status))

    def test_production_never_accepts_sandbox_as_accounting_ready(self):
        production = get_mobile_money_readiness(settings(APP_ENV="production"))
        self.assertFalse(production["configuration_ready"])
        self.assertFalse(production["ready_for_live_test"])
        self.assertTrue(any("test" in reason.lower()
                            for reason in production["blocking_checks"]))
        standalone_test = get_mobile_money_readiness(settings(APP_ENV="test"))
        self.assertTrue(standalone_test["configuration_ready"])

    def test_live_requires_https_valid_callback_and_reconciliation(self):
        live = get_mobile_money_readiness(settings(PAYDUNYA_MODE="live"))
        self.assertTrue(live["ready_for_live_test"])
        broken = get_mobile_money_readiness(settings(
            PAYDUNYA_MODE="live",
            PAYDUNYA_CALLBACK_URL="http://api.example.invalid/api/payments/paydunya/ipn",
            PAYMENT_RECONCILIATION_ENABLED=False,
        ))
        self.assertFalse(broken["ready_for_live_test"])
        self.assertEqual(len(broken["blocking_checks"]), 2)

    def test_missing_keys_and_nonexistent_direct_provider_block_live(self):
        status = get_mobile_money_readiness(settings(
            PAYDUNYA_MODE="live",
            PAYDUNYA_TOKEN=None,
            MOBILE_MONEY_PROVIDER="wave_direct",
            paydunya_allowed_channels_list=["card"],
        ))
        self.assertFalse(status["configuration_ready"])
        self.assertFalse(status["credentials_present"])
        self.assertEqual(status["allowed_channels"], [])
        self.assertEqual(len(status["blocking_checks"]), 3)

    def test_missing_callback_can_be_derived_from_public_api(self):
        sandbox = get_mobile_money_readiness(settings(
            PAYDUNYA_MODE="test",
            PAYDUNYA_CALLBACK_URL=None,
            PUBLIC_API_BASE_URL="https://api.example.invalid",
        ))
        self.assertTrue(sandbox["ipn_url_valid"])
        live = get_mobile_money_readiness(settings(
            PAYDUNYA_MODE="live",
            PAYDUNYA_CALLBACK_URL=None,
            PUBLIC_API_BASE_URL="https://api.example.invalid",
        ))
        self.assertFalse(live["ipn_url_valid"])
        self.assertFalse(live["ready_for_live_test"])

    def test_live_rejects_private_and_reserved_ipn_hosts(self):
        for host in (
            "127.0.0.1",
            "10.0.0.1",
            "192.168.1.10",
            "localhost",
            "payments.internal",
            "api.example.invalid",
        ):
            with self.subTest(host=host):
                status = get_mobile_money_readiness(settings(
                    PAYDUNYA_MODE="live",
                    PAYDUNYA_CALLBACK_URL=(
                        f"https://{host}/api/payments/paydunya/ipn"
                    ),
                ))
                self.assertFalse(status["ipn_url_valid"])
                self.assertFalse(status["ready_for_live_test"])

    def test_malicious_callback_is_rejected(self):
        for url in (
            "https://api.example.invalid.evil.com/other",
            "https://user:pass@api.example.invalid/api/payments/paydunya/ipn",
            "https://api.example.invalid/api/payments/paydunya/ipn?token=secret",
            "ftp://api.example.invalid/api/payments/paydunya/ipn",
        ):
            with self.subTest(url=url):
                status = get_mobile_money_readiness(settings(
                    PAYDUNYA_MODE="live",
                    PAYDUNYA_CALLBACK_URL=url,
                ))
                self.assertFalse(status["ipn_url_valid"])


if __name__ == "__main__":
    unittest.main()
