from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_active_validated_user, get_user_role_names
from app.core.roles import SECRETARY_ROLE, TEAM_LEADER_ROLE
from app.db.database import get_db
from app.models.event import Event
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.pole import Pole
from app.models.project import Project
from app.models.season import Season
from app.models.user import User
from app.schemas.institutional_document import (
    InstitutionalDocumentCancel,
    InstitutionalDocumentReject,
    InstitutionalDocumentRequestCreate,
    InstitutionalDocumentRequestRead,
    InstitutionalDocumentRequestUpdate,
    InstitutionalTemplateRead,
)
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.institutional_document_service import (
    INSTITUTIONAL_SLOGAN,
    INSTITUTIONAL_TEMPLATES,
    REQUEST_STATUSES,
    allocate_official_reference,
    can_access_request,
    can_create_request,
    can_start_template,
    can_submit_request,
    get_current_season,
    get_template_rule,
    next_status_after_sg_validation,
    next_status_after_submit,
    request_flags,
    validate_payload,
    validate_request_scope,
)


router = APIRouter(prefix="/institutional-documents", tags=["Institutional documents"])


def _request_payload(
    db: Session,
    current_user: User,
    item: InstitutionalDocumentRequest,
) -> InstitutionalDocumentRequestRead:
    rule = get_template_rule(item.template_code)
    flags = request_flags(db, current_user, item)
    return InstitutionalDocumentRequestRead(
        id=item.id,
        template_code=item.template_code,
        template_label=rule.label,
        template_version=item.template_version,
        status=item.status,
        payload=item.payload_json or {},
        requested_by=item.requested_by,
        submitted_by=item.submitted_by,
        submitted_at=item.submitted_at,
        sg_validated_by=item.sg_validated_by,
        sg_validated_at=item.sg_validated_at,
        approved_by=item.approved_by,
        approved_at=item.approved_at,
        rejected_by=item.rejected_by,
        rejected_at=item.rejected_at,
        rejection_reason=item.rejection_reason,
        cancelled_by=item.cancelled_by,
        cancelled_at=item.cancelled_at,
        cancellation_reason=item.cancellation_reason,
        pole_id=item.pole_id,
        project_id=item.project_id,
        event_id=item.event_id,
        season_id=item.season_id,
        sequence_number=item.sequence_number,
        official_reference=item.official_reference,
        generated_document_id=item.generated_document_id,
        generated_at=item.generated_at,
        created_at=item.created_at,
        updated_at=item.updated_at,
        **flags,
    )


def _audit(
    db: Session,
    http_request: Request,
    current_user: User,
    item: InstitutionalDocumentRequest,
    action: str,
    *,
    old_status: str | None = None,
    extra: dict | None = None,
) -> None:
    old_value = {"status": old_status} if old_status is not None else None
    new_value = {
        "status": item.status,
        "template_code": item.template_code,
        "official_reference": item.official_reference,
    }
    if extra:
        new_value.update(extra)
    create_audit_log(
        db,
        action=action,
        user_id=current_user.id,
        entity_type="institutional_document_request",
        entity_id=item.id,
        old_value=old_value,
        new_value=new_value,
        ip_address=get_client_ip(http_request),
    )


def _get_request_or_404(db: Session, request_id: UUID) -> InstitutionalDocumentRequest:
    item = (
        db.query(InstitutionalDocumentRequest)
        .filter(InstitutionalDocumentRequest.id == request_id)
        .first()
    )
    if item is None:
        raise HTTPException(status_code=404, detail="Demande institutionnelle introuvable.")
    return item


def _get_accessible_request(
    db: Session,
    current_user: User,
    request_id: UUID,
) -> InstitutionalDocumentRequest:
    item = _get_request_or_404(db, request_id)
    if not can_access_request(db, current_user, item):
        raise HTTPException(status_code=404, detail="Demande institutionnelle introuvable.")
    return item


def _ensure_entity_ids_exist(
    db: Session,
    *,
    pole_id=None,
    project_id=None,
    event_id=None,
    season_id=None,
) -> None:
    checks = (
        (pole_id, Pole, "Pôle introuvable."),
        (project_id, Project, "Projet introuvable."),
        (event_id, Event, "Événement introuvable."),
        (season_id, Season, "Saison introuvable."),
    )
    for entity_id, model, message in checks:
        if (
            entity_id is not None
            and db.query(model).filter(model.id == entity_id).first() is None
        ):
            raise HTTPException(status_code=404, detail=message)


def _officialize_if_validated(db: Session, item: InstitutionalDocumentRequest) -> None:
    if item.status == "validated":
        allocate_official_reference(db, item)


