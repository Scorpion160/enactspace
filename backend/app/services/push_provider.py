from dataclasses import dataclass
from enum import Enum
from typing import Protocol

from app.core.config import settings


class PushFailureKind(str, Enum):
    invalid_token = "invalid_token"
    transient = "transient"
    unavailable = "unavailable"


class PushProviderError(RuntimeError):
    def __init__(self, kind: PushFailureKind, code: str):
        super().__init__(code)
        self.kind = kind
        self.code = code[:80]


@dataclass(frozen=True)
class PushMessage:
    token: str
    title: str
    body: str
    data: dict[str, str]


class PushProvider(Protocol):
    def send(self, message: PushMessage) -> str: ...


class FirebaseAdminPushProvider:
    def __init__(self) -> None:
        if not settings.FIREBASE_PROJECT_ID:
            raise PushProviderError(PushFailureKind.unavailable, "firebase_not_configured")
        try:
            import firebase_admin
            from firebase_admin import exceptions, messaging

            try:
                self._app = firebase_admin.get_app()
            except ValueError:
                self._app = firebase_admin.initialize_app(
                    options={"projectId": settings.FIREBASE_PROJECT_ID}
                )
            self._messaging = messaging
            self._exceptions = exceptions
        except PushProviderError:
            raise
        except Exception as error:
            raise PushProviderError(PushFailureKind.unavailable, "firebase_init_failed") from error

    def send(self, message: PushMessage) -> str:
        messaging = self._messaging
        try:
            return messaging.send(messaging.Message(
                token=message.token,
                notification=messaging.Notification(title=message.title, body=message.body),
                data=message.data,
                android=messaging.AndroidConfig(notification=messaging.AndroidNotification(
                    channel_id="enactspace_notifications"
                )),
            ), app=self._app)
        except messaging.UnregisteredError as error:
            raise PushProviderError(PushFailureKind.invalid_token, "invalid_registration") from error
        except messaging.SenderIdMismatchError as error:
            raise PushProviderError(PushFailureKind.unavailable, "sender_id_mismatch") from error
        except messaging.QuotaExceededError as error:
            raise PushProviderError(PushFailureKind.transient, "quota_exceeded") from error
        except messaging.ThirdPartyAuthError as error:
            raise PushProviderError(PushFailureKind.unavailable, "provider_auth_failed") from error
        except (self._exceptions.UnavailableError, self._exceptions.InternalError) as error:
            raise PushProviderError(PushFailureKind.transient, "provider_unavailable") from error
        except Exception as error:
            raise PushProviderError(PushFailureKind.transient, "provider_send_failed") from error
