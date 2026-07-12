from datetime import date, datetime
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.database import get_db
from app.models.recruitment import (
    RecruitmentCampaign,
    Application,
    ApplicationReview,
)
from app.models.role import Role, UserRole
from app.models.user import User
from app.core.security import hash_password
from app.schemas.recruitment import (
    RecruitmentCampaignCreate,
    RecruitmentCampaignUpdate,
    RecruitmentCampaignRead,
    ApplicationCreate,
    ApplicationUpdate,
    ApplicationRead,
    ApplicationStatusChange,
    ApplicationTrackingRequest,
    ApplicationTrackingRead,
    ApplicationReviewCreate,
    ApplicationReviewUpdate,
    ApplicationReviewRead,
    ConvertApplicationToUserRequest,
)
from app.api.deps import (
    require_recruitment_access,
    require_sg_or_admin,
    user_has_any_role,
)
from app.core.config import settings
from app.core.roles import RECRUITMENT_ACCESS_ROLES
from app.services.notification_service import notify_user, notify_users


router = APIRouter(prefix="/recruitment", tags=["Recrutement"])


VALID_APPLICATION_STATUSES = {
    "received",
    "preselected",
    "interview",
    "submitted",
    "under_review",
    "interview_scheduled",
    "accepted",
    "rejected",
    "waiting_list",
    "cancelled",
}

APPLICATION_STATUS_ALIASES = {
    "received": "submitted",
    "preselected": "under_review",
    "interview": "interview_scheduled",
}

APPLICATION_TRACKING_NEXT_STEPS = {
    "submitted": "Votre dossier a bien été reçu. Le pôle Veille prépare la présélection.",
    "under_review": "Votre dossier est en cours d'étude par l'équipe recrutement.",
    "interview_scheduled": "Un entretien est prévu ou en préparation. Les détails seront communiqués par email.",
    "accepted": "Votre candidature est acceptée. La création de votre compte EnactSpace va suivre.",
    "rejected": "Le processus est terminé pour cette campagne. Merci pour votre candidature.",
    "waiting_list": "Votre profil est en liste d'attente. Vous serez contacté si une place se libère.",
    "cancelled": "Cette candidature est clôturée pour cette campagne.",
}

APPLICATION_TRACKING_MESSAGES = {
    "submitted": "Candidature reçue.",
    "under_review": "Candidature en cours d'étude.",
    "interview_scheduled": "Entretien programmé.",
    "accepted": "Candidature acceptée.",
    "rejected": "Candidature non retenue.",
    "waiting_list": "Candidature placée en liste d'attente.",
    "cancelled": "Candidature annulée ou clôturée.",
}

APPLICATION_FINAL_RESULTS = {
    "accepted": "Profil retenu pour la prochaine étape d'intégration.",
    "rejected": "Profil non retenu pour cette campagne.",
    "waiting_list": "Profil conservé en attente selon les places disponibles.",
    "cancelled": "Dossier clôturé.",
}

VALID_RECOMMENDATIONS = {
    "favorable",
    "reserve",
    "defavorable",
}

RECRUITMENT_NOTIFICATION_ROLES = RECRUITMENT_ACCESS_ROLES
RECRUITMENT_CONVERSION_ROLES = {
    "administrateur",
    "team_leader",
    "secretaire_generale",
}
REVIEW_ADMIN_ROLES = {"administrateur", "team_leader"}


def normalize_application_status(value: str) -> str:
    status_value = value.strip().lower()
    return APPLICATION_STATUS_ALIASES.get(status_value, status_value)


def get_campaign_or_404(db: Session, campaign_id: str) -> RecruitmentCampaign:
    campaign = db.query(RecruitmentCampaign).filter(
        RecruitmentCampaign.id == campaign_id
    ).first()

    if not campaign:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Campagne de recrutement introuvable",
        )

    return campaign


def campaign_is_open(campaign: RecruitmentCampaign) -> bool:
    today = date.today()
    return (
        campaign.is_active
        and (campaign.start_date is None or campaign.start_date <= today)
        and (campaign.end_date is None or campaign.end_date >= today)
    )


def validate_campaign_dates(start_date, end_date) -> None:
    if start_date is not None and end_date is not None:
        if end_date < start_date:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La date de fin doit suivre la date de début",
            )


def get_application_or_404(db: Session, application_id: str) -> Application:
    application = db.query(Application).filter(
        Application.id == application_id
    ).first()

    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Candidature introuvable",
        )

    return application


