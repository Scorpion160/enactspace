import hashlib
import hmac
import re

from app.core.config import settings
from app.models.attendance import AttendanceNfcTag


ACTIVE_NFC_TAG_STATUS = "active"
REVOKED_NFC_TAG_STATUSES = {"revoked", "lost", "replaced", "disabled"}
NFC_TAG_STATUSES = {ACTIVE_NFC_TAG_STATUS, *REVOKED_NFC_TAG_STATUSES}


class AttendanceNfcTagError(ValueError):
    pass


def normalize_nfc_tag_payload(tag_payload: str) -> str:
    normalized = re.sub(r"[\s:-]+", "", tag_payload.strip()).upper()
    if len(normalized) < 4:
        raise AttendanceNfcTagError("Tag NFC invalide")
    return normalized


def hash_nfc_tag_payload(tag_payload: str) -> str:
    normalized = normalize_nfc_tag_payload(tag_payload)
    return hmac.new(
        settings.attendance_nfc_hash_secret.encode("utf-8"),
        normalized.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def mask_nfc_tag_hash(tag_uid_hash: str) -> str:
    suffix = tag_uid_hash[-4:].upper() if tag_uid_hash else "----"
    return f"Badge ****{suffix}"


def nfc_tag_read_payload(tag: AttendanceNfcTag) -> dict:
    return {
        "id": tag.id,
        "member_id": tag.member_id,
        "tag_label": tag.tag_label,
        "tag_type": tag.tag_type,
        "status": tag.status,
        "masked_tag": mask_nfc_tag_hash(tag.tag_uid_hash),
        "assigned_by_id": tag.assigned_by_id,
        "assigned_at": tag.assigned_at,
        "revoked_by_id": tag.revoked_by_id,
        "revoked_at": tag.revoked_at,
        "last_used_at": tag.last_used_at,
        "created_at": tag.created_at,
        "updated_at": tag.updated_at,
    }
