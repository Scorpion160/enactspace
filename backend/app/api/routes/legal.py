from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, require_admin_or_team_leader
from app.db.database import get_db
from app.models.account import LegalAcceptance, LegalDocument
from app.models.user import User
from app.schemas.account import (
    LegalAcceptanceCreate,
    LegalAcceptanceRead,
    LegalDocumentCreate,
    LegalDocumentPublish,
    LegalDocumentRead,
    LegalDocumentType,
    LegalStatusItem,
)
from app.services.audit_service import create_audit_log


router = APIRouter(prefix="/legal", tags=["Légal et confidentialité"])


@router.post("/documents", response_model=LegalDocumentRead, status_code=201)
def create_legal_document(
    payload: LegalDocumentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    document = LegalDocument(**payload.model_dump(mode="json"))
    db.add(document)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Cette version existe déjà")
    create_audit_log(
        db, "legal_document_created", current_user.id,
        "legal_document", document.id,
        new_value={"type": document.document_type, "version": document.version},
    )
    db.commit()
    db.refresh(document)
    return document


@router.post("/documents/{document_id}/publish", response_model=LegalDocumentRead)
def publish_legal_document(
    document_id: str,
    payload: LegalDocumentPublish,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin_or_team_leader),
):
    document = (
        db.query(LegalDocument)
        .filter(LegalDocument.id == document_id)
        .with_for_update()
        .first()
    )
    if document is None:
        raise HTTPException(status_code=404, detail="Document juridique introuvable")
    now = datetime.utcnow()
    previous_documents = (
        db.query(LegalDocument)
        .filter(
            LegalDocument.document_type == document.document_type,
            LegalDocument.is_active.is_(True),
            LegalDocument.id != document.id,
        )
        .with_for_update()
        .all()
    )
    for previous in previous_documents:
        previous.is_active = False
        previous.updated_at = now
    # Flush the deactivation before activating the replacement so the partial
    # unique index remains valid independently of SQLAlchemy's UPDATE order.
    db.flush()
    document.published_at = document.published_at or now
    document.effective_at = payload.effective_at or document.effective_at or now
    document.is_active = True
    document.updated_at = now
    create_audit_log(
        db, "legal_document_published", current_user.id,
        "legal_document", document.id,
        new_value={"type": document.document_type, "version": document.version},
    )
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=409,
            detail="Une autre version de ce type est déjà active",
        )
    db.refresh(document)
    return document


@router.get("/documents", response_model=list[LegalDocumentRead])
def list_legal_documents(
    document_type: LegalDocumentType | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(LegalDocument).filter(LegalDocument.published_at.is_not(None))
    if document_type:
        query = query.filter(LegalDocument.document_type == document_type.value)
    return query.order_by(LegalDocument.document_type, LegalDocument.published_at.desc()).all()


@router.get("/documents/{document_type}", response_model=LegalDocumentRead)
def get_active_legal_document(
    document_type: LegalDocumentType,
    db: Session = Depends(get_db),
):
    document = db.query(LegalDocument).filter(
        LegalDocument.document_type == document_type.value,
        LegalDocument.published_at.is_not(None),
        LegalDocument.is_active.is_(True),
    ).first()
    if document is None:
        raise HTTPException(status_code=404, detail="Aucune version active publiée")
    return document


@router.get("/status/me", response_model=list[LegalStatusItem])
def get_my_legal_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    documents = db.query(LegalDocument).filter(
        LegalDocument.published_at.is_not(None),
        LegalDocument.is_active.is_(True),
    ).all()
    acceptances = {
        item.legal_document_id: item
        for item in db.query(LegalAcceptance).filter(
            LegalAcceptance.user_id == current_user.id,
            LegalAcceptance.legal_document_id.in_([doc.id for doc in documents]),
        ).all()
    } if documents else {}
    return [
        LegalStatusItem(
            document_type=document.document_type,
            document_id=document.id,
            version=document.version,
            requires_acceptance=document.requires_acceptance,
            accepted=(not document.requires_acceptance or document.id in acceptances),
            accepted_at=acceptances[document.id].accepted_at if document.id in acceptances else None,
        )
        for document in documents
    ]


@router.post("/acceptances", response_model=LegalAcceptanceRead, status_code=201)
def accept_legal_document(
    payload: LegalAcceptanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = db.query(LegalDocument).filter(
        LegalDocument.id == payload.legal_document_id,
        LegalDocument.version == payload.version,
    ).first()
    if document is None:
        raise HTTPException(status_code=404, detail="Document ou version introuvable")
    if document.published_at is None:
        raise HTTPException(status_code=409, detail="Cette version n'est pas publiée")
    if not document.requires_acceptance:
        raise HTTPException(status_code=409, detail="Ce document ne requiert pas d'acceptation")
    existing = db.query(LegalAcceptance).filter(
        LegalAcceptance.user_id == current_user.id,
        LegalAcceptance.legal_document_id == document.id,
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Cette version est déjà acceptée")
    acceptance = LegalAcceptance(
        user_id=current_user.id,
        legal_document_id=document.id,
        document_version=document.version,
        source=payload.source.value if payload.source else None,
    )
    db.add(acceptance)
    try:
        db.flush()
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Cette version est déjà acceptée")
    create_audit_log(
        db, "legal_acceptance", current_user.id,
        "legal_document", document.id,
        new_value={"type": document.document_type, "version": document.version},
    )
    db.commit()
    db.refresh(acceptance)
    return acceptance
