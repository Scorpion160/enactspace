import secrets
from app.services.request_rate_limit import protect_public_request
from app.services.recruitment_history import application_history, member_name
from app.services.recruitment_questionnaire import effective_questions, questionnaire_version
from app.core.time import utc_now
from datetime import date, datetime, timedelta
import csv
from io import StringIO
import uuid

from fastapi import APIRouter, Depends, HTTPException, Request, status, Query, File, Form, UploadFile
from pydantic import ValidationError
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from sqlalchemy.exc import IntegrityError

from app.db.database import get_db
from app.models.recruitment import (
    RecruitmentCampaign,
    Application,
    ApplicationReview,
)
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.models.role import Role, UserRole
from app.models.user import User
from app.core.security import hash_password
from app.schemas.recruitment import (
    RecruitmentCampaignCreate,
    RecruitmentCampaignUpdate,
    RecruitmentCampaignRead,
    RecruitmentCampaignPublicRead,
    ApplicationCreate,
    ApplicationUpdate,
    ApplicationInterviewSchedule,
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
from app.core.roles import BASE_ACTIVE_ROLE, RECRUITMENT_ACCESS_ROLES
from app.services.notification_service import notify_user, notify_users
from app.services.audit_service import create_audit_log, get_client_ip
from app.services.email_delivery_service import enqueue_email_delivery
from app.services.recruitment_emails import enqueue_candidate_update
from app.services.operational_integrity import lock_row, to_naive_utc


from app.services.recruitment_rubric import VERSION as RUBRIC_VERSION, rubric_payload, assess_ratings, structured_summary

router = APIRouter(prefix="/recruitment", dependencies=[Depends(protect_public_request)], tags=["Recrutement"])


VALID_APPLICATION_STATUSES = {
    "submitted",
    "under_review",
    "interview_scheduled",
    "accepted",
    "rejected",
    "waiting_list",
    "cancelled",
}
APPLICATION_STATUS_TRANSITIONS = {
    "submitted": {"under_review", "cancelled"},
    "under_review": {"interview_scheduled", "waiting_list", "accepted", "rejected", "cancelled"},
    "interview_scheduled": {"under_review", "waiting_list", "accepted", "rejected", "cancelled"},
    "waiting_list": {"interview_scheduled", "accepted", "rejected", "cancelled"},
    "accepted": set(),
    "rejected": set(),
    "cancelled": set(),
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

MEMBER_ONBOARDING_CHECKLIST = [
    {
        "id": "beginner-guide",
        "title": "Guide du débutant",
        "route": "/help",
    },
    {
        "id": "academy-new-enacteur",
        "title": "Parcours Academy — Nouveau Enacteur",
        "route": "/academy",
    },
    {
        "id": "discover-pole",
        "title": "Découvrir mon pôle",
        "route": "/poles",
    },
    {
        "id": "meet-team",
        "title": "Découvrir l'équipe et mon parrain",
        "route": "/members",
    },
    {
        "id": "useful-documents",
        "title": "Consulter les documents utiles",
        "route": "/documents",
    },
    {
        "id": "first-project",
        "title": "Rejoindre un projet ou une première mission",
        "route": "/projects",
    },
]


def member_onboarding_payload() -> dict:
    return {
        "academy_path_id": "new-enacteur",
        "academy_path_title": "Nouveau Enacteur",
        "checklist": [dict(item) for item in MEMBER_ONBOARDING_CHECKLIST],
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


def apply_application_status(application: Application, value: str) -> bool:
    next_status = normalize_application_status(value)
    current_status = normalize_application_status(application.status)
    if next_status not in VALID_APPLICATION_STATUSES:
        raise HTTPException(status_code=400, detail="Statut de candidature invalide")
    if application.converted_user_id and next_status != "accepted":
        raise HTTPException(status_code=409, detail="Une candidature convertie reste acceptée")
    if next_status == current_status:
        application.status = current_status
        return False
    if next_status not in APPLICATION_STATUS_TRANSITIONS.get(current_status, set()):
        raise HTTPException(
            status_code=409,
            detail=f"Transition de candidature interdite : {current_status} -> {next_status}",
        )
    application.status = next_status
    application.updated_at = utc_now()
    return True


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

    campaign = get_campaign_or_404(db, str(application.campaign_id))
    reviews = db.query(ApplicationReview).filter(ApplicationReview.application_id == application.id).all()
    summary = structured_summary(reviews, campaign.screening_rubric_version or RUBRIC_VERSION)
    if summary["screening_score"] is not None:
        application.final_score = round(summary["screening_score"] / 5, 2)
    elif avg_score is None:
        application.final_score = None
    else:
        application.final_score = round(float(avg_score), 2)

    application.updated_at = utc_now()


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


def notify_application_status(
    db: Session,
    application: Application,
) -> None:
    enqueue_candidate_update(db, application)
    if not application.converted_user_id:
        return

    normalized_status = normalize_application_status(application.status)
    notify_user(
        db,
        user_id=application.converted_user_id,
        title="Statut de candidature mis à jour",
        message=APPLICATION_TRACKING_NEXT_STEPS.get(
            normalized_status,
            "Votre candidature a ete mise a jour.",
        ),
        notification_type="recruitment_status",
        related_type="application",
        related_id=application.id,
        dedupe=False,
        send_email=False,
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
        target_headcount=payload.target_headcount,
        positions=[item.model_dump() for item in payload.positions],
        target_profiles=payload.target_profiles,
        communication_actions=[item.model_dump() for item in payload.communication_actions],
        interview_questions=[item.model_dump() for item in payload.interview_questions],
        application_questions=[q.model_dump() for q in payload.application_questions] if payload.application_questions is not None else None,
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


@router.get("/campaigns/public", response_model=list[RecruitmentCampaignPublicRead])
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

    if payload.target_headcount is not None:
        campaign.target_headcount = payload.target_headcount

    if payload.positions is not None:
        campaign.positions = [item.model_dump() for item in payload.positions]

    if payload.target_profiles is not None:
        campaign.target_profiles = payload.target_profiles

    if payload.communication_actions is not None:
        campaign.communication_actions = [
            item.model_dump() for item in payload.communication_actions
        ]

    if payload.interview_questions is not None:
        campaign.interview_questions = [
            item.model_dump() for item in payload.interview_questions
        ]

    if payload.application_questions is not None:
        campaign.application_questions = [q.model_dump() for q in payload.application_questions]
    if payload.is_active is not None:
        campaign.is_active = payload.is_active

    campaign.updated_at = utc_now()

    db.commit()
    db.refresh(campaign)

    return campaign


@router.delete("/campaigns/{campaign_id}")
def delete_campaign(
    campaign_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    campaign = lock_row(db, RecruitmentCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(status_code=404, detail="Campagne introuvable")

    applications = (
        db.query(Application)
        .filter(Application.campaign_id == campaign.id)
        .order_by(Application.id.asc())
        .with_for_update()
        .all()
    )
    if any(application.converted_user_id for application in applications):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une campagne avec des candidatures converties doit être clôturée, pas supprimée",
        )

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
    return create_application(payload, db)


def create_application(payload, db, attachments=None, created_files=None):
    campaign = get_campaign_or_404(db, str(payload.campaign_id))

    if not campaign_is_open(campaign):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cette campagne de recrutement n'est pas ouverte",
        )
    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()
    gender = payload.gender.strip().lower()
    phone = payload.phone.strip()
    department = payload.department.strip()
    study_level = payload.study_level.strip()
    if not all((first_name, last_name, phone, department, study_level)):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Identité, téléphone et parcours sont obligatoires",
        )
    if gender not in {"homme", "femme", "non_precise"}:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Genre invalide",
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

    answer_snapshot = None
    if payload.questionnaire_version and payload.questionnaire_version != questionnaire_version(campaign.application_questions):
        raise HTTPException(status_code=409, detail="Le questionnaire a changé. Recharge la campagne pour relire tes réponses.")
    if payload.questionnaire_answers is None and campaign.application_questions is not None:
        # Older clients can still answer existing fields; new required questions cannot be skipped.
        for q in effective_questions(campaign.application_questions):
            answer = (getattr(payload, q.get('legacy_field') or '', '') or '').strip()
            if q.get('required') and not answer:
                raise HTTPException(422, "Une réponse obligatoire est manquante : " + q['label'])
    if payload.questionnaire_answers is not None:
        questions = effective_questions(campaign.application_questions)
        answers = payload.questionnaire_answers or {}
        known = {q['id'] for q in questions}
        if set(answers) - known:
            raise HTTPException(status_code=422, detail="Le questionnaire contient une question inconnue")
        answer_snapshot = []
        for q in questions:
            answer = answers.get(q['id'], '').strip()
            if len(answer) > 5000:
                raise HTTPException(status_code=422, detail="Une réponse dépasse 5 000 caractères")
            if q.get('required') and not answer:
                raise HTTPException(status_code=422, detail="Une réponse obligatoire est manquante : " + q['label'])
            answer_snapshot.append({'id': q['id'], 'question': q['label'], 'answer': answer})
            if q.get('legacy_field'):
                setattr(payload, q['legacy_field'], answer or None)

    application = Application(
        campaign_id=payload.campaign_id,
        first_name=first_name,
        last_name=last_name,
        gender=gender,
        email=payload.email,
        phone=phone,
        department=department,
        study_level=study_level,
        class_name=payload.class_name,
        questionnaire_answers=answer_snapshot,
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
    try:
        db.flush()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une candidature existe déjà pour cet email",
        ) from exc
    from app.services.file_storage_service import store_bytes
    for field, (name, data) in (attachments or {}).items():
        stored = store_bytes(db, data=data, original_filename=name, uploaded_by=None,
            storage_scope="recruitment", visibility="private", entity_type="application",
            entity_id=application.id, is_temporary=False)
        if created_files is not None:
            created_files.append(stored)
        setattr(application, field, f"/api/files/{stored.id}/download")
    ensure_tracking_code(db, application)
    notify_recruitment_responsibles(db, application, campaign)
    enqueue_email_delivery(
        db,
        recipient_email=application.email,
        subject=f"EnactSpace - Candidature {campaign.title}",
        text_body=(
            f"Bonjour {application.first_name},\n\n"
            "Votre candidature à Enactus ESP a bien été reçue.\n"
            f"Code de suivi : {application.tracking_code}\n\n"
            "Conservez ce code pour suivre l'avancement de votre candidature."
        ),
        dedupe_key=f"recruitment-submission:{application.id}",
    )
    db.commit()
    db.refresh(application)

    return application_payload(db, None, application)


@router.post("/applications/with-files", response_model=ApplicationRead)
async def submit_application_files(
    payload: str = Form(...), cv: UploadFile | None = File(default=None),
    motivation_letter: UploadFile | None = File(default=None), attachment: UploadFile | None = File(default=None),
    db: Session = Depends(get_db),
):
    if len(payload) > 240000:
        raise HTTPException(413, "Le formulaire dépasse la taille autorisée.")
    try:
        parsed = ApplicationCreate.model_validate_json(payload)
    except ValidationError:
        raise HTTPException(422, "Vérifiez les champs obligatoires et les réponses du formulaire.")
    campaign = get_campaign_or_404(db, str(parsed.campaign_id))
    if not campaign_is_open(campaign):
        raise HTTPException(400, "Cette campagne de recrutement n’est pas ouverte.")
    from app.services.attachment_service import read_attachment
    from app.models.stored_file import StoredFile
    from app.services.file_storage_service import delete_physical_file
    attachments = {}
    for field, file in (("cv_url",cv),("motivation_letter_url",motivation_letter),("attachment_url",attachment)):
        if file is not None:
            attachments[field] = await read_attachment(file, application=True)
    created_files = []
    try:
        return create_application(parsed, db, attachments, created_files)
    except Exception:
        db.rollback()
        for stored in created_files:
            delete_physical_file(stored)
        raise


def build_tracking_code(application: Application | None = None) -> str:
    year = utc_now().year
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


def public_interview_details(application: Application) -> str | None:
    if not application.interview_at:
        return None

    parts = [f"Entretien prévu le {application.interview_at:%d/%m/%Y à %H:%M}"]
    if application.interview_location:
        parts.append(f"Lieu: {application.interview_location}")
    if application.interview_link:
        parts.append(f"Lien: {application.interview_link}")
    return " · ".join(parts)


def profile_type_from_application(
    application: Application,
    requested_profile_type: str | None,
) -> str:
    if requested_profile_type and requested_profile_type.strip():
        profile_type = requested_profile_type.strip().lower()
        if profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Type de profil membre invalide",
            )
        return profile_type

    gender = (application.gender or "").strip().lower()
    if gender.startswith("f") or "femme" in gender:
        return "enactrice"
    return "enacteur"


def ensure_user_role(db: Session, user: User, role_name: str) -> None:
    role = db.query(Role).filter(Role.name == role_name).first()
    if not role:
        role = Role(name=role_name)
        db.add(role)
        db.flush()

    exists = (
        db.query(UserRole.id)
        .filter(UserRole.user_id == user.id, UserRole.role_id == role.id)
        .first()
    )
    if not exists:
        db.add(UserRole(user_id=user.id, role_id=role.id))


def ensure_pole_membership(db: Session, user: User, pole_id) -> None:
    pole = db.query(Pole.id).filter(Pole.id == pole_id).first()
    if not pole:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pôle introuvable pour la conversion",
        )

    membership = (
        db.query(PoleMember)
        .filter(PoleMember.pole_id == pole_id, PoleMember.user_id == user.id)
        .first()
    )
    if membership:
        membership.position = "membre"
        membership.left_at = None
        membership.is_active = True
    else:
        db.add(PoleMember(pole_id=pole_id, user_id=user.id, position="membre"))


def ensure_project_membership(db: Session, user: User, project_id) -> None:
    project = db.query(Project.id).filter(Project.id == project_id).first()
    if not project:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Projet introuvable pour la conversion",
        )

    membership = (
        db.query(ProjectMember)
        .filter(ProjectMember.project_id == project_id, ProjectMember.user_id == user.id)
        .first()
    )
    if membership:
        membership.position = "membre"
        membership.left_at = None
        membership.is_active = True
    else:
        db.add(ProjectMember(project_id=project_id, user_id=user.id, position="membre"))


