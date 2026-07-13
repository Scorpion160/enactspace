from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import urlparse


SECRET_MARKERS = (
    "SECRET",
    "PASSWORD",
    "TOKEN",
    "KEY",
    "FCM",
    "PAYDUNYA",
    "SMTP",
)
ENV_KEY_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")
WINDOWS_ABSOLUTE_PATH_RE = re.compile(r"^[A-Za-z]:[\\/]")


class EnvironmentValidationError(Exception):
    pass


def backend_dir() -> Path:
    return Path(__file__).resolve().parents[2]


def is_quoted(value: str) -> bool:
    value = value.strip()
    return len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}


def parse_env_file(path: Path) -> tuple[dict[str, str], list[str]]:
    values: dict[str, str] = {}
    warnings: list[str] = []
    errors: list[str] = []

    if not path.exists():
        raise EnvironmentValidationError(f"Environment file not found: {path}")

    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            errors.append(f"Line {line_number}: missing '='")
            continue
        key, raw_value = line.split("=", 1)
        key = key.strip().lstrip("\ufeff")
        value = raw_value.strip()
        if not ENV_KEY_RE.match(key):
            errors.append(f"Line {line_number}: invalid variable name")
            continue
        if "#" in value and not is_quoted(value):
            errors.append(f"Line {line_number}: value containing # must be quoted")
            continue
        if value and not is_quoted(value):
            if any(character.isspace() for character in value):
                warnings.append(f"Line {line_number}: value containing spaces should be quoted")
            if "," in value or "://" in value:
                warnings.append(f"Line {line_number}: URL or list value should be quoted")
        values[key] = value[1:-1] if is_quoted(value) else value

    if errors:
        raise EnvironmentValidationError("\n".join(errors))
    return values, warnings


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EnvironmentValidationError(message)


def validate_database(values: dict[str, str]) -> None:
    database_url = values.get("DATABASE_URL", "")
    require(bool(database_url), "DATABASE_URL is required")
    parsed = urlparse(database_url)
    require(bool(parsed.scheme), "DATABASE_URL scheme is required")
    if values.get("APP_ENV") == "production":
        require(
            not database_url.startswith("sqlite"),
            "Production DATABASE_URL must not use SQLite",
        )


def validate_storage(values: dict[str, str]) -> None:
    storage_path = values.get("FILE_STORAGE_PATH") or "uploads"
    require(bool(storage_path), "FILE_STORAGE_PATH is required")
    if values.get("APP_ENV") == "production":
        is_absolute = (
            storage_path.startswith("/")
            or storage_path.startswith("\\")
            or bool(WINDOWS_ABSOLUTE_PATH_RE.match(storage_path))
        )
        require(
            is_absolute,
            "Production FILE_STORAGE_PATH must be absolute",
        )


def validate_jwt(values: dict[str, str]) -> list[str]:
    secret = values.get("JWT_SECRET_KEY") or values.get("SECRET_KEY")
    require(bool(secret), "JWT_SECRET_KEY or SECRET_KEY is required")
    require(secret not in {"CHANGE_ME", "CHANGE_ME_LONG_RANDOM_SECRET"}, "JWT secret must be changed")
    if values.get("APP_ENV") == "production":
        require(len(secret or "") >= 32, "JWT secret should be at least 32 characters")
        return []
    if len(secret or "") < 32:
        return ["JWT secret is short for production; replace it on VPS"]
    return []


def validate_qr(values: dict[str, str]) -> None:
    if values.get("ATTENDANCE_QR_ENABLED", "true").lower() != "true":
        return
    if values.get("APP_ENV") == "production":
        qr_secret = values.get("ATTENDANCE_QR_SECRET")
        require(bool(qr_secret), "ATTENDANCE_QR_SECRET is required in production")
        require(qr_secret != "CHANGE_ME", "ATTENDANCE_QR_SECRET must be changed")
        require(
            qr_secret != (values.get("JWT_SECRET_KEY") or values.get("SECRET_KEY")),
            "ATTENDANCE_QR_SECRET must differ from JWT secret",
        )


def validate_nfc(values: dict[str, str]) -> None:
    if values.get("ATTENDANCE_NFC_ENABLED", "true").lower() != "true":
        return
    if values.get("APP_ENV") == "production":
        nfc_secret = values.get("ATTENDANCE_NFC_HASH_SECRET")
        require(bool(nfc_secret), "ATTENDANCE_NFC_HASH_SECRET is required in production")
        require(nfc_secret != "CHANGE_ME", "ATTENDANCE_NFC_HASH_SECRET must be changed")
        require(
            nfc_secret != (values.get("JWT_SECRET_KEY") or values.get("SECRET_KEY")),
            "ATTENDANCE_NFC_HASH_SECRET must differ from JWT secret",
        )
        require(
            nfc_secret != values.get("ATTENDANCE_QR_SECRET"),
            "ATTENDANCE_NFC_HASH_SECRET must differ from QR secret",
        )


def validate_payments(values: dict[str, str]) -> str:
    mobile_money_enabled = values.get("MOBILE_MONEY_ENABLED", "false").lower() == "true"
    if not mobile_money_enabled:
        return "Payment configuration valid or disabled"
    provider = values.get("MOBILE_MONEY_PROVIDER", "")
    require(provider in {"mock", "paydunya", "manual_proof"}, "Unsupported MOBILE_MONEY_PROVIDER")
    require(values.get("PAYMENT_CURRENCY") == "XOF", "PAYMENT_CURRENCY must be XOF")
    if provider == "paydunya":
        mode = values.get("PAYDUNYA_MODE", "")
        require(mode in {"test", "live"}, "PAYDUNYA_MODE must be test or live")
        for key in (
            "PAYDUNYA_MASTER_KEY",
            "PAYDUNYA_PUBLIC_KEY",
            "PAYDUNYA_PRIVATE_KEY",
            "PAYDUNYA_TOKEN",
        ):
            require(bool(values.get(key)), f"{key} is required when PayDunya is enabled")
        if mode == "live":
            callback = values.get("PAYDUNYA_CALLBACK_URL", "")
            require(callback.startswith("https://"), "PAYDUNYA_CALLBACK_URL must be HTTPS in live mode")
    return "Payment configuration valid or disabled"


def validate_environment(path: Path) -> list[str]:
    values, warnings = parse_env_file(path)
    messages = []
    validate_database(values)
    messages.append("Database configuration valid")
    validate_storage(values)
    messages.append("Storage configuration valid")
    warnings.extend(validate_jwt(values))
    messages.append("JWT configuration valid")
    validate_qr(values)
    messages.append("QR configuration valid")
    validate_nfc(values)
    messages.append("NFC configuration valid")
    messages.append(validate_payments(values))
    messages.extend(f"Warning: {warning}" for warning in warnings)
    return messages


def main() -> int:
    env_path = Path(sys.argv[1]) if len(sys.argv) > 1 else backend_dir() / ".env"
    try:
        messages = validate_environment(env_path)
    except Exception as exc:
        print("Environment invalid")
        print(str(exc))
        return 1

    print("Environment valid")
    for message in messages:
        print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
