from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "EnactSpace"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True
    APP_VERSION: str = "1.0.0"

    DATABASE_URL: str

    SECRET_KEY: str
    JWT_SECRET_KEY: str | None = None
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    REFRESH_TOKEN_HMAC_KEY: str | None = None

    CORS_ORIGINS: str = ""
    PUBLIC_API_BASE_URL: str | None = None
    FILE_STORAGE_PATH: str = "uploads"
    AUTO_CREATE_TABLES: bool | None = None

    ENABLE_SEED: bool = False

    EMAIL_ENABLED: bool | None = None
    NOTIFICATION_EMAIL_ENABLED: bool = False
    NOTIFICATION_EMAIL_FROM: str = "enactus@esp.sn"
    SMTP_HOST: str | None = "smtp.gmail.com"
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = "enactus@esp.sn"
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = True
    SMTP_USE_SSL: bool = False
    SMTP_TIMEOUT_SECONDS: int = 20
    EMAIL_RESTRICT_TO_TEST_RECIPIENT: bool = False
    EMAIL_TEST_RECIPIENT: str | None = None

    PUSH_ENABLED: bool | None = None
    NOTIFICATION_PUSH_ENABLED: bool = False
    FCM_SERVER_KEY: str | None = None
    FIREBASE_PROJECT_ID: str | None = None
    PUSH_TOKEN_ENCRYPTION_KEY: str | None = None
    PUSH_RESTRICT_TO_TEST_USER_EMAIL: bool = False
    PUSH_TEST_USER_EMAIL: str | None = None

    PAYMENT_PROVIDER_ENABLED: bool = False
    PAYMENT_PROVIDER: str = "manual_proof"
    PAYMENT_WEBHOOK_SECRET: str | None = None
    MOBILE_MONEY_ENABLED: bool = False
    MOBILE_MONEY_PROVIDER: str = "paydunya"
    PAYDUNYA_MODE: str = "test"
    PAYDUNYA_MASTER_KEY: str | None = None
    PAYDUNYA_PUBLIC_KEY: str | None = None
    PAYDUNYA_PRIVATE_KEY: str | None = None
    PAYDUNYA_TOKEN: str | None = None
    PAYDUNYA_CALLBACK_URL: str | None = None
    PAYDUNYA_RETURN_URL: str | None = None
    PAYDUNYA_CANCEL_URL: str | None = None
    PAYDUNYA_ALLOWED_CHANNELS: str = "wave-senegal,orange-money-senegal"
    PAYDUNYA_TIMEOUT_SECONDS: int = 15
    PAYMENT_CURRENCY: str = "XOF"
    PAYMENT_TRANSACTION_TTL_MINUTES: int = 30
    PAYMENT_RECONCILIATION_ENABLED: bool = True
    PAYMENT_RECONCILIATION_LOOKBACK_DAYS: int = 7
    PAYMENT_RECONCILIATION_RETRY_SECONDS: int = 60

    MEET_SERVER_URL: str = "https://meet.jit.si"
    MEET_REQUIRE_JWT: bool = False
    MEET_JWT_APP_ID: str | None = None
    MEET_JWT_SECRET: str | None = None
    MEET_JWT_AUDIENCE: str = "jitsi"
    MEET_JWT_SUBJECT: str | None = None
    MEET_JWT_TTL_MINUTES: int = 180
    MEET_RECORDING_ENABLED: bool = False

    ATTENDANCE_QR_ENABLED: bool = True
    ATTENDANCE_QR_SECRET: str | None = None
    ATTENDANCE_QR_TTL_SECONDS: int = 60
    ATTENDANCE_QR_ROTATION_SECONDS: int = 45
    ATTENDANCE_LATE_GRACE_MINUTES: int = 10
    ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE: int = 10
    ATTENDANCE_QR_REQUIRE_MANUAL_CONFIRMATION: bool = False
    ATTENDANCE_QR_REQUIRE_SESSION_PIN: bool = False
    ATTENDANCE_QR_REQUIRE_LOCATION_CHECK: bool = False

    ATTENDANCE_NFC_ENABLED: bool = True
    ATTENDANCE_NFC_HASH_SECRET: str | None = None
    ATTENDANCE_NFC_RATE_LIMIT_PER_MINUTE: int = 30

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @model_validator(mode="after")
    def validate_attendance_qr_settings(self):
        if not 1 <= self.PAYMENT_RECONCILIATION_LOOKBACK_DAYS <= 365:
            raise ValueError("PAYMENT_RECONCILIATION_LOOKBACK_DAYS must be between 1 and 365")
        if not 1 <= self.PAYMENT_RECONCILIATION_RETRY_SECONDS <= 3600:
            raise ValueError("PAYMENT_RECONCILIATION_RETRY_SECONDS must be between 1 and 3600")
        if self.ALGORITHM != "HS256":
            raise ValueError("ALGORITHM must be HS256")
        if self.ATTENDANCE_QR_TTL_SECONDS < 15:
            raise ValueError("ATTENDANCE_QR_TTL_SECONDS must be at least 15")
        if self.ATTENDANCE_QR_ROTATION_SECONDS < 10:
            raise ValueError("ATTENDANCE_QR_ROTATION_SECONDS must be at least 10")
        if self.ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE < 1:
            raise ValueError("ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE must be positive")
        if self.ATTENDANCE_NFC_RATE_LIMIT_PER_MINUTE < 1:
            raise ValueError("ATTENDANCE_NFC_RATE_LIMIT_PER_MINUTE must be positive")
        if self.SMTP_TIMEOUT_SECONDS < 1:
            raise ValueError("SMTP_TIMEOUT_SECONDS must be positive")
        if self.SMTP_USE_SSL and self.SMTP_USE_TLS:
            raise ValueError("SMTP_USE_SSL and SMTP_USE_TLS cannot both be true")
        if self.EMAIL_RESTRICT_TO_TEST_RECIPIENT:
            recipient = (self.EMAIL_TEST_RECIPIENT or "").strip()
            if not recipient or "@" not in recipient:
                raise ValueError(
                    "EMAIL_TEST_RECIPIENT is required when email restriction is enabled"
                )
        if self.PUSH_RESTRICT_TO_TEST_USER_EMAIL:
            test_email = (self.PUSH_TEST_USER_EMAIL or "").strip()
            if not test_email or "@" not in test_email:
                raise ValueError(
                    "PUSH_TEST_USER_EMAIL is required when push restriction is enabled"
                )
        if self.PAYMENT_TRANSACTION_TTL_MINUTES < 1:
            raise ValueError("PAYMENT_TRANSACTION_TTL_MINUTES must be positive")
        if self.PAYDUNYA_TIMEOUT_SECONDS < 1:
            raise ValueError("PAYDUNYA_TIMEOUT_SECONDS must be positive")
        if self.REFRESH_TOKEN_EXPIRE_DAYS < 1:
            raise ValueError("REFRESH_TOKEN_EXPIRE_DAYS must be positive")
        if self.MEET_JWT_TTL_MINUTES < 5:
            raise ValueError("MEET_JWT_TTL_MINUTES must be at least 5")
        if not self.MEET_SERVER_URL.startswith(("https://", "http://")):
            raise ValueError("MEET_SERVER_URL must be an absolute HTTP(S) URL")
        if self.APP_ENV == "production":
            if not self.REFRESH_TOKEN_HMAC_KEY:
                raise ValueError("REFRESH_TOKEN_HMAC_KEY is required in production")
            if self.REFRESH_TOKEN_HMAC_KEY == self.signing_secret:
                raise ValueError("REFRESH_TOKEN_HMAC_KEY must differ from JWT secret")
            if self.push_enabled:
                if not self.FIREBASE_PROJECT_ID:
                    raise ValueError("FIREBASE_PROJECT_ID is required when push is enabled")
                if not self.PUSH_TOKEN_ENCRYPTION_KEY:
                    raise ValueError("PUSH_TOKEN_ENCRYPTION_KEY is required when push is enabled")
                auth_secrets = {
                    self.SECRET_KEY,
                    self.JWT_SECRET_KEY,
                    self.REFRESH_TOKEN_HMAC_KEY,
                }
                if self.PUSH_TOKEN_ENCRYPTION_KEY in auth_secrets:
                    raise ValueError("PUSH_TOKEN_ENCRYPTION_KEY must differ from auth secrets")
            if not self.MEET_SERVER_URL.startswith("https://"):
                raise ValueError("MEET_SERVER_URL must use HTTPS in production")
            if self.MEET_SERVER_URL.rstrip("/").lower() == "https://meet.jit.si":
                raise ValueError(
                    "MEET_SERVER_URL must use a private Jitsi/JaaS endpoint in production"
                )
            if not self.MEET_REQUIRE_JWT:
                raise ValueError("MEET_REQUIRE_JWT must be enabled in production")
            if not (
                self.MEET_JWT_APP_ID and self.MEET_JWT_SECRET and self.MEET_JWT_SUBJECT
            ):
                raise ValueError(
                    "MEET_JWT_APP_ID, MEET_JWT_SECRET and MEET_JWT_SUBJECT are required in production"
                )
            if self.MEET_JWT_SECRET == self.signing_secret:
                raise ValueError("MEET_JWT_SECRET must differ from the EnactSpace JWT secret")
        if self.PAYDUNYA_MODE not in {"test", "live"}:
            raise ValueError("PAYDUNYA_MODE must be test or live")
        if self.MOBILE_MONEY_PROVIDER not in {
            "manual_proof",
            "mock",
            "paydunya",
            "wave_direct",
            "orange_money_direct",
        }:
            raise ValueError("MOBILE_MONEY_PROVIDER is not supported")
        if self.PAYMENT_CURRENCY != "XOF":
            raise ValueError("PAYMENT_CURRENCY must be XOF for Mobile Money V1.1")
        if self.APP_ENV == "production" and self.MOBILE_MONEY_ENABLED:
            if self.PAYDUNYA_MODE == "live" and self.MOBILE_MONEY_PROVIDER == "paydunya":
                required_keys = [
                    self.PAYDUNYA_MASTER_KEY,
                    self.PAYDUNYA_PUBLIC_KEY,
                    self.PAYDUNYA_PRIVATE_KEY,
                    self.PAYDUNYA_TOKEN,
                ]
                if not all(required_keys):
                    raise ValueError("PayDunya live keys are required in production")
            if self.PAYDUNYA_MODE == "live" and not (
                self.PAYDUNYA_CALLBACK_URL and self.PAYDUNYA_CALLBACK_URL.startswith("https://")
            ):
                raise ValueError("PAYDUNYA_CALLBACK_URL must be HTTPS in live mode")
        if self.APP_ENV == "production" and self.ATTENDANCE_QR_ENABLED:
            if not self.ATTENDANCE_QR_SECRET:
                raise ValueError("ATTENDANCE_QR_SECRET is required in production")
            if self.ATTENDANCE_QR_SECRET == self.signing_secret:
                raise ValueError("ATTENDANCE_QR_SECRET must differ from JWT secret")
            if self.ATTENDANCE_QR_SECRET == "CHANGE_ME":
                raise ValueError("ATTENDANCE_QR_SECRET must be changed in production")
        if self.APP_ENV == "production" and self.ATTENDANCE_NFC_ENABLED:
            if not self.ATTENDANCE_NFC_HASH_SECRET:
                raise ValueError("ATTENDANCE_NFC_HASH_SECRET is required in production")
            if self.ATTENDANCE_NFC_HASH_SECRET == self.signing_secret:
                raise ValueError(
                    "ATTENDANCE_NFC_HASH_SECRET must differ from JWT secret"
                )
            if self.ATTENDANCE_QR_SECRET and (
                self.ATTENDANCE_NFC_HASH_SECRET == self.ATTENDANCE_QR_SECRET
            ):
                raise ValueError(
                    "ATTENDANCE_NFC_HASH_SECRET must differ from QR secret"
                )
            if self.ATTENDANCE_NFC_HASH_SECRET == "CHANGE_ME":
                raise ValueError(
                    "ATTENDANCE_NFC_HASH_SECRET must be changed in production"
                )
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        if not self.CORS_ORIGINS:
            return []

        return [
            origin.strip()
            for origin in self.CORS_ORIGINS.split(",")
            if origin.strip()
        ]

    @property
    def signing_secret(self) -> str:
        return self.JWT_SECRET_KEY or self.SECRET_KEY

    @property
    def refresh_token_hmac_key(self) -> str:
        return self.REFRESH_TOKEN_HMAC_KEY or self.signing_secret

    @property
    def attendance_qr_secret(self) -> str:
        return self.ATTENDANCE_QR_SECRET or self.signing_secret

    @property
    def attendance_nfc_hash_secret(self) -> str:
        return self.ATTENDANCE_NFC_HASH_SECRET or self.signing_secret

    @property
    def paydunya_allowed_channels_list(self) -> list[str]:
        if not self.PAYDUNYA_ALLOWED_CHANNELS:
            return []
        return [
            channel.strip()
            for channel in self.PAYDUNYA_ALLOWED_CHANNELS.split(",")
            if channel.strip()
        ]

    @property
    def email_enabled(self) -> bool:
        if self.EMAIL_ENABLED is not None:
            return self.EMAIL_ENABLED
        return self.NOTIFICATION_EMAIL_ENABLED

    @property
    def push_enabled(self) -> bool:
        if self.PUSH_ENABLED is not None:
            return self.PUSH_ENABLED
        return self.NOTIFICATION_PUSH_ENABLED

    @property
    def database_auto_create_tables(self) -> bool:
        if self.AUTO_CREATE_TABLES is not None:
            return self.AUTO_CREATE_TABLES
        return self.APP_ENV != "production"

    @property
    def seed_routes_enabled(self) -> bool:
        return self.ENABLE_SEED and self.APP_ENV.lower() in {
            "development",
            "test",
        }


settings = Settings()
