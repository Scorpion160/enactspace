from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.database import get_db
from app.models.recruitment import (
    RecruitmentCampaign,
    Application,
    ApplicationReview,
)
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
    ApplicationReviewCreate,
    ApplicationReviewUpdate,
    ApplicationReviewRead,
    ConvertApplicationToUserRequest,
)
from app.api.deps import get_current_user


router = APIRouter(prefix="/recruitment", tags=["Recrutement"])


VALID_APPLICATION_STATUSES = {
    "received",
    "preselected",
    "interview",
    "accepted",
    "rejected",
}

VALID_RECOMMENDATIONS = {
    "favorable",
    "reserve",
    "defavorable",
}


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


@router.post("/campaigns", response_model=RecruitmentCampaignRead)
def create_campaign(
    payload: RecruitmentCampaignCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
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
    current_user: User = Depends(get_current_user),
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
    return db.query(RecruitmentCampaign).filter(
        RecruitmentCampaign.is_active == True
    ).order_by(RecruitmentCampaign.created_at.desc()).all()


@router.get("/campaigns/{campaign_id}", response_model=RecruitmentCampaignRead)
def get_campaign(
    campaign_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_campaign_or_404(db, campaign_id)


@router.patch("/campaigns/{campaign_id}", response_model=RecruitmentCampaignRead)
def update_campaign(
    campaign_id: str,
    payload: RecruitmentCampaignUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    campaign = get_campaign_or_404(db, campaign_id)

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
    current_user: User = Depends(get_current_user),
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

    if not campaign.is_active:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette campagne de recrutement n'est pas active",
        )

    application = Application(
        campaign_id=payload.campaign_id,
        first_name=payload.first_name,
        last_name=payload.last_name,
        email=payload.email,
        phone=payload.phone,
        department=payload.department,
        study_level=payload.study_level,
        motivation=payload.motivation,
        known_enactus_from=payload.known_enactus_from,
        enactus_knowledge=payload.enactus_knowledge,
        other_clubs=payload.other_clubs,
        contribution=payload.contribution,
        project_ideas=payload.project_ideas,
        leadership_profile=payload.leadership_profile,
        cv_url=payload.cv_url,
        motivation_letter_url=payload.motivation_letter_url,
        status="received",
    )

    db.add(application)
    db.commit()
    db.refresh(application)

    return application


@router.get("/applications", response_model=list[ApplicationRead])
def list_applications(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    campaign_id: str | None = Query(default=None),
    status_filter: str | None = Query(default=None),
    search: str | None = Query(default=None),
):
    query = db.query(Application)

    if campaign_id:
        query = query.filter(Application.campaign_id == campaign_id)

    if status_filter:
        query = query.filter(Application.status == status_filter)

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            (Application.first_name.ilike(pattern)) |
            (Application.last_name.ilike(pattern)) |
            (Application.email.ilike(pattern)) |
            (Application.department.ilike(pattern))
        )

    return query.order_by(Application.created_at.desc()).all()


@router.get("/applications/{application_id}", response_model=ApplicationRead)
def get_application(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return get_application_or_404(db, application_id)


@router.patch("/applications/{application_id}", response_model=ApplicationRead)
def update_application(
    application_id: str,
    payload: ApplicationUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    application = get_application_or_404(db, application_id)

    if payload.status is not None:
        if payload.status not in VALID_APPLICATION_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Statut de candidature invalide",
            )
        application.status = payload.status

    fields = [
        "phone",
        "department",
        "study_level",
        "motivation",
        "known_enactus_from",
        "enactus_knowledge",
        "other_clubs",
        "contribution",
        "project_ideas",
        "leadership_profile",
        "cv_url",
        "motivation_letter_url",
    ]

    for field in fields:
        value = getattr(payload, field)
        if value is not None:
            setattr(application, field, value)

    application.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(application)

    return application


@router.post("/applications/{application_id}/status", response_model=ApplicationRead)
def change_application_status(
    application_id: str,
    payload: ApplicationStatusChange,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    application = get_application_or_404(db, application_id)

    if payload.status not in VALID_APPLICATION_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Statut de candidature invalide",
        )

    application.status = payload.status
    application.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(application)

    return application


@router.delete("/applications/{application_id}")
def delete_application(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
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
    current_user: User = Depends(get_current_user),
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
    current_user: User = Depends(get_current_user),
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
    current_user: User = Depends(get_current_user),
):
    review = db.query(ApplicationReview).filter(
        ApplicationReview.id == review_id
    ).first()

    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Évaluation introuvable",
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
    current_user: User = Depends(get_current_user),
):
    review = db.query(ApplicationReview).filter(
        ApplicationReview.id == review_id
    ).first()

    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Évaluation introuvable",
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
    current_user: User = Depends(get_current_user),
):
    application = get_application_or_404(db, application_id)

    if application.status != "accepted":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La candidature doit être acceptée avant création du compte",
        )

    if application.converted_user_id:
        return {
            "ok": True,
            "message": "Un compte existe déjà pour cette candidature",
            "user_id": str(application.converted_user_id),
        }

    existing_user = db.query(User).filter(
        User.email == application.email
    ).first()

    if existing_user:
        application.converted_user_id = existing_user.id
        application.updated_at = datetime.utcnow()
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
        password_hash=hash_password(payload.password),
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

    db.commit()
    db.refresh(user)

    return {
        "ok": True,
        "message": "Compte créé avec succès. Il doit être validé par la Secrétaire Générale.",
        "user_id": str(user.id),
    }