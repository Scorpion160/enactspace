from pathlib import Path

from sqlalchemy.orm import Session

from app.db.database import SessionLocal
from app.models.account import LegalDocument


DRAFTS = (
    ("privacy_policy", "v1-draft", "Politique de confidentialité — brouillon", "privacy_policy_v1_draft.md"),
    ("terms_of_use", "v1-draft", "Conditions d'utilisation — brouillon", "terms_of_use_v1_draft.md"),
)


def bootstrap_legal_drafts(db: Session, docs_root: Path | None = None) -> int:
    root = docs_root or Path(__file__).resolve().parents[3] / "docs" / "legal"
    created = 0
    for document_type, version, title, filename in DRAFTS:
        existing = db.query(LegalDocument).filter(
            LegalDocument.document_type == document_type,
            LegalDocument.version == version,
        ).first()
        if existing:
            continue
        content = (root / filename).read_text(encoding="utf-8")
        db.add(LegalDocument(
            document_type=document_type,
            version=version,
            title=title,
            content=content,
            is_active=False,
            published_at=None,
            requires_acceptance=True,
        ))
        created += 1
    db.commit()
    return created


if __name__ == "__main__":
    with SessionLocal() as session:
        count = bootstrap_legal_drafts(session)
        print(f"{count} brouillon(s) juridique(s) créé(s). Aucune publication effectuée.")
