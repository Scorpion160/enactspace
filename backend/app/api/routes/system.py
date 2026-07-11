from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.database import get_db


router = APIRouter(prefix="/system", tags=["system"])


def _storage_root() -> Path:
    configured_storage_path = Path(settings.FILE_STORAGE_PATH)
    if configured_storage_path.is_absolute():
        return configured_storage_path
    return Path(__file__).resolve().parents[3] / configured_storage_path


def _check_database(db: Session) -> dict:
    try:
        db.execute(text("SELECT 1"))
        return {"reachable": True}
    except Exception as error:
        return {
            "reachable": False,
            "error": error.__class__.__name__,
        }


def _check_storage() -> dict:
    root = _storage_root()
    try:
        root.mkdir(parents=True, exist_ok=True)
        probe = root / f".health_{uuid4().hex}"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
        return {
            "reachable": root.exists() and root.is_dir(),
            "path_configured": bool(settings.FILE_STORAGE_PATH),
            "writable": True,
        }
    except Exception as error:
        return {
            "reachable": False,
            "path_configured": bool(settings.FILE_STORAGE_PATH),
            "writable": False,
            "error": error.__class__.__name__,
        }


@router.get("/status")
def system_status(response: Response, db: Session = Depends(get_db)):
    database = _check_database(db)
    storage = _check_storage()
    online = database["reachable"] and storage["reachable"]

    if not online:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "ok": online,
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.APP_ENV,
        "backend": {"online": True},
        "database": database,
        "storage": storage,
        "features": {
            "email_enabled": settings.email_enabled,
            "push_enabled": settings.push_enabled,
            "payment_provider_enabled": settings.PAYMENT_PROVIDER_ENABLED,
            "payment_provider": settings.PAYMENT_PROVIDER,
        },
    }