def recompute_application_score(db: Session, application: Application):
    avg_score = db.query(func.avg(ApplicationReview.score)).filter(
        ApplicationReview.application_id == application.id,
        ApplicationReview.score.isnot(None),
    ).scalar()

    if avg_score is None:
        application.final_score = None
    else:
        application.final_score = round(float(avg_score), 2)

    application.updated_at = datetime.utcnow()


def notify_recruitment_responsibles(
    db: Session,
    application: Application,
    campaign: RecruitmentCampaign,
) -> None:
    recipients = (
        db.query(User)
        .join(UserRole, UserRole.user_id == User.id)
        .join(Role, Role.id == UserRole.role_id)
        .filter(
            User.is_active == True,
            Role.name.in_(RECRUITMENT_NOTIFICATION_ROLES),
        )
        .distinct()
        .all()
    )

    if not recipients:
        return

    applicant_name = f"{application.first_name} {application.last_name}".strip()
    title = "Nouvelle candidature reçue"
    message = (
        f"{applicant_name or application.email} a postulé à la campagne "
        f"{campaign.title}."
    )

    notify_users(
        db,
        user_ids=[user.id for user in recipients],
        title=title,
        message=message,
        notification_type="application_received",
        related_type="application",
        related_id=application.id,
        dedupe=True,
    )


def notify_application_status_if_linked(
    db: Session,
    application: Application,
) -> None:
    if not application.converted_user_id:
        return

    normalized_status = normalize_application_status(application.status)
    notify_user(
        db,
        user_id=application.converted_user_id,
        title="Statut de candidature mis a jour",
        message=APPLICATION_TRACKING_NEXT_STEPS.get(
            normalized_status,
            "Votre candidature a ete mise a jour.",
        ),
        notification_type="recruitment_status",
        related_type="application",
        related_id=application.id,
        dedupe=True,
    )


