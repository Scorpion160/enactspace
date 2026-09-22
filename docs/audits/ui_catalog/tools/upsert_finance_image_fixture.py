"""Upsert idempotent d'une preuve image Finance dans l'audit UI isolé.

Ce script :
- refuse toute base autre que postgres/enactspace_ui_audit ;
- ne réinitialise aucun schéma ;
- ne supprime aucune donnée ;
- n'effectue aucun appel réseau ;
- crée ou met à jour un StoredFile et un Payment synthétiques.
"""

from __future__ import annotations

import hashlib
import json
import os
import struct
import uuid
import app.models.base  # noqa: F401
from datetime import datetime
from decimal import Decimal
from pathlib import Path

from sqlalchemy.engine import make_url

from app.core.config import settings
from app.db.database import SessionLocal
from app.models.finance import Payment
from app.models.stored_file import StoredFile
from app.models.user import User


NAMESPACE = uuid.UUID("c7b11b65-6718-4d5d-a2db-a47224a6a729")

IMAGE_FILENAME = "audit-payment-proof-image.png"
PAYMENT_REFERENCE = "AUDIT-PAY-IMG-001"
AUDIT_MEMBER_EMAIL = "audit.member@example.test"
AUDIT_ADMIN_EMAIL = "audit.admin@example.test"

EXPECTED_WIDTH = 1200
EXPECTED_HEIGHT = 1600
EXPECTED_AMOUNT = Decimal("3500")
EXPECTED_METHOD = "wave"


def uid(key: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, key)


def require_isolated_database() -> None:
    if os.environ.get("APP_ENV") != "ui_audit":
        raise RuntimeError(
            f"Refus : APP_ENV={os.environ.get('APP_ENV')!r}, attendu 'ui_audit'."
        )

    database_url = os.environ.get("DATABASE_URL", "")
    url = make_url(database_url)

    if url.drivername not in {"postgresql", "postgresql+psycopg"}:
        raise RuntimeError(
            f"Refus : pilote PostgreSQL audit attendu, reçu {url.drivername!r}."
        )

    if url.host != "postgres" or url.database != "enactspace_ui_audit":
        raise RuntimeError(
            "Refus absolu : la base doit être "
            "postgres/enactspace_ui_audit."
        )


def upload_root() -> Path:
    configured = Path(settings.FILE_STORAGE_PATH)

    if configured.is_absolute():
        return configured

    # Même logique générale que le seed, sans modifier le stockage.
    return Path.cwd() / configured


def read_png_dimensions(path: Path) -> tuple[int, int]:
    """Lit directement le chunk IHDR d'un PNG, sans dépendre de Pillow."""
    with path.open("rb") as stream:
        signature = stream.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise RuntimeError(f"{path} n'a pas une signature PNG valide.")

        chunk_length_bytes = stream.read(4)
        chunk_type = stream.read(4)

        if len(chunk_length_bytes) != 4 or chunk_type != b"IHDR":
            raise RuntimeError("Chunk IHDR PNG introuvable.")

        chunk_length = struct.unpack(">I", chunk_length_bytes)[0]
        if chunk_length < 8:
            raise RuntimeError("Chunk IHDR PNG invalide.")

        ihdr_data = stream.read(chunk_length)
        if len(ihdr_data) < 8:
            raise RuntimeError("Données IHDR PNG incomplètes.")

        width, height = struct.unpack(">II", ihdr_data[:8])
        return width, height


