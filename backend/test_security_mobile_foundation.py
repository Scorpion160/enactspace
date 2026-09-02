import os
import unittest

os.environ.setdefault("DATABASE_URL", "sqlite:///security-foundation-import.db")
os.environ.setdefault("SECRET_KEY", "unit-test-import-secret")

from fastapi import FastAPI

from app.api.routes.seed import (
    SeedRequest,
    V1DemoSeedRequest,
    register_seed_routes,
)
from app.core.config import Settings


def make_settings(*, app_env: str, enable_seed: bool) -> Settings:
    return Settings(
        _env_file=None,
        APP_ENV=app_env,
        APP_DEBUG=False,
        DATABASE_URL="sqlite:///security-foundation-test.db",
        SECRET_KEY="unit-test-secret-not-for-production",
        ENABLE_SEED=enable_seed,
        ATTENDANCE_QR_ENABLED=False,
        ATTENDANCE_NFC_ENABLED=False,
    )


class SeedRouteSecurityTests(unittest.TestCase):
    def test_production_never_registers_seed_routes(self):
        app = FastAPI()
        registered = register_seed_routes(
            app,
            app_settings=make_settings(app_env="production", enable_seed=True),
        )

        self.assertFalse(registered)
        self.assertNotIn("/api/seed/initial", app.openapi()["paths"])

    def test_development_requires_explicit_seed_enablement(self):
        app = FastAPI()
        registered = register_seed_routes(
            app,
            app_settings=make_settings(app_env="development", enable_seed=False),
        )

        self.assertFalse(registered)
        self.assertNotIn("/api/seed/initial", app.openapi()["paths"])

    def test_test_environment_can_explicitly_register_seed_routes(self):
        app = FastAPI()
        registered = register_seed_routes(
            app,
            app_settings=make_settings(app_env="test", enable_seed=True),
        )

        self.assertTrue(registered)
        self.assertIn("/api/seed/initial", app.openapi()["paths"])

    def test_seed_credentials_have_no_defaults(self):
        for field_name in (
            "admin_first_name",
            "admin_last_name",
            "admin_email",
            "admin_password",
        ):
            self.assertTrue(SeedRequest.model_fields[field_name].is_required())
        self.assertTrue(V1DemoSeedRequest.model_fields["password"].is_required())


if __name__ == "__main__":
    unittest.main()