def anonymous_code(application: Application) -> str:
    return f"Candidat #{str(application.id).replace('-', '')[:6].upper()}"


def application_payload(
    db: Session,
    current_user: User | None,
    application: Application,
    *,
    anonymized: bool = False,
    include_history: bool = False,
    prefetched_campaigns: dict | None = None,
    prefetched_reviews: dict | None = None,
) -> dict:
    data = ApplicationRead.model_validate(application).model_dump()
    if current_user is not None:
        campaign = (prefetched_campaigns.get(application.campaign_id) if prefetched_campaigns is not None
                    else get_campaign_or_404(db, str(application.campaign_id)))
        version = campaign.screening_rubric_version or RUBRIC_VERSION
        reviews = (prefetched_reviews.get(application.id, []) if prefetched_reviews is not None
                   else db.query(ApplicationReview).filter(ApplicationReview.application_id == application.id).all())
        data.update(structured_summary(reviews, version))
        data["screening_rubric"] = rubric_payload(version)
        own_review = next((review for review in reviews if review.reviewer_id == current_user.id), None)
        data["my_review"] = ApplicationReviewRead.model_validate(own_review).model_dump() if own_review else None
    if include_history and current_user is not None:
        data["history"] = application_history(db, application)
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
                "questionnaire_answers": None,
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
            public_interview_details(application)
            or (
                "Les détails de l'entretien seront communiqués dès validation interne."
                if normalized_status == "interview_scheduled"
                else None
            )
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
    preferred_pole: str | None = Query(default=None),
    project_interest: str | None = Query(default=None),
    department: str | None = Query(default=None),
    class_name: str | None = Query(default=None),
    gender: str | None = Query(default=None),
    submitted_from: date | None = Query(default=None),
    submitted_to: date | None = Query(default=None),
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

    text_filters = {
        Application.preferred_pole: preferred_pole,
        Application.project_interest: project_interest,
        Application.department: department,
        Application.class_name: class_name,
        Application.gender: gender,
    }
    for column, value in text_filters.items():
        if value and value.strip():
            query = query.filter(column.ilike(f"%{value.strip()}%"))

    if submitted_from:
        query = query.filter(Application.created_at >= submitted_from)

    if submitted_to:
        query = query.filter(Application.created_at < submitted_to + timedelta(days=1))

    applications = query.order_by(Application.created_at.desc()).all()
    campaigns = {row.id: row for row in db.query(RecruitmentCampaign).filter(
        RecruitmentCampaign.id.in_({row.campaign_id for row in applications})).all()} if applications else {}
    reviews_by_application = {}
    if applications:
        for review in db.query(ApplicationReview).filter(ApplicationReview.application_id.in_(
                [row.id for row in applications])).all():
            reviews_by_application.setdefault(review.application_id, []).append(review)
    return [
        application_payload(
            db,
            current_user,
            application,
            anonymized=anonymized,
            prefetched_campaigns=campaigns,
            prefetched_reviews=reviews_by_application,
        )
        for application in applications
    ]