@router.post("/campaigns", response_model=RecruitmentCampaignRead)
def create_campaign(
    payload: RecruitmentCampaignCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    validate_campaign_dates(payload.start_date, payload.end_date)
    campaign = RecruitmentCampaign(
        season_id=payload.season_id,
        title=payload.title,
        description=payload.description,
        start_date=payload.start_date,
        end_date=payload.end_date,
        is_active=payload.is_active,
        created_by=current_user.id,
    )

    db.add(campaign)
    db.commit()
    db.refresh(campaign)

    return campaign


@router.get("/campaigns", response_model=list[RecruitmentCampaignRead])
def list_campaigns(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
    is_active: bool | None = Query(default=None),
):
    query = db.query(RecruitmentCampaign)

    if is_active is not None:
        query = query.filter(RecruitmentCampaign.is_active == is_active)

    return query.order_by(RecruitmentCampaign.created_at.desc()).all()


@router.get("/campaigns/public", response_model=list[RecruitmentCampaignRead])
def list_public_active_campaigns(
    db: Session = Depends(get_db),
):
    campaigns = db.query(RecruitmentCampaign).filter(
        RecruitmentCampaign.is_active.is_(True)
    ).order_by(RecruitmentCampaign.created_at.desc()).all()
    return [campaign for campaign in campaigns if campaign_is_open(campaign)]


@router.get("/campaigns/{campaign_id}", response_model=RecruitmentCampaignRead)
def get_campaign(
    campaign_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    return get_campaign_or_404(db, campaign_id)


@router.patch("/campaigns/{campaign_id}", response_model=RecruitmentCampaignRead)
def update_campaign(
    campaign_id: str,
    payload: RecruitmentCampaignUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    campaign = get_campaign_or_404(db, campaign_id)
    validate_campaign_dates(
        payload.start_date or campaign.start_date,
        payload.end_date or campaign.end_date,
    )

    if payload.title is not None:
        campaign.title = payload.title

    if payload.description is not None:
        campaign.description = payload.description

    if payload.start_date is not None:
        campaign.start_date = payload.start_date

    if payload.end_date is not None:
        campaign.end_date = payload.end_date

    if payload.is_active is not None:
        campaign.is_active = payload.is_active

    campaign.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(campaign)

    return campaign


@router.delete("/campaigns/{campaign_id}")
def delete_campaign(
    campaign_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    campaign = get_campaign_or_404(db, campaign_id)

    db.delete(campaign)
    db.commit()

    return {
        "ok": True,
        "message": "Campagne supprimée",
    }


@router.post("/applications", response_model=ApplicationRead)
def submit_application(
    payload: ApplicationCreate,
    db: Session = Depends(get_db),
):
    campaign = get_campaign_or_404(db, str(payload.campaign_id))

    if not campaign_is_open(campaign):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette campagne de recrutement n'est pas ouverte",
        )
    duplicate = (
        db.query(Application.id)
        .filter(
            Application.campaign_id == payload.campaign_id,
            func.lower(Application.email) == payload.email.lower(),
        )
        .first()
    )
    if duplicate:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une candidature existe déjà pour cet email",
        )

    application = Application(
        campaign_id=payload.campaign_id,
        first_name=payload.first_name,
        last_name=payload.last_name,
        gender=payload.gender,
        email=payload.email,
        phone=payload.phone,
        department=payload.department,
        study_level=payload.study_level,
        class_name=payload.class_name,
        motivation=payload.motivation,
        known_enactus_from=payload.known_enactus_from,
        enactus_knowledge=payload.enactus_knowledge,
        other_clubs=payload.other_clubs,
        contribution=payload.contribution,
        project_ideas=payload.project_ideas,
        leadership_profile=payload.leadership_profile,
        preferred_pole=payload.preferred_pole,
        project_interest=payload.project_interest,
        associative_experience=payload.associative_experience,
        availability=payload.availability,
        public_comment=payload.public_comment,
        cv_url=payload.cv_url,
        motivation_letter_url=payload.motivation_letter_url,
        attachment_url=payload.attachment_url,
        status="submitted",
    )

    db.add(application)
    db.flush()
    ensure_tracking_code(db, application)
    notify_recruitment_responsibles(db, application, campaign)
    candidate_email_ready()
    db.commit()
    db.refresh(application)

    return application_payload(db, None, application)


def build_tracking_code(application: Application | None = None) -> str:
    year = datetime.utcnow().year
    if application and application.created_at:
        year = application.created_at.year
    return f"ESP-{year}-{uuid.uuid4().hex[:8].upper()}"


def ensure_tracking_code(db: Session, application: Application) -> str:
    if application.tracking_code:
        return application.tracking_code

    for _ in range(8):
        candidate = build_tracking_code(application)
        exists = (
            db.query(Application.id)
            .filter(Application.tracking_code == candidate)
            .first()
        )
        if not exists:
            application.tracking_code = candidate
            return candidate

    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Impossible de générer un code de suivi unique",
    )


def get_application_by_public_reference(
    db: Session,
    reference: str,
    email: str,
) -> Application | None:
    normalized_reference = reference.strip()
    if not normalized_reference:
        return None

    query = db.query(Application).filter(
        func.lower(Application.email) == email.lower(),
    )

    try:
        application_uuid = uuid.UUID(normalized_reference)
    except ValueError:
        return query.filter(
            func.upper(Application.tracking_code) == normalized_reference.upper()
        ).first()

    return query.filter(Application.id == application_uuid).first()


def candidate_email_ready() -> bool:
    return bool(settings.email_enabled and settings.SMTP_HOST)


def anonymous_code(application: Application) -> str:
    return f"Candidat #{str(application.id).replace('-', '')[:6].upper()}"


def application_payload(
    db: Session,
    current_user: User | None,
    application: Application,
    *,
    anonymized: bool = False,
) -> dict:
    data = ApplicationRead.model_validate(application).model_dump()
    data["status"] = normalize_application_status(application.status)
    data["tracking_code"] = application.tracking_code or str(application.id)
    data["is_anonymized"] = anonymized
    data["anonymous_code"] = anonymous_code(application)
    data["can_convert"] = bool(current_user) and not anonymized and user_has_any_role(
        db,
        current_user.id,
        RECRUITMENT_CONVERSION_ROLES,
    )
    if anonymized:
        code = str(application.id).replace("-", "")[:12]
        data.update(
            {
                "first_name": "Candidat",
                "last_name": anonymous_code(application).split("#")[-1].strip(),
                "email": f"candidate-{code}@example.com",
                "phone": None,
                "tracking_code": anonymous_code(application),
                "cv_url": None,
                "motivation_letter_url": None,
                "known_enactus_from": None,
                "other_clubs": None,
                "associative_experience": None,
                "availability": None,
                "public_comment": None,
                "attachment_url": None,
            }
        )
    return data


def can_manage_review(db: Session, current_user: User, review) -> bool:
    return review.reviewer_id == current_user.id or user_has_any_role(
        db,
        current_user.id,
        REVIEW_ADMIN_ROLES,
    )


@router.post("/applications/track", response_model=ApplicationTrackingRead)
def track_application(
    payload: ApplicationTrackingRequest,
    db: Session = Depends(get_db),
):
    application = get_application_by_public_reference(
        db,
        payload.application_id,
        payload.email,
    )

    if not application:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Aucune candidature ne correspond à cette référence et cet email",
        )

    campaign = get_campaign_or_404(db, str(application.campaign_id))
    normalized_status = normalize_application_status(application.status)
    tracking_code = ensure_tracking_code(db, application)
    db.commit()
    return {
        "application_id": application.id,
        "tracking_code": tracking_code,
        "campaign_title": campaign.title,
        "first_name": application.first_name,
        "last_name": application.last_name,
        "email": application.email,
        "department": application.department,
        "study_level": application.study_level,
        "preferred_pole": application.preferred_pole,
        "project_interest": application.project_interest,
        "status": normalized_status,
        "submitted_at": application.created_at,
        "updated_at": application.updated_at,
        "next_step": APPLICATION_TRACKING_NEXT_STEPS.get(
            normalized_status,
            "Votre dossier est en cours de traitement.",
        ),
        "candidate_message": APPLICATION_TRACKING_MESSAGES.get(normalized_status),
        "interview_details": (
            "Les détails de l'entretien seront communiqués dès validation interne."
            if normalized_status == "interview_scheduled"
            else None
        ),
        "final_result": APPLICATION_FINAL_RESULTS.get(normalized_status),
        "account_created": application.converted_user_id is not None,
    }


