from pathlib import Path

from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.models.account import LegalDocument


DOCUMENTS = (
    (
        "privacy_policy",
        "1.0",
        "Politique de confidentialit?",
        "privacy_policy_v1.md",
    ),
    (
        "terms_of_use",
        "1.0",
        "Conditions d'utilisation",
        "terms_of_use_v1.md",
    ),
)


def bootstrap_legal_documents(db: Session, docs_root: Path | None = None) -> int:
    """Create the Enactus ESP validated v1.0 texts without auto-publishing.

    Publication remains an explicit audited action through the legal API.
    """
    root = docs_root or Path(__file__).resolve().parents[3] / "docs" / "legal"
    created = 0
    for document_type, version, title, filename in DOCUMENTS:
        existing = (
            db.query(LegalDocument)
            .filter(
                LegalDocument.document_type == document_type,
                LegalDocument.version == version,
            )
            .first()
        )
        if existing:
            continue
        content = (root / filename).read_text(encoding="utf-8")
        db.add(
            LegalDocument(
                document_type=document_type,
                version=version,
                title=title,
                content=content,
                is_active=False,
                published_at=None,
                requires_acceptance=True,
            )
        )
        created += 1
    db.commit()
    return created


if __name__ == "__main__":
    with SessionLocal() as session:
        count = bootstrap_legal_documents(session)
        print(
            f"{count} document(s) juridique(s) officiel(s) cr??(s). "
            "Publication explicite requise via l'API d'administration."
        )
