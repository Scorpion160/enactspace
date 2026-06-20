from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.db.database import get_db
from app.models.document import Document
from app.models.event import Event
from app.models.pole import PoleMember
from app.models.project import ProjectMember
from app.models.user import User
from app.schemas.document import DocumentCreate, DocumentUpdate, DocumentRead
from app.api.deps import (
    get_current_active_validated_user,
    get_user_role_names,
)
from app.services.audit_service import create_audit_log, get_client_ip

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

GLOBAL_DOCUMENT_MANAGERS = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
ENACCHEF_ROLES = GLOBAL_DOCUMENT_MANAGERS | {
    "financier",
    "faculty_advisor",
    "chef_pole",
    "adjoint_chef_pole",
    "chef_projet",
    "adjoint_chef_projet",
}
POLE_LEAD_POSITIONS = {"chef_pole", "adjoint_chef_pole"}
PROJECT_LEAD_POSITIONS = {"chef_projet", "adjoint_chef_projet"}


def active_pole_ids_query(db: Session, user_id):
    return db.query(PoleMember.pole_id).filter(
        PoleMember.user_id == user_id,
        PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
    )


def active_project_ids_query(db: Session, user_id):
    return db.query(ProjectMember.project_id).filter(
        ProjectMember.user_id == user_id,
        ProjectMember.is_active.is_(True),
        ProjectMember.left_at.is_(None),
    )


def visible_documents_query(db: Session, current_user: User):
    query = db.query(Document)
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_DOCUMENT_MANAGERS):
        return query

    clauses = [
        Document.visibility == "public_club",
        Document.uploaded_by == current_user.id,
    ]
    is_alumni = (
        current_user.status == "alumni"
        or current_user.profile_type == "alumni"
        or "alumni" in roles
    )
    if not is_alumni:
        clauses.append(Document.visibility == "internal")
        clauses.append(
            and_(
                Document.visibility == "pole_only",
                Document.pole_id.in_(
                    active_pole_ids_query(db, current_user.id)
                ),
            )
        )
        clauses.append(
            and_(
                Document.visibility == "project_only",
                Document.project_id.in_(
                    active_project_ids_query(db, current_user.id)
                ),
            )
        )
        if roles.intersection(ENACCHEF_ROLES):
            clauses.append(Document.visibility == "enacchef_only")

    return query.filter(or_(*clauses))


def is_scope_lead(db: Session, current_user: User, document: Document) -> bool:
    if document.pole_id is not None:
        if (
            db.query(PoleMember.id)
            .filter(
                PoleMember.pole_id == document.pole_id,
                PoleMember.user_id == current_user.id,
                PoleMember.is_active.is_(True),
                PoleMember.left_at.is_(None),
                PoleMember.position.in_(POLE_LEAD_POSITIONS),
            )
            .first()
        ):
            return True
    if document.project_id is not None:
        if (
            db.query(ProjectMember.id)
            .filter(
                ProjectMember.project_id == document.project_id,
                ProjectMember.user_id == current_user.id,
                ProjectMember.is_active.is_(True),
                ProjectMember.left_at.is_(None),
                ProjectMember.position.in_(PROJECT_LEAD_POSITIONS),
            )
            .first()
        ):
            return True
    if document.event_id is not None:
        if (
            db.query(Event.id)
            .filter(
                Event.id == document.event_id,
                Event.created_by == current_user.id,
            )
            .first()
        ):
            return True
    return False


def can_manage_document(
    db: Session,
    current_user: User,
    document: Document,
) -> bool:
    roles = get_user_role_names(db, current_user.id)
    return (
        bool(roles.intersection(GLOBAL_DOCUMENT_MANAGERS))
        or is_scope_lead(db, current_user, document)
        or (
            document.uploaded_by == current_user.id
            and not document.is_official
        )
    )


def can_validate_document(
    db: Session,
    current_user: User,
    document: Document,
) -> bool:
    roles = get_user_role_names(db, current_user.id)
    return bool(roles.intersection(GLOBAL_DOCUMENT_MANAGERS)) or is_scope_lead(
        db,
        current_user,
        document,
    )


