from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    APP_NAME: str = "EnactSpace"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True
    APP_VERSION: str = "1.1-dev"

    DATABASE_URL: str

    SECRET_KEY: str
    JWT_SECRET_KEY: str | None = None
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440

    CORS_ORIGINS: str = ""
    PUBLIC_API_BASE_URL: str | None = None
    FILE_STORAGE_PATH: str = "uploads"
    AUTO_CREATE_TABLES: bool | None = None

    ENABLE_SEED: bool = True

    EMAIL_ENABLED: bool | None = None
    NOTIFICATION_EMAIL_ENABLED: bool = False
    NOTIFICATION_EMAIL_FROM: str = "noreply@enactspace.local"
    SMTP_HOST: str | None = None
    SMTP_PORT: int = 587
    SMTP_USERNAME: str | None = None
    SMTP_PASSWORD: str | None = None
    SMTP_USE_TLS: bool = True

    PUSH_ENABLED: bool | None = None
    NOTIFICATION_PUSH_ENABLED: bool = False
    FCM_SERVER_KEY: str | None = None

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
        if self.ATTENDANCE_QR_TTL_SECONDS < 15:
            raise ValueError("ATTENDANCE_QR_TTL_SECONDS must be at least 15")
        if self.ATTENDANCE_QR_ROTATION_SECONDS < 10:
            raise ValueError("ATTENDANCE_QR_ROTATION_SECONDS must be at least 10")
        if self.ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE < 1:
            raise ValueError("ATTENDANCE_QR_RATE_LIMIT_PER_MINUTE must be positive")
        if self.ATTENDANCE_NFC_RATE_LIMIT_PER_MINUTE < 1:
            raise ValueError("ATTENDANCE_NFC_RATE_LIMIT_PER_MINUTE must be positive")
        if self.PAYMENT_TRANSACTION_TTL_MINUTES < 1:
            raise ValueError("PAYMENT_TRANSACTION_TTL_MINUTES must be positive")
        if self.PAYDUNYA_TIMEOUT_SECONDS < 1:
            raise ValueError("PAYDUNYA_TIMEOUT_SECONDS must be positive")
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


settings = Settings()