@router.get("/applications", response_model=list[ApplicationRead])
def list_applications(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
    campaign_id: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    search: str | None = Query(default=None),
    anonymized: bool = Query(default=False),
):
    query = db.query(Application)

    if campaign_id:
        query = query.filter(Application.campaign_id == campaign_id)

    if status_filter:
        normalized_filter = normalize_application_status(status_filter)
        legacy_matches = [
            legacy
            for legacy, normalized in APPLICATION_STATUS_ALIASES.items()
            if normalized == normalized_filter
        ]
        query = query.filter(
            Application.status.in_([normalized_filter, *legacy_matches])
        )

    if search and not anonymized:
        pattern = f"%{search}%"
        query = query.filter(
            (Application.first_name.ilike(pattern)) |
            (Application.last_name.ilike(pattern)) |
            (Application.email.ilike(pattern)) |
            (Application.department.ilike(pattern))
        )

    applications = query.order_by(Application.created_at.desc()).all()
    return [
        application_payload(
            db,
            current_user,
            application,
            anonymized=anonymized,
        )
        for application in applications
    ]


@router.get("/applications/{application_id}", response_model=ApplicationRead)
def get_application(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = get_application_or_404(db, application_id)
    return application_payload(db, current_user, application)


@router.patch("/applications/{application_id}", response_model=ApplicationRead)
def update_application(
    application_id: str,
    payload: ApplicationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = get_application_or_404(db, application_id)
    old_status = application.status

    if payload.status is not None:
        next_status = normalize_application_status(payload.status)
        if next_status not in VALID_APPLICATION_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut de candidature invalide",
            )
        application.status = next_status

    fields = [
        "gender",
        "phone",
        "department",
        "study_level",
        "class_name",
        "motivation",
        "known_enactus_from",
        "enactus_knowledge",
        "other_clubs",
        "contribution",
        "project_ideas",
        "leadership_profile",
        "preferred_pole",
        "project_interest",
        "associative_experience",
        "availability",
        "public_comment",
        "cv_url",
        "motivation_letter_url",
        "attachment_url",
    ]

    for field in fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(application, field, value)

    application.updated_at = datetime.utcnow()
    if payload.status is not None and application.status != old_status:
        notify_application_status_if_linked(db, application)

    db.commit()
    db.refresh(application)

    return application_payload(db, current_user, application)


@router.post("/applications/{application_id}/status", response_model=ApplicationRead)
def change_application_status(
    application_id: str,
    payload: ApplicationStatusChange,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = get_application_or_404(db, application_id)

    next_status = normalize_application_status(payload.status)
    if next_status not in VALID_APPLICATION_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de candidature invalide",
        )

    application.status = next_status
    application.updated_at = datetime.utcnow()
    notify_application_status_if_linked(db, application)

    db.commit()
    db.refresh(application)

    return application_payload(db, current_user, application)


@router.delete("/applications/{application_id}")
def delete_application(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = get_application_or_404(db, application_id)

    db.delete(application)
    db.commit()

    return {
        "ok": True,
        "message": "Candidature supprimée",
    }


@router.post("/reviews", response_model=ApplicationReviewRead)
def create_or_update_review(
    payload: ApplicationReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    if payload.recommendation not in VALID_RECOMMENDATIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Recommandation invalide",
        )

    if payload.score is not None and (payload.score < 0 or payload.score > 20):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le score doit être compris entre 0 et 20",
        )

    application = get_application_or_404(db, str(payload.application_id))

    review = db.query(ApplicationReview).filter(
        ApplicationReview.application_id == payload.application_id,
        ApplicationReview.reviewer_id == current_user.id,
    ).first()

    if review:
        review.score = payload.score
        review.comment = payload.comment
        review.recommendation = payload.recommendation
        review.updated_at = datetime.utcnow()
    else:
        review = ApplicationReview(
            application_id=payload.application_id,
            reviewer_id=current_user.id,
            score=payload.score,
            comment=payload.comment,
            recommendation=payload.recommendation,
        )
        db.add(review)

    db.flush()

    recompute_application_score(db, application)

    db.commit()
    db.refresh(review)

    return review


@router.get("/applications/{application_id}/reviews", response_model=list[ApplicationReviewRead])
def list_application_reviews(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    get_application_or_404(db, application_id)

    return db.query(ApplicationReview).filter(
        ApplicationReview.application_id == application_id
    ).order_by(ApplicationReview.created_at.desc()).all()


@router.patch("/reviews/{review_id}", response_model=ApplicationReviewRead)
def update_review(
    review_id: str,
    payload: ApplicationReviewUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    review = db.query(ApplicationReview).filter(
        ApplicationReview.id == review_id
    ).first()

    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Évaluation introuvable",
        )
    if not can_manage_review(db, current_user, review):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez modifier que votre propre évaluation",
        )

    if payload.recommendation is not None:
        if payload.recommendation not in VALID_RECOMMENDATIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Recommandation invalide",
            )
        review.recommendation = payload.recommendation

    if payload.score is not None:
        if payload.score < 0 or payload.score > 20:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Le score doit être compris entre 0 et 20",
            )
        review.score = payload.score

    if payload.comment is not None:
        review.comment = payload.comment

    review.updated_at = datetime.utcnow()

    application = get_application_or_404(db, str(review.application_id))
    recompute_application_score(db, application)

    db.commit()
    db.refresh(review)

    return review