@router.get("/templates", response_model=list[InstitutionalTemplateRead])
def list_institutional_templates(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    result = []
    for rule in INSTITUTIONAL_TEMPLATES.values():
        result.append(
            InstitutionalTemplateRead(
                code=rule.code,
                label=rule.label,
                version=rule.version,
                category=rule.category,
                visibility=rule.visibility,
                scope=rule.scope,
                reference_prefix=rule.reference_prefix,
                slogan=INSTITUTIONAL_SLOGAN,
                requires_sg_validation=rule.requires_sg_validation,
                requires_tl_approval=rule.requires_tl_approval,
                fields=list(rule.fields),
                can_create=can_start_template(db, current_user, rule),
            )
        )
    return result


@router.post(
    "/requests",
    response_model=InstitutionalDocumentRequestRead,
    status_code=status.HTTP_201_CREATED,
)
def create_institutional_document_request(
    payload: InstitutionalDocumentRequestCreate,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    rule = get_template_rule(payload.template_code)
    season_id = payload.season_id
    if season_id is None:
        current_season = get_current_season(db)
        if current_season is None:
            raise HTTPException(
                status_code=409,
                detail="Aucune saison courante n’est configurée.",
            )
        season_id = current_season.id

    _ensure_entity_ids_exist(
        db,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        event_id=payload.event_id,
        season_id=season_id,
    )
    validate_request_scope(
        db,
        rule,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
    )
    if not can_create_request(
        db,
        current_user,
        rule,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
    ):
        detail = "Vous n’êtes pas autorisé à créer ce type de document."
        if rule.code == "notification_renvoi":
            detail = (
                "La notification de renvoi peut uniquement être créée par le chef "
                "du Pôle Veille ou son adjoint."
            )
        raise HTTPException(status_code=403, detail=detail)

    item = InstitutionalDocumentRequest(
        template_code=rule.code,
        template_version=rule.version,
        status="draft",
        payload_json=payload.payload,
        requested_by=current_user.id,
        pole_id=payload.pole_id,
        project_id=payload.project_id,
        event_id=payload.event_id,
        season_id=season_id,
    )
    db.add(item)
    db.flush()
    _audit(db, http_request, current_user, item, "institutional_document.created")
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.get("/requests", response_model=list[InstitutionalDocumentRequestRead])
def list_institutional_document_requests(
    request_status: str | None = Query(default=None, alias="status"),
    template_code: str | None = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    query = db.query(InstitutionalDocumentRequest)
    if request_status is not None:
        if request_status not in REQUEST_STATUSES:
            raise HTTPException(status_code=400, detail="Statut invalide.")
        query = query.filter(InstitutionalDocumentRequest.status == request_status)
    if template_code is not None:
        get_template_rule(template_code)
        query = query.filter(InstitutionalDocumentRequest.template_code == template_code)

    rows = query.order_by(InstitutionalDocumentRequest.created_at.desc()).all()
    return [
        _request_payload(db, current_user, item)
        for item in rows
        if can_access_request(db, current_user, item)
    ]


@router.get("/requests/{request_id}", response_model=InstitutionalDocumentRequestRead)
def get_institutional_document_request(
    request_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    return _request_payload(db, current_user, item)


@router.patch("/requests/{request_id}", response_model=InstitutionalDocumentRequestRead)
def update_institutional_document_request(
    request_id: UUID,
    payload: InstitutionalDocumentRequestUpdate,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    if item.requested_by != current_user.id or item.status not in {"draft", "rejected"}:
        raise HTTPException(
            status_code=403,
            detail="Seul l’auteur peut modifier un brouillon ou une demande rejetée.",
        )

    old_status = item.status
    fields_set = payload.model_fields_set
    if "payload" in fields_set:
        item.payload_json = payload.payload or {}
    for field_name in ("pole_id", "project_id", "event_id", "season_id"):
        if field_name in fields_set:
            setattr(item, field_name, getattr(payload, field_name))

    if item.season_id is None:
        current_season = get_current_season(db)
        if current_season is None:
            raise HTTPException(
                status_code=409, detail="Aucune saison courante n’est configurée."
            )
        item.season_id = current_season.id

    rule = get_template_rule(item.template_code)
    _ensure_entity_ids_exist(
        db,
        pole_id=item.pole_id,
        project_id=item.project_id,
        event_id=item.event_id,
        season_id=item.season_id,
    )
    validate_request_scope(db, rule, pole_id=item.pole_id, project_id=item.project_id)
    if not can_create_request(
        db,
        current_user,
        rule,
        pole_id=item.pole_id,
        project_id=item.project_id,
    ):
        raise HTTPException(
            status_code=403, detail="Périmètre non autorisé pour cet utilisateur."
        )

    if item.status == "rejected":
        item.status = "draft"
    item.updated_at = datetime.utcnow()
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.updated",
        old_status=old_status,
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.post("/requests/{request_id}/submit", response_model=InstitutionalDocumentRequestRead)
def submit_institutional_document_request(
    request_id: UUID,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    if item.status not in {"draft", "rejected"}:
        raise HTTPException(
            status_code=409,
            detail="Cette demande ne peut pas être soumise dans son état actuel.",
        )
    if not can_submit_request(db, current_user, item):
        detail = "Vous n’êtes pas autorisé à soumettre cette demande."
        if item.template_code == "notification_renvoi":
            detail = (
                "Seul le chef du Pôle Veille ou son adjoint peut soumettre une "
                "notification de renvoi."
            )
        raise HTTPException(status_code=403, detail=detail)

    rule = get_template_rule(item.template_code)
    validate_request_scope(db, rule, pole_id=item.pole_id, project_id=item.project_id)
    validate_payload(rule, item.payload_json or {})

    old_status = item.status
    now = datetime.utcnow()
    item.submitted_by = current_user.id
    item.submitted_at = now
    item.sg_validated_by = None
    item.sg_validated_at = None
    item.approved_by = None
    item.approved_at = None
    item.rejected_by = None
    item.rejected_at = None
    item.rejection_reason = None
    item.status = next_status_after_submit(db, item)
    item.updated_at = now
    _officialize_if_validated(db, item)
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.submitted",
        old_status=old_status,
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.post("/requests/{request_id}/sg-validate", response_model=InstitutionalDocumentRequestRead)
def sg_validate_institutional_document_request(
    request_id: UUID,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    roles = get_user_role_names(db, current_user.id)
    if SECRETARY_ROLE not in roles:
        raise HTTPException(
            status_code=403, detail="Validation réservée au Secrétariat Général."
        )
    if item.status != "pending_sg_validation":
        raise HTTPException(
            status_code=409, detail="Cette demande n’attend pas de validation SG."
        )
    if item.requested_by == current_user.id:
        raise HTTPException(
            status_code=409, detail="L’auteur ne peut pas valider sa propre demande."
        )

    old_status = item.status
    now = datetime.utcnow()
    item.sg_validated_by = current_user.id
    item.sg_validated_at = now
    item.status = next_status_after_sg_validation(db, item)
    item.updated_at = now
    _officialize_if_validated(db, item)
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.sg_validated",
        old_status=old_status,
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.post("/requests/{request_id}/approve", response_model=InstitutionalDocumentRequestRead)
def approve_institutional_document_request(
    request_id: UUID,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    roles = get_user_role_names(db, current_user.id)
    if TEAM_LEADER_ROLE not in roles:
        raise HTTPException(status_code=403, detail="Approbation réservée au Team Leader.")
    if item.status != "pending_approval":
        raise HTTPException(
            status_code=409, detail="Cette demande n’attend pas d’approbation."
        )
    if item.requested_by == current_user.id or item.sg_validated_by == current_user.id:
        raise HTTPException(
            status_code=409,
            detail="L’approbateur doit être distinct de l’auteur et du validateur SG.",
        )

    old_status = item.status
    now = datetime.utcnow()
    item.approved_by = current_user.id
    item.approved_at = now
    item.status = "validated"
    item.updated_at = now
    allocate_official_reference(db, item)
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.approved",
        old_status=old_status,
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.post("/requests/{request_id}/reject", response_model=InstitutionalDocumentRequestRead)
def reject_institutional_document_request(
    request_id: UUID,
    payload: InstitutionalDocumentReject,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    roles = get_user_role_names(db, current_user.id)
    if item.requested_by == current_user.id:
        raise HTTPException(
            status_code=409, detail="L’auteur ne peut pas rejeter sa propre demande."
        )
    if item.status == "pending_sg_validation":
        if SECRETARY_ROLE not in roles:
            raise HTTPException(
                status_code=403,
                detail="Rejet réservé au Secrétariat Général à cette étape.",
            )
    elif item.status == "pending_approval":
        if TEAM_LEADER_ROLE not in roles:
            raise HTTPException(
                status_code=403,
                detail="Rejet réservé au Team Leader à cette étape.",
            )
        if item.sg_validated_by == current_user.id:
            raise HTTPException(
                status_code=409,
                detail="Le même utilisateur ne peut pas valider puis rejeter en approbation.",
            )
    else:
        raise HTTPException(
            status_code=409,
            detail="Cette demande ne peut pas être rejetée dans son état actuel.",
        )

    old_status = item.status
    now = datetime.utcnow()
    item.status = "rejected"
    item.rejected_by = current_user.id
    item.rejected_at = now
    item.rejection_reason = payload.reason.strip()
    item.updated_at = now
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.rejected",
        old_status=old_status,
        extra={"reason": item.rejection_reason},
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)


@router.post("/requests/{request_id}/cancel", response_model=InstitutionalDocumentRequestRead)
def cancel_institutional_document_request(
    request_id: UUID,
    payload: InstitutionalDocumentCancel,
    http_request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_active_validated_user),
):
    item = _get_accessible_request(db, current_user, request_id)
    if item.requested_by != current_user.id:
        raise HTTPException(status_code=403, detail="Seul l’auteur peut annuler sa demande.")
    if item.status not in {"draft", "rejected", "pending_sg_validation"}:
        raise HTTPException(
            status_code=409,
            detail="La demande est trop avancée pour être annulée par son auteur.",
        )

    old_status = item.status
    now = datetime.utcnow()
    item.status = "cancelled"
    item.cancelled_by = current_user.id
    item.cancelled_at = now
    item.cancellation_reason = payload.reason.strip() if payload.reason else None
    item.updated_at = now
    _audit(
        db,
        http_request,
        current_user,
        item,
        "institutional_document.cancelled",
        old_status=old_status,
        extra={"reason": item.cancellation_reason},
    )
    db.commit()
    db.refresh(item)
    return _request_payload(db, current_user, item)
