"""Individual activation and resumable first login, independent of devices."""
import hashlib,hmac,secrets
from datetime import timedelta
from email_validator import validate_email,EmailNotValidError
from fastapi import HTTPException
from sqlalchemy import func,or_
from app.core.config import settings
from app.core.time import utc_now
from app.core.security import hash_password
from app.models.user import User
from app.models.role import Role,UserRole
from app.core.roles import ADMIN_ROLE
from app.models.account import AuthSession
from app.models.academic import UserAcademicHistory
from app.models.season import Season
from app.services.annual_transition import lock_year_transition
from app.services.academic_profile import progression_for
from app.models.first_access import ActivationChallenge
from app.services.email_delivery_service import enqueue_email_delivery
from app.services.email_templates import APP_URL
from app.services.session_service import revoke_user_sessions

GENERIC_MESSAGE="Si votre compte est prêt et son adresse renseignée, un code d'activation vous sera envoyé. Sinon, contactez la SG."
ONBOARDING_PATHS={"/api/users/me","/api/first-access/me","/api/first-access/me/complete",
                  "/api/first-access/catalog","/api/auth/logout","/api/auth/logout-all",
                  "/api/legal/status/me","/api/legal/acceptances",
                  "/api/users/me/preferences","/api/users/me/data-export",
                  "/api/users/me/deletion-request","/api/users/me/deletion-request/cancel",
                  "/api/support/tickets","/api/feedback"}

def contact_is_usable(email):
    try:
        validate_email(email,check_deliverability=False)
    except (EmailNotValidError,TypeError):
        return False
    domain=email.rsplit("@",1)[-1].lower()
    return not domain.endswith((".local",".invalid",".test")) and domain not in {"localhost","enactspace.local"}

def activation_eligible(user):
    return bool(user and user.is_active and (
        (user.status=="active" and user.profile_type in {"enacteur","enactrice"})
        or (user.status=="alumni" and user.profile_type=="alumni")))

def find_account(db,identifier):
    value=identifier.strip().lower()
    return db.query(User).filter(or_(func.lower(User.email)==value,func.lower(User.username)==value)).populate_existing().with_for_update().first()

def code_digest(user_id,email,code):
    return hmac.new(settings.signing_secret.encode(),f"activate:{user_id}:{email}:{code}".encode(),hashlib.sha256).hexdigest()

def already_signed_in(db,user):
    return user.onboarding_completed_at is not None or db.query(AuthSession.id).filter(AuthSession.user_id==user.id).first() is not None

def administrator(db,user):
    return user is not None and db.query(Role.id).join(UserRole,UserRole.role_id==Role.id).filter(
        UserRole.user_id==user.id,Role.name==ADMIN_ROLE).first() is not None

def issue_activation(db,user):
    """Caller holds the user lock. No commit and no SMTP send here."""
    if not activation_eligible(user) or not user.credential_setup_required or administrator(db,user) or not contact_is_usable(user.email):
        return False
    if user.credential_activated_at is not None or (already_signed_in(db,user) and not user.credential_setup_required):
        return False
    challenge=db.query(ActivationChallenge).filter_by(user_id=user.id).populate_existing().with_for_update().first()
    now=utc_now()
    if challenge and challenge.created_at+timedelta(seconds=60)>now:
        return False
    code=f"{secrets.randbelow(100_000_000):08d}"
    values=dict(code_hash=code_digest(user.id,user.email,code),email_snapshot=user.email,
                failed_attempts=0,expires_at=now+timedelta(minutes=30),created_at=now)
    if challenge is None:
        challenge=ActivationChallenge(user_id=user.id,**values);db.add(challenge)
    else:
        for field,value in values.items():setattr(challenge,field,value)
    enqueue_email_delivery(db,recipient_email=user.email,user_id=user.id,
        subject="Bienvenue dans EnactSpace — activez votre accès",
        text_body=(f"Bonjour {user.first_name},\n\nBienvenue dans l'espace de Enactus ESP !\n"
            f"Votre identifiant : {user.username}\nVotre code personnel : {code}\n"
            "Ce code expire dans 30 minutes et ne peut être utilisé qu'une fois. "
            f"Ouvrez {APP_URL}/activate, puis créez votre propre mot de passe.\n\n"
            "Vous pourrez ensuite compléter votre profil et découvrir votre espace. "
            "Ne partagez pas ce code ; les responsables n'ont pas besoin de connaître votre mot de passe."),
        dedupe_key=f"activation:{challenge.id or user.id}:{now.isoformat()}")
    return True