@router.delete("/reviews/{review_id}")
def delete_review(
    review_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    review = db.query(ApplicationReview).filter(
        ApplicationReview.id == review_id
    ).first()

    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Évaluation introuvable",
        )
    if not can_manage_review(db, current_user, review):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Vous ne pouvez supprimer que votre propre évaluation",
        )

    application_id = review.application_id

    db.delete(review)
    db.flush()

    application = get_application_or_404(db, str(application_id))
    recompute_application_score(db, application)

    db.commit()

    return {
        "ok": True,
        "message": "Évaluation supprimée",
    }


@router.post("/applications/{application_id}/convert-to-user", response_model=dict)
def convert_application_to_user(
    application_id: str,
    payload: ConvertApplicationToUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    application = get_application_or_404(db, application_id)

    if application.status != "accepted":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La candidature doit être acceptée avant création du compte",
        )
    if len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe initial doit contenir au moins 8 caractères",
        )

    if application.converted_user_id:
        return {
            "ok": True,
            "message": "Un compte existe déjà pour cette candidature",
            "user_id": str(application.converted_user_id),
        }

    existing_user = db.query(User).filter(
        func.lower(User.email) == application.email.lower()
    ).first()

    if existing_user:
        application.converted_user_id = existing_user.id
        application.updated_at = datetime.utcnow()
        notify_user(
            db,
            user_id=existing_user.id,
            title="Candidature liee a votre compte",
            message="Votre candidature Enactus ESP est maintenant liee a votre compte.",
            notification_type="recruitment_update",
            related_type="application",
            related_id=application.id,
            dedupe=True,
        )
        db.commit()

        return {
            "ok": True,
            "message": "Un compte existait déjà avec cet email",
            "user_id": str(existing_user.id),
        }

    user = User(
        first_name=application.first_name,
        last_name=application.last_name,
        email=application.email,
        phone=application.phone,
        password_hash=hash_password(payload.password.strip()),
        department=application.department,
        study_level=application.study_level,
        status="pending",
        email_verified=False,
        is_active=True,
    )

    db.add(user)
    db.flush()

    application.converted_user_id = user.id
    application.updated_at = datetime.utcnow()
    notify_user(
        db,
        user_id=user.id,
        title="Compte EnactSpace cree",
        message="Votre compte candidat a ete cree et attend validation.",
        notification_type="recruitment_update",
        related_type="application",
        related_id=application.id,
        dedupe=True,
    )

    db.commit()
    db.refresh(user)

    return {
        "ok": True,
        "message": "Compte créé avec succès. Il doit être validé par la Secrétaire Générale.",
        "user_id": str(user.id),
    }