@router.get("/applications/export.csv")
def export_applications_csv(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    del current_user
    output = StringIO()
    writer = csv.writer(output)
    writer.writerow(
        [
            "Nom",
            "Prénom",
            "Genre",
            "Email",
            "Téléphone",
            "Classe",
            "Département",
            "Pôle souhaité",
            "Projet d'intérêt",
            "Statut",
            "Score",
            "Avis",
            "Date soumission",
            "Date entretien",
            "Décision",
        ]
    )

    applications = db.query(Application).order_by(Application.created_at.desc()).all()
    for application in applications:
        latest_review = (
            db.query(ApplicationReview)
            .filter(ApplicationReview.application_id == application.id)
            .order_by(ApplicationReview.updated_at.desc())
            .first()
        )
        status_value = normalize_application_status(application.status)
        writer.writerow(
            [
                application.last_name,
                application.first_name,
                application.gender,
                application.email,
                application.phone,
                application.class_name,
                application.department,
                application.preferred_pole,
                application.project_interest,
                status_value,
                application.final_score,
                latest_review.recommendation if latest_review else "",
                application.created_at.isoformat() if application.created_at else "",
                application.interview_at.isoformat() if application.interview_at else "",
                APPLICATION_FINAL_RESULTS.get(status_value, ""),
            ]
        )

    output.seek(0)
    headers = {"Content-Disposition": "attachment; filename=recrutement.csv"}
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv; charset=utf-8",
        headers=headers,
    )


