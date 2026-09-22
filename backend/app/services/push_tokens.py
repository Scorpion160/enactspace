import hashlib

from cryptography.fernet import Fernet, InvalidToken

from app.core.config import settings


class PushTokenConfigurationError(RuntimeError):
    pass


def normalize_push_token(token: str) -> str:
    normalized = token.strip()
    if not normalized:
        raise ValueError("Push token must not be blank")
    return normalized


def push_token_hash(token: str) -> str:
    return hashlib.sha256(normalize_push_token(token).encode("utf-8")).hexdigest()


def _fernet() -> Fernet:
    key = settings.PUSH_TOKEN_ENCRYPTION_KEY
    if not key:
        raise PushTokenConfigurationError("Push token encryption is not configured")
    try:
        return Fernet(key.encode("ascii"))
    except (ValueError, UnicodeEncodeError) as error:
        raise PushTokenConfigurationError("Push token encryption key is invalid") from error


def encrypt_push_token(token: str) -> str:
    return _fernet().encrypt(normalize_push_token(token).encode("utf-8")).decode("ascii")


def decrypt_push_token(ciphertext: str) -> str:
    try:
        return _fernet().decrypt(ciphertext.encode("ascii")).decode("utf-8")
    except (InvalidToken, UnicodeError) as error:
        raise PushTokenConfigurationError("Stored push token cannot be decrypted") from error
