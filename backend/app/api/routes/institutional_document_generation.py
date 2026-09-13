import shutil
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, get_user_role_names
from app.api.routes.institutional_documents import _request_payload
from app.core.roles import ADMIN_ROLE, SECRETARY_ROLE, TEAM_LEADER_ROLE
from app.db.database import get_db
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.user import User
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.institutional_document_service import can_access_request, get_template_rule
from app.services.institutional_pdf_preview_service import compile_request_preview_pdf
from app.services.institutional_pdf_service import (
    InstitutionalPdfError,
    persist_official_pdf,
)
from app.services.notification_service import notify_user


router = APIRouter(
    prefix="/institutional-documents",
    tags=["Institutional document generation"],
)

GENERATOR_ROLES = {ADMIN_ROLE, SECRETARY_ROLE, TEAM_LEADER_ROLE}


def _accessible_request(
    db: Session,
    current_user: User,
    request_id: UUID,
) -> InstitutionalDocumentRequest:
    item = (
        db.query(InstitutionalDocumentRequest)
        .filter(InstitutionalDocumentRequest.id == request_id)
        .first()
    )
    if item is None or not can_access_request(db, current_user, item):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Demande institutionnelle introuvable.",
        )
    return item


@router.get("/renderer-status")
def institutional_renderer_status(
    current_user: User = Depends(get_current_active_validated_user),
):
    executable = shutil.which("pdflatex")
    return {
        "available": executable is not None,
        "engine": "pdflatex",
    }


@router.get("/requests/{request_id}/preview")
def preview_institutional_document(
    request_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _accessible_request(db, current_user, request_id)
    try:
        pdf = compile_request_preview_pdf(db, item)
        safe_name = item.template_code.replace("/", "-")
        return Response(
            content=pdf,
            media_type="application/pdf",
            headers={
                "Content-Disposition": (
                    f'inline; filename="BROUILLON-{safe_name}.pdf"'
                ),
                "Cache-Control": "no-store",
            },
        )
    except HTTPException:
        raise
    except InstitutionalPdfError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="La prévisualisation du PDF institutionnel a échoué.",
        ) from exc


@router.post("/requests/{request_id}/generate")
def generate_institutional_document(
    request_id: UUID,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    roles = get_user_role_names(db, current_user.id)
    if not roles.intersection(GENERATOR_ROLES):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Génération réservée au SG, au Team Leader ou à l'administration.",
        )

    item = _accessible_request(db, current_user, request_id)

    if item.generated_document_id is not None:
        return {
            "request": _request_payload(db, current_user, item).model_dump(mode="json"),
            "document_id": str(item.generated_document_id),
            "official_reference": item.official_reference,
            "already_generated": True,
        }

    if item.status != "validated":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le document doit être validé avant sa génération officielle.",
        )

    try:
        document = persist_official_pdf(db, item)
        create_audit_log(
            db,
            action="institutional_document.generated",
            user_id=current_user.id,
            entity_type="institutional_document_request",
            entity_id=item.id,
            old_value={"status": "validated"},
            new_value={
                "status": "generated",
                "official_reference": item.official_reference,
                "document_id": str(document.id),
                "file_id": str(document.file_id) if document.file_id else None,
            },
            ip_address=get_client_ip(http_request),
        )
        if item.requested_by != current_user.id:
            rule = get_template_rule(item.template_code)
            notify_user(
                db,
                recipient_id=item.requested_by,
                title="PDF institutionnel disponible",
                body=(
                    f"Le PDF officiel « {rule.label} » est disponible dans Documents "
                    f"({item.official_reference})."
                ),
                type="institutional_document",
                entity_type="document",
                entity_id=document.id,
                created_by_id=current_user.id,
            )
        db.commit()
        db.refresh(item)
        return {
            "request": _request_payload(db, current_user, item).model_dump(mode="json"),
            "document_id": str(document.id),
            "file_id": str(document.file_id) if document.file_id else None,
            "file_url": document.file_url,
            "official_reference": item.official_reference,
            "already_generated": False,
        }
    except HTTPException:
        db.rollback()
        raise
    except InstitutionalPdfError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="La génération du PDF institutionnel a échoué.",
        ) from exc
    except Exception as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossible d'archiver le PDF institutionnel.",
        ) from exc