@router.get("/applications/{application_id}", response_model=ApplicationRead)
def get_application(
    application_id: str,
    anonymized: bool = Query(default=False),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = get_application_or_404(db, application_id)
    return application_payload(db, current_user, application, anonymized=anonymized, include_history=True)


@router.post("/applications/{application_id}/interview", response_model=ApplicationRead)
def schedule_application_interview(
    application_id: str,
    payload: ApplicationInterviewSchedule,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")

    old_interview = {
        name: getattr(application, name).isoformat() if isinstance(getattr(application, name), datetime) else getattr(application, name)
        for name in ("interview_at", "interview_location", "interview_link", "interview_jury", "interview_note")
    }
    old_status = normalize_application_status(application.status)
    changed = apply_application_status(application, "interview_scheduled")

    application.interview_at = to_naive_utc(payload.interview_at)
    application.interview_location = payload.interview_location
    application.interview_link = payload.interview_link
    application.interview_jury = payload.interview_jury
    application.interview_note = payload.interview_note
    application.updated_at = utc_now()
    if changed:
        notify_application_status(db, application)
        create_audit_log(
            db=db,
            action="changement_statut_candidature",
            user_id=current_user.id,
            entity_type="application",
            entity_id=application.id,
            old_value={"status": old_status},
            new_value={"status": application.status, "interview_scheduled": True, "interview_at": application.interview_at.isoformat() + "Z"},
            ip_address=get_client_ip(request),
        )

    elif old_interview != {
        name: getattr(application, name).isoformat() if isinstance(getattr(application, name), datetime) else getattr(application, name)
        for name in old_interview
    }:
        public_interview_changed = any(
            old_interview[name] != (getattr(application, name).isoformat()
                if isinstance(getattr(application, name), datetime) else getattr(application, name))
            for name in ("interview_at", "interview_location", "interview_link")
        )
        if public_interview_changed:
            notify_application_status(db, application)
        create_audit_log(
            db=db, action="programmation_entretien_candidature", user_id=current_user.id,
            entity_type="application", entity_id=application.id,
            old_value={"interview_at": old_interview["interview_at"]},
            new_value={"interview_at": application.interview_at.isoformat() + "Z"},
            ip_address=get_client_ip(request),
        )

    db.commit()
    db.refresh(application)

    return application_payload(db, current_user, application)


@router.patch("/applications/{application_id}", response_model=ApplicationRead)
def update_application(
    application_id: str,
    payload: ApplicationUpdate,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    if application.converted_user_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une candidature convertie est immuable",
        )
    old_status = normalize_application_status(application.status)
    status_changed = False

    if payload.status is not None:
        status_changed = apply_application_status(application, payload.status)

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

    application.updated_at = utc_now()
    if status_changed:
        notify_application_status(db, application)
        create_audit_log(
            db=db,
            action="changement_statut_candidature",
            user_id=current_user.id,
            entity_type="application",
            entity_id=application.id,
            old_value={"status": old_status},
            new_value={"status": application.status},
            ip_address=get_client_ip(request),
        )

    db.commit()
    db.refresh(application)

    return application_payload(db, current_user, application)


@router.post("/applications/{application_id}/status", response_model=ApplicationRead)
def change_application_status(
    application_id: str,
    payload: ApplicationStatusChange,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    old_status = normalize_application_status(application.status)
    changed = apply_application_status(application, payload.status)
    if changed:
        notify_application_status(db, application)
        create_audit_log(
            db=db,
            action="changement_statut_candidature",
            user_id=current_user.id,
            entity_type="application",
            entity_id=application.id,
            old_value={"status": old_status},
            new_value={"status": application.status},
            ip_address=get_client_ip(request),
        )

    db.commit()
    db.refresh(application)

    return application_payload(db, current_user, application)


@router.delete("/applications/{application_id}")
def delete_application(
    application_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_recruitment_access),
):
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")

    if application.converted_user_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Une candidature convertie ne peut pas être supprimée",
        )

    db.delete(application)
    db.commit()

    return {
        "ok": True,
        "message": "Candidature supprimée",
    }

def lock_review_application(db: Session, application_id: str) -> Application:
    campaign_id = db.query(Application.campaign_id).filter(Application.id == application_id).scalar()
    if campaign_id is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    lock_row(db, RecruitmentCampaign, campaign_id)
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    return application


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

    application = lock_review_application(db, str(payload.application_id))
    snapshot = None
    score = payload.score
    if payload.criteria_assessment is not None:
        campaign = get_campaign_or_404(db, str(application.campaign_id))
        version = campaign.screening_rubric_version or RUBRIC_VERSION
        try:
            snapshot, score = assess_ratings(payload.criteria_assessment.get("ratings"),
                                             payload.criteria_assessment.get("rubric_version"))
            if snapshot["rubric_version"] != version:
                raise ValueError("La grille de cette campagne a changé. Recharge le dossier.")
        except (ValueError, AttributeError) as error:
            raise HTTPException(status_code=422, detail=str(error))
        campaign.screening_rubric_version = version

    review = db.query(ApplicationReview).filter(
        ApplicationReview.application_id == payload.application_id,
        ApplicationReview.reviewer_id == current_user.id,
    ).first()

    if review:
        if review.criteria_assessment is not None and snapshot is None:
            raise HTTPException(status_code=409, detail="Utilise la grille pour modifier cette évaluation.")
        review.score = score
        review.criteria_assessment = snapshot
        review.comment = payload.comment
        review.recommendation = payload.recommendation
        review.updated_at = utc_now()
    else:
        review = ApplicationReview(
            application_id=payload.application_id,
            reviewer_id=current_user.id,
            score=score,
            criteria_assessment=snapshot,
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

    rows = db.query(ApplicationReview, User).outerjoin(User, User.id == ApplicationReview.reviewer_id).filter(
        ApplicationReview.application_id == application_id
    ).order_by(ApplicationReview.created_at.desc()).all()
    return [dict(ApplicationReviewRead.model_validate(review).model_dump(), reviewer_name=member_name(actor)) for review, actor in rows]


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

    application = lock_review_application(db, str(review.application_id))
    db.refresh(review)
    if payload.recommendation is not None:
        if payload.recommendation not in VALID_RECOMMENDATIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Recommandation invalide",
            )
        review.recommendation = payload.recommendation

    if payload.criteria_assessment is not None:
        application = get_application_or_404(db, str(review.application_id))
        campaign = get_campaign_or_404(db, str(application.campaign_id))
        try:
            snapshot, computed = assess_ratings(payload.criteria_assessment.get("ratings"), payload.criteria_assessment.get("rubric_version"))
            if snapshot["rubric_version"] != (campaign.screening_rubric_version or RUBRIC_VERSION):
                raise ValueError("La grille de cette campagne a changé. Recharge le dossier.")
        except (ValueError, AttributeError) as error:
            raise HTTPException(status_code=422, detail=str(error))
        review.criteria_assessment = snapshot
        review.score = computed
        campaign.screening_rubric_version = snapshot["rubric_version"]
    elif payload.score is not None:
        if review.criteria_assessment is not None:
            raise HTTPException(status_code=409, detail="Utilise la grille pour modifier cette évaluation.")
        if payload.score < 0 or payload.score > 20:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Le score doit être compris entre 0 et 20",
            )
        review.score = payload.score

    if payload.comment is not None:
        review.comment = payload.comment

    review.updated_at = utc_now()

    db.flush()
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

    application = lock_review_application(db, str(review.application_id))

    db.delete(review)
    db.flush()

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
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_sg_or_admin),
):
    campaign_id = db.query(Application.campaign_id).filter(
        Application.id == application_id
    ).scalar()
    if campaign_id is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")
    campaign = lock_row(db, RecruitmentCampaign, campaign_id)
    if campaign is None:
        raise HTTPException(status_code=404, detail="Campagne introuvable")
    application = lock_row(db, Application, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="Candidature introuvable")

    if application.status != "accepted":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La candidature doit être acceptée avant création du compte",
        )
    if payload.password is not None and len(payload.password.strip()) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le mot de passe initial doit contenir au moins 8 caractères",
        )
    requested_profile_type = profile_type_from_application(
        application,
        payload.profile_type,
    )

    if application.converted_user_id:
        return {
            "ok": True,
            "message": "Un compte existe déjà pour cette candidature",
            "user_id": str(application.converted_user_id),
        }

    existing_user = (
        db.query(User)
        .filter(func.lower(User.email) == application.email.lower())
        .with_for_update()
        .first()
    )

    if existing_user:
        if (
            existing_user.status != "active"
            or not existing_user.is_active
            or existing_user.profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Un compte existe avec un cycle de vie incompatible; "
                    "un administrateur doit le résoudre avant la conversion"
                ),
            )
        application.converted_user_id = existing_user.id
        ensure_user_role(db, existing_user, BASE_ACTIVE_ROLE)
        existing_user.gender = existing_user.gender or application.gender
        existing_user.department = existing_user.department or application.department
        existing_user.study_level = existing_user.study_level or application.study_level
        existing_user.promotion = existing_user.promotion or application.class_name
        application.updated_at = utc_now()
        from app.services.first_access import issue_activation
        issue_activation(db, existing_user)
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
        create_audit_log(
            db=db,
            action="conversion_candidature",
            user_id=current_user.id,
            entity_type="application",
            entity_id=application.id,
            old_value={"converted_user_id": None},
            new_value={"converted_user_id": str(existing_user.id), "existing_user": True},
            ip_address=get_client_ip(request),
        )
        db.commit()

        return {
            "ok": True,
            "message": "Un compte existait déjà avec cet email",
            "user_id": str(existing_user.id),
            "profile_type": existing_user.profile_type,
            "core_pole_id": None,
            "project_id": None,
            "onboarding": member_onboarding_payload(),
        }

    user = User(
        first_name=application.first_name,
        last_name=application.last_name,
        email=application.email.strip().lower(),
        phone=application.phone,
        gender=application.gender,
        profile_type=requested_profile_type,
        password_hash=hash_password(secrets.token_urlsafe(32)),
        credential_setup_required=True,
        onboarding_required=True,
        department=application.department,
        study_level=application.study_level,
        promotion=application.class_name,
        status="active",
        email_verified=True,
        is_active=True,
    )

    db.add(user)
    try:
        db.flush()
    except IntegrityError as exc:
        db.rollback()
        campaign = lock_row(db, RecruitmentCampaign, campaign_id)
        application = lock_row(db, Application, application_id)
        if campaign is None or application is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La candidature n'est plus disponible pour conversion",
            ) from exc
        if application.converted_user_id:
            return {
                "ok": True,
                "message": "Un compte existe déjà pour cette candidature",
                "user_id": str(application.converted_user_id),
            }
        existing_user = (
            db.query(User)
            .filter(func.lower(User.email) == application.email.lower())
            .with_for_update()
            .first()
        )
        if existing_user is None or (
            existing_user.status != "active"
            or not existing_user.is_active
            or existing_user.profile_type not in {BASE_ACTIVE_ROLE, "enactrice"}
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Un compte existe déjà avec cet email",
            ) from exc
        application.converted_user_id = existing_user.id
        ensure_user_role(db, existing_user, BASE_ACTIVE_ROLE)
        application.updated_at = utc_now()
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
        create_audit_log(
            db=db,
            action="conversion_candidature",
            user_id=current_user.id,
            entity_type="application",
            entity_id=application.id,
            old_value={"converted_user_id": None},
            new_value={"converted_user_id": str(existing_user.id), "existing_user": True},
            ip_address=get_client_ip(request),
        )
        db.commit()
        return {
            "ok": True,
            "message": "Un compte existait déjà avec cet email",
            "user_id": str(existing_user.id),
            "profile_type": existing_user.profile_type,
            "core_pole_id": None,
            "project_id": None,
            "onboarding": member_onboarding_payload(),
        }
    ensure_user_role(db, user, BASE_ACTIVE_ROLE)
    if payload.core_pole_id:
        ensure_pole_membership(db, user, payload.core_pole_id)
    for pole_id in payload.support_pole_ids:
        ensure_pole_membership(db, user, pole_id)
    if payload.project_id:
        ensure_project_membership(db, user, payload.project_id)

    from app.services.first_access import issue_activation
    issue_activation(db, user)
    application.converted_user_id = user.id
    application.updated_at = utc_now()
    notify_user(
        db,
        user_id=user.id,
        title="Votre profil EnactSpace est créé",
        message="Activez votre accès depuis Première connexion, puis complétez votre profil.",
        notification_type="recruitment_update",
        related_type="application",
        related_id=application.id,
        dedupe=True,
    )

    create_audit_log(
        db=db,
        action="conversion_candidature",
        user_id=current_user.id,
        entity_type="application",
        entity_id=application.id,
        old_value={"converted_user_id": None},
        new_value={"converted_user_id": str(user.id), "existing_user": False},
        ip_address=get_client_ip(request),
    )

    db.commit()
    db.refresh(user)

    return {
        "ok": True,
        "message": "Compte membre créé avec succès.",
        "user_id": str(user.id),
        "profile_type": user.profile_type,
        "core_pole_id": str(payload.core_pole_id) if payload.core_pole_id else None,
        "project_id": str(payload.project_id) if payload.project_id else None,
        "onboarding": member_onboarding_payload(),
    }