def document_payload(
    db: Session,
    current_user: User,
    document: Document,
) -> dict:
    data = DocumentRead.model_validate(document).model_dump()
    data["can_manage"] = can_manage_document(db, current_user, document)
    data["can_validate"] = can_validate_document(db, current_user, document)
    return data


def get_visible_document_or_404(
    db: Session,
    current_user: User,
    document_id: str,
) -> Document:
    document = (
        visible_documents_query(db, current_user)
        .filter(Document.id == document_id)
        .first()
    )
    if document is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Document introuvable",
        )
    return document


def ensure_document_scope(
    db: Session,
    current_user: User,
    visibility: str,
    pole_id=None,
    project_id=None,
) -> None:
    roles = get_user_role_names(db, current_user.id)
    if roles.intersection(GLOBAL_DOCUMENT_MANAGERS):
        return
    if visibility == "enacchef_only" and not roles.intersection(
        ENACCHEF_ROLES
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Visibilité réservée aux Enacchefs",
        )
    if visibility == "pole_only":
        belongs_to_pole = pole_id is not None and (
            active_pole_ids_query(db, current_user.id)
            .filter(PoleMember.pole_id == pole_id)
            .first()
            is not None
        )
        if not belongs_to_pole:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous devez appartenir à ce pôle",
            )
    if visibility == "project_only":
        belongs_to_project = project_id is not None and (
            active_project_ids_query(db, current_user.id)
            .filter(ProjectMember.project_id == project_id)
            .first()
            is not None
        )
        if not belongs_to_project:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Vous devez appartenir à ce projet",
            )


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
    ensure_document_scope(
        db,
        current_user,
        payload.visibility,
        payload.pole_id,
        payload.project_id,
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

    return document_payload(db, current_user, document)


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
    query = visible_documents_query(db, current_user)

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

    documents = query.order_by(Document.created_at.desc()).all()
    return [
        document_payload(db, current_user, document)
        for document in documents
    ]


@router.get("/templates", response_model=list[DocumentRead])
def list_templates(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    documents = visible_documents_query(db, current_user).filter(
        Document.is_template.is_(True)
    ).order_by(Document.created_at.desc()).all()
    return [
        document_payload(db, current_user, document)
        for document in documents
    ]


@router.get("/official", response_model=list[DocumentRead])
def list_official_documents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    documents = visible_documents_query(db, current_user).filter(
        Document.is_official.is_(True)
    ).order_by(Document.created_at.desc()).all()
    return [
        document_payload(db, current_user, document)
        for document in documents
    ]


@router.get("/{document_id}", response_model=DocumentRead)
def get_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = get_visible_document_or_404(db, current_user, document_id)
    return document_payload(db, current_user, document)


@router.patch("/{document_id}", response_model=DocumentRead)
def update_document(
    document_id: str,
    payload: DocumentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = get_visible_document_or_404(db, current_user, document_id)
    if not can_manage_document(db, current_user, document):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Modification réservée au responsable du document",
        )
    ensure_document_scope(
        db,
        current_user,
        payload.visibility or document.visibility,
        payload.pole_id or document.pole_id,
        payload.project_id or document.project_id,
    )

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

    return document_payload(db, current_user, document)


@router.post("/{document_id}/validate", response_model=DocumentRead)
def validate_document(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = get_visible_document_or_404(db, current_user, document_id)
    if not can_validate_document(db, current_user, document):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Validation réservée au responsable du périmètre",
        )

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

    return document_payload(db, current_user, document)


@router.post("/{document_id}/unvalidate", response_model=DocumentRead)
def unvalidate_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = get_visible_document_or_404(db, current_user, document_id)
    if not can_validate_document(db, current_user, document):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Validation réservée au responsable du périmètre",
        )

    document.is_official = False
    document.validated_by = None
    document.validated_at = None
    document.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(document)

    return document_payload(db, current_user, document)


@router.delete("/{document_id}")
def delete_document(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    document = get_visible_document_or_404(db, current_user, document_id)
    if not can_manage_document(db, current_user, document):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Suppression réservée au responsable du document",
        )

    db.delete(document)
    db.commit()

    return {
        "ok": True,
        "message": "Document supprimé",
    }