def confirm_activation(db,payload):
    user=find_account(db,payload.identifier)
    challenge=(db.query(ActivationChallenge).filter_by(user_id=user.id).populate_existing().with_for_update().first()) if user else None
    invalid=HTTPException(400,"Code d'activation invalide ou expiré.")
    if not activation_eligible(user) or not user.credential_setup_required or administrator(db,user) or challenge is None or user.credential_activated_at is not None:
        raise invalid
    now=utc_now()
    if challenge.email_snapshot!=user.email or challenge.expires_at<=now or challenge.failed_attempts>=5:
        db.delete(challenge);db.commit();raise invalid
    expected=code_digest(user.id,challenge.email_snapshot,payload.code)
    if not hmac.compare_digest(expected,challenge.code_hash):
        challenge.failed_attempts+=1
        if challenge.failed_attempts>=5:db.delete(challenge)
        db.commit();raise invalid
    user.password_hash=hash_password(payload.new_password)
    user.email_verified=True
    user.credential_setup_required=False
    user.credential_activated_at=now
    user.onboarding_required=user.onboarding_completed_at is None
    user.updated_at=now
    revoke_user_sessions(db,user.id)
    db.delete(challenge)
    enqueue_email_delivery(db,recipient_email=user.email,user_id=user.id,
        subject="Votre accès EnactSpace est prêt",
        text_body=f"Bonjour {user.first_name},\n\nVotre mot de passe a été créé. Connectez-vous avec votre email ou {user.username} pour compléter votre profil.\nSi cette activation ne vient pas de vous, contactez immédiatement la SG.",
        dedupe_key=f"activation-complete:{user.id}:{now.isoformat()}")
    return user

def onboarding_pending(user):
    return bool(user.onboarding_required and user.onboarding_completed_at is None)

def check_session_access(user,path):
    if user.credential_setup_required:
        raise HTTPException(403,"Activez votre compte avec Première connexion avant de poursuivre.")
    own_help_detail=False
    for prefix in ("/api/support/tickets/","/api/feedback/"):
        if path.startswith(prefix):
            parts=path[len(prefix):].split("/")
            try:
                from uuid import UUID
                UUID(parts[0])
                own_help_detail=len(parts)==1 or (prefix=="/api/support/tickets/" and parts[1:]==["messages"])
            except (ValueError,TypeError,AttributeError):pass
    if onboarding_pending(user) and path not in ONBOARDING_PATHS and not own_help_detail:
        raise HTTPException(403,detail={"code":"onboarding_required","message":"Complétez votre profil pour accéder à votre espace."})


def academic_onboarding_context(db,user):
    if user.status=="alumni":
        return None,None
    years=db.query(Season).filter(Season.is_current.is_(True),Season.archived.is_(False)).all()
    if len(years)>1:
        raise HTTPException(409,"L'année courante doit être clarifiée par la SG.")
    year=years[0] if years else None
    history=db.query(UserAcademicHistory).filter_by(user_id=user.id,season_id=year.id).first() if year else None
    return year,history

def confirm_initial_academic_profile(db,user,payload):
    """Reuse the annual confirmation and its lock; never rewrite a past record."""
    lock_year_transition(db)
    year,history=academic_onboarding_context(db,user)
    if payload.academic_year_id!=(year.id if year else None):
        raise HTTPException(409,"L'année courante a changé. Actualisez vos informations avant de poursuivre.")
    if year is None:
        return
    if history is not None:
        if (payload.department,payload.cursus,payload.study_level)!=(history.department,history.cursus,history.study_level):
            raise HTTPException(422,"Votre parcours a déjà été confirmé pour cette année. Actualisez les informations ; la SG peut vous accompagner pour une correction.")
    else:
        previous=(db.query(UserAcademicHistory).join(Season,Season.id==UserAcademicHistory.season_id)
                  .filter(UserAcademicHistory.user_id==user.id).order_by(Season.start_date.desc()).first())
        action="initial"
        if previous:
            next_level=progression_for(previous.cursus,previous.study_level).suggested_next_level
            if payload.cursus==previous.cursus and payload.study_level==previous.study_level:action="repeat"
            elif payload.cursus==previous.cursus and payload.study_level==next_level:action="progress"
            else:action="change"
        history=UserAcademicHistory(user_id=user.id,season_id=year.id,department=payload.department,
            cursus=payload.cursus,study_level=payload.study_level,specialty=payload.specialty,
            promotion=payload.promotion,progression_action=action,confirmed_at=utc_now())
        db.add(history)
    user.academic_confirmed_season_id=year.id
    user.academic_confirmed_at=history.confirmed_at
