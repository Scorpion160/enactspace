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

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

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
    def email_enabled(self) -> bool:
        if self.EMAIL_ENABLED is not None:
            return self.EMAIL_ENABLED
        return self.NOTIFICATION_EMAIL_ENABLED

    @property
    def push_enabled(self) -> bool:
        if self.PUSH_ENABLED is not None:
            return self.PUSH_ENABLED
        return self.NOTIFICATION_PUSH_ENABLED


settings = Settings()