def main() -> None:
    require_isolated_database()

    image_path = upload_root() / IMAGE_FILENAME
    if not image_path.is_file():
        raise RuntimeError(f"Preuve image introuvable : {image_path}")

    payload = image_path.read_bytes()
    if not payload:
        raise RuntimeError("La preuve image est vide.")

    width, height = read_png_dimensions(image_path)
    if (width, height) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
        raise RuntimeError(
            "Dimensions inattendues : "
            f"{width}x{height}, attendu "
            f"{EXPECTED_WIDTH}x{EXPECTED_HEIGHT}."
        )

    checksum = hashlib.sha256(payload).hexdigest()
    now = datetime.utcnow()

    db = SessionLocal()
    created_file = False
    created_payment = False

    try:
        admin = (
            db.query(User)
            .filter(User.email == AUDIT_ADMIN_EMAIL)
            .one()
        )
        member = (
            db.query(User)
            .filter(User.email == AUDIT_MEMBER_EMAIL)
            .one()
        )

        stored_file = (
            db.query(StoredFile)
            .filter(StoredFile.stored_filename == IMAGE_FILENAME)
            .one_or_none()
        )

        if stored_file is None:
            stored_file = StoredFile(
                id=uid(f"file:{IMAGE_FILENAME}"),
                original_filename=IMAGE_FILENAME,
                stored_filename=IMAGE_FILENAME,
                mime_type="image/png",
                file_size=len(payload),
                extension="png",
                storage_path=IMAGE_FILENAME,
                storage_scope="audit",
                uploaded_by_id=admin.id,
                is_temporary=False,
                visibility="internal",
                entity_type="audit",
                checksum=checksum,
                created_at=now,
                updated_at=now,
            )
            db.add(stored_file)
            created_file = True
        else:
            stored_file.original_filename = IMAGE_FILENAME
            stored_file.mime_type = "image/png"
            stored_file.file_size = len(payload)
            stored_file.extension = "png"
            stored_file.storage_path = IMAGE_FILENAME
            stored_file.storage_scope = "audit"
            stored_file.uploaded_by_id = admin.id
            stored_file.is_temporary = False
            stored_file.visibility = "internal"
            stored_file.entity_type = "audit"
            stored_file.checksum = checksum
            stored_file.updated_at = now

        db.flush()

        payment = (
            db.query(Payment)
            .filter(Payment.reference == PAYMENT_REFERENCE)
            .one_or_none()
        )

        if payment is None:
            payment = Payment(
                id=uid(f"payment:{PAYMENT_REFERENCE}"),
                user_id=member.id,
                amount=EXPECTED_AMOUNT,
                currency="FCFA",
                method=EXPECTED_METHOD,
                status="pending",
                reference=PAYMENT_REFERENCE,
                proof_url=f"/uploads/{IMAGE_FILENAME}",
                proof_file_id=stored_file.id,
                validated_by=None,
                validated_at=None,
                rejected_at=None,
                rejection_reason=None,
                created_at=now,
            )
            db.add(payment)
            created_payment = True
        else:
            payment.user_id = member.id
            payment.amount = EXPECTED_AMOUNT
            payment.currency = "FCFA"
            payment.method = EXPECTED_METHOD
            payment.status = "pending"
            payment.proof_url = f"/uploads/{IMAGE_FILENAME}"
            payment.proof_file_id = stored_file.id
            payment.validated_by = None
            payment.validated_at = None
            payment.rejected_at = None
            payment.rejection_reason = None

        db.flush()

        duplicate_count = (
            db.query(Payment)
            .filter(Payment.reference == PAYMENT_REFERENCE)
            .count()
        )
        if duplicate_count != 1:
            raise RuntimeError(
                f"Référence {PAYMENT_REFERENCE} présente "
                f"{duplicate_count} fois."
            )

        original_payment = (
            db.query(Payment)
            .filter(Payment.reference == "AUDIT-PAY-000")
            .one()
        )
        if original_payment.status != "pending":
            raise RuntimeError(
                "AUDIT-PAY-000 n'est plus en attente : "
                f"{original_payment.status!r}"
            )
        if original_payment.proof_url != "/uploads/audit-payment-proof.pdf":
            raise RuntimeError(
                "La preuve de AUDIT-PAY-000 a été modifiée."
            )

        db.commit()
        db.refresh(stored_file)
        db.refresh(payment)

        result = {
            "environment": os.environ.get("APP_ENV"),
            "database_host": make_url(
                os.environ["DATABASE_URL"]
            ).host,
            "database_name": make_url(
                os.environ["DATABASE_URL"]
            ).database,
            "payment_id": str(payment.id),
            "reference": payment.reference,
            "user_id": str(payment.user_id),
            "status": payment.status,
            "amount": str(payment.amount),
            "currency": payment.currency,
            "method": payment.method,
            "proof_url": payment.proof_url,
            "proof_file_id": str(payment.proof_file_id),
            "stored_file_id": str(stored_file.id),
            "filename": stored_file.stored_filename,
            "mime_type": stored_file.mime_type,
            "file_size": stored_file.file_size,
            "width": width,
            "height": height,
            "checksum_sha256": checksum,
            "stored_file_created": created_file,
            "payment_created": created_payment,
            "created_or_updated": (
                "created"
                if created_file or created_payment
                else "updated"
            ),
            "original_payment": {
                "reference": original_payment.reference,
                "status": original_payment.status,
                "proof_url": original_payment.proof_url,
            },
        }

        print(json.dumps(result, ensure_ascii=False, sort_keys=True))

    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()