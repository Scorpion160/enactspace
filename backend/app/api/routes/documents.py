from datetime import datetime

from fastapi import Request
from app.services.audit_service import create_audit_log, get_client_ip

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.document import Document
from app.models.user import User
from app.schemas.document import DocumentCreate, DocumentUpdate, DocumentRead
from app.api.deps import (
    get_current_active_validated_user,
    require_enacchef_or_admin,
)

router = APIRouter(prefix="/documents", tags=["Documents"])


VALID_DOCUMENT_VISIBILITIES = {
    "public_club",
    "internal",
    "pole_only",
    "project_only",
    "enacchef_only",
    "private",
}

VALID_DOCUMENT_CATEGORIES = {
    "general",
    "pv",
    "rapport",
    "budget",
    "fiche_projet",
    "pitch_deck",
    "support_formation",
    "photo",
    "video",
    "code_source",
    "administratif",
    "partenariat",
    "autre",
}


def get_document_or_404(db: Session, document_id: str) -> Document:
    document = db.query(Document).filter(Document.id == document_id).first()

    if not document:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document introuvable",
        )

    return document


@router.post("/", response_model=DocumentRead)
def create_document(
    payload: DocumentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    if payload.visibility not in VALID_DOCUMENT_VISIBILITIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Visibilité invalide",
        )

    if payload.category and payload.category not in VALID_DOCUMENT_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Catégorie invalide",
        )

    document = Document(
        title=payload.title,
        description=payload.description,
        file_url=payload.file_url,
        file_type=payload.file_type,
        category=payload.category,
        uploaded_by=current_user.id,
        visibility=payload.visibility,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        event_id=payload.event_id,
        season_id=payload.season_id,
        is_template=payload.is_template,
        is_official=False,
    )

    db.add(document)
    db.commit()
    db.refresh(document)

    return document


@router.get("/", response_model=list[DocumentRead])
def list_documents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
    search: str | None = Query(default=None),
    category: str | None = Query(default=None),
    visibility: str | None = Query(default=None),
    pole_id: str | None = Query(default=None),
    project_id: str | None = Query(default=None),
    event_id: str | None = Query(default=None),
    season_id: str | None = Query(default=None),
    is_template: bool | None = Query(default=None),
    is_official: bool | None = Query(default=None),
):
    query = db.query(Document)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (Document.title.ilike(pattern)) |
            (Document.description.ilike(pattern))
        )

    if category:
        query = query.filter(Document.category == category)

    if visibility:
        query = query.filter(Document.visibility == visibility)

    if pole_id:
        query = query.filter(Document.pole_id == pole_id)

    if project_id:
        query = query.filter(Document.project_id == project_id)

    if event_id:
        query = query.filter(Document.event_id == event_id)

    if season_id:
        query = query.filter(Document.season_id == season_id)

    if is_template is not None:
        query = query.filter(Document.is_template == is_template)

    if is_official is not None:
        query = query.filter(Document.is_official == is_official)

    return query.order_by(Document.created_at.desc()).all()


@router.get("/templates", response_model=list[DocumentRead])
def list_templates(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Document).filter(
        Document.is_template == True
    ).order_by(Document.created_at.desc()).all()


@router.get("/official", response_model=list[DocumentRead])
def list_official_documents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return db.query(Document).filter(
        Document.is_official == True
    ).order_by(Document.created_at.desc()).all()


@router.get("/{document_id}", response_model=DocumentRead)
def get_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    return get_document_or_404(db, document_id)


@router.patch("/{document_id}", response_model=DocumentRead)
def update_document(
    document_id: str,
    payload: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    document = get_document_or_404(db, document_id)

    if payload.visibility is not None:
        if payload.visibility not in VALID_DOCUMENT_VISIBILITIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Visibilité invalide",
            )
        document.visibility = payload.visibility

    if payload.category is not None:
        if payload.category not in VALID_DOCUMENT_CATEGORIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Catégorie invalide",
            )
        document.category = payload.category

    if payload.title is not None:
        document.title = payload.title

    if payload.description is not None:
        document.description = payload.description

    if payload.file_url is not None:
        document.file_url = payload.file_url

    if payload.file_type is not None:
        document.file_type = payload.file_type

    if payload.pole_id is not None:
        document.pole_id = payload.pole_id

    if payload.project_id is not None:
        document.project_id = payload.project_id

    if payload.event_id is not None:
        document.event_id = payload.event_id

    if payload.season_id is not None:
        document.season_id = payload.season_id

    if payload.is_template is not None:
        document.is_template = payload.is_template

    document.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(document)

    return document


@router.post("/{document_id}/validate", response_model=DocumentRead)
def validate_document(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    document = get_document_or_404(db, document_id)

    document.is_official = True
    document.validated_by = current_user.id
    document.validated_at = datetime.utcnow()
    document.updated_at = datetime.utcnow()

    create_audit_log(
        db=db,
        action="validation_document",
        user_id=current_user.id,
        entity_type="document",
        entity_id=document.id,
        old_value={"is_official": False},
        new_value={
            "is_official": True,
            "validated_by": str(current_user.id),
        },
        ip_address=get_client_ip(request),
    )
    db.commit()
    db.refresh(document)

    return document


@router.post("/{document_id}/unvalidate", response_model=DocumentRead)
def unvalidate_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    document = get_document_or_404(db, document_id)

    document.is_official = False
    document.validated_by = None
    document.validated_at = None
    document.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(document)

    return document


@router.delete("/{document_id}")
def delete_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_enacchef_or_admin),
):
    document = get_document_or_404(db, document_id)

    db.delete(document)
    db.commit()

    return {
        "ok": True,
        "message": "Document supprimé",
    }
