import secrets
from uuid import UUID
from fastapi import APIRouter,Depends,HTTPException,Request
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.api.deps import get_current_active_validated_user,require_sg_or_admin,get_user_role_names
from app.api.routes.users import lock_account_management
from app.core.roles import SECRETARIAT_ROLES,ADMIN_ROLE
from app.core.time import utc_now
from app.core.security import hash_password
from app.services.session_service import revoke_user_sessions
from app.services.email_delivery_service import enqueue_email_delivery
from app.models.user import User
from app.models.first_access import ActivationChallenge
from app.models.alumni import AlumniProfile
from app.models.account import AuthSession
from app.schemas.first_access import ActivationRequest,ActivationConfirm,FirstAccessComplete,FirstAccessContact,FirstAccessRecovery
from app.services.first_access import (
    GENERIC_MESSAGE,find_account,issue_activation,confirm_activation,activation_eligible,
    contact_is_usable,already_signed_in,onboarding_pending,academic_onboarding_context,confirm_initial_academic_profile,
)
from app.services.request_rate_limit import protect_public_request
from app.services.operational_integrity import lock_user
from app.services.alumni_profiles import ensure_alumni_profile
from app.services.academic_profile import ACADEMIC_DEPARTMENTS,ACADEMIC_LEVELS,validate_academic_path
from app.services.audit_service import create_audit_log

public_router=APIRouter(prefix="/auth/activation",tags=["Première connexion"],dependencies=[Depends(protect_public_request)])
router=APIRouter(prefix="/first-access",tags=["Première connexion"])

@public_router.post("/request")
def request_activation(payload:ActivationRequest,db:Session=Depends(get_db)):
    user=find_account(db,payload.identifier)
    if user is not None:issue_activation(db,user)
    db.commit()
    return {"message":GENERIC_MESSAGE}

@public_router.post("/confirm")
def activate(payload:ActivationConfirm,db:Session=Depends(get_db)):
    user=confirm_activation(db,payload)
    create_audit_log(db,"account_activated",user.id,"user",user.id)
    db.commit()
    return {"message":"Votre mot de passe est prêt. Connectez-vous pour compléter votre profil."}

@router.get("/catalog")
def catalog(user:User=Depends(get_current_active_validated_user)):
    return {"departments":{name:{course:list(ACADEMIC_LEVELS[course]) for course in sorted(courses)}
                           for name,courses in ACADEMIC_DEPARTMENTS.items()}}

@router.get("/me")
def read_first_access(db:Session=Depends(get_db),user:User=Depends(get_current_active_validated_user)):
    profile=db.query(AlumniProfile).filter_by(user_id=user.id).first() if user.status=="alumni" else None
    year,history=academic_onboarding_context(db,user)
    return {"pending":onboarding_pending(user),"profile_type":user.profile_type,"email":user.email,"username":user.username,
            "first_name":user.first_name,"last_name":user.last_name,"phone":user.phone,"gender":user.gender,
            "department":history.department if history else user.department,"cursus":history.cursus if history else user.cursus,"study_level":history.study_level if history else user.study_level,"specialty":user.specialty,
            "promotion":user.promotion,"enactus_join_year":user.enactus_join_year,"bio":user.bio,
            "graduation_year":profile.graduation_year if profile else None,"completed_at":user.onboarding_completed_at,
            "academic_year_id":str(year.id) if year else None,"academic_year_name":year.name if year else None,
            "academic_year_confirmed":history is not None,"contact_ready":contact_is_usable(user.email)}

@router.post("/me/complete")
def complete_first_access(payload:FirstAccessComplete,db:Session=Depends(get_db),
                          user:User=Depends(get_current_active_validated_user)):
    user=lock_user(db,user.id)
    if not activation_eligible(user) or not user.email_verified or user.credential_setup_required:
        raise HTTPException(403,"Compte indisponible.")
    if not contact_is_usable(user.email):raise HTTPException(409,"Votre adresse email doit être confirmée avec la SG avant de poursuivre.")
    if not onboarding_pending(user):
        return {"completed":True,"completed_at":user.onboarding_completed_at}
    if payload.department not in ACADEMIC_DEPARTMENTS:
        raise HTTPException(422,"Choisissez votre département ESP.")
    if user.status=="alumni":
        if payload.graduation_year is None:
            raise HTTPException(422,"Renseignez votre année de fin d'études.")
        profile=ensure_alumni_profile(db,user)
        profile.graduation_year=payload.graduation_year
        profile.enactus_join_year=payload.enactus_join_year
    else:
        try:validate_academic_path(payload.department,payload.cursus or "",payload.study_level or "")
        except ValueError as exc:raise HTTPException(422,str(exc)) from exc
        confirm_initial_academic_profile(db,user,payload)
    excluded={"graduation_year","academic_year_id"}
    if user.status=="alumni":excluded.update({"cursus","study_level"})
    for field,value in payload.model_dump(exclude=excluded).items():
        setattr(user,field,value)
    if user.status=='active':user.profile_type='enactrice' if payload.gender=='femme' else 'enacteur'
    user.onboarding_completed_at=utc_now()
    user.onboarding_required=False
    user.updated_at=utc_now()
    create_audit_log(db,"first_access_completed",user.id,"user",user.id)
    db.commit()
    return {"completed":True,"completed_at":user.onboarding_completed_at}

@router.get("/members")
def activation_inventory(db:Session=Depends(get_db),actor:User=Depends(require_sg_or_admin)):
    actor,_=lock_account_management(db,actor.id,allowed_roles=SECRETARIAT_ROLES)
    actor_roles=get_user_role_names(db,actor.id)
    signed_ids={row[0] for row in db.query(AuthSession.user_id).distinct().all()}
    rows=[]
    for user in db.query(User).order_by(User.last_name,User.first_name).all():
        has_signed=user.id in signed_ids or user.credential_activated_at is not None or user.onboarding_completed_at is not None
        state=("contact_missing" if not contact_is_usable(user.email) else "not_ready" if not activation_eligible(user)
               else "ready" if user.credential_setup_required else "completed" if user.onboarding_completed_at
               else "profile_pending" if has_signed else "ready")
        rows.append({"id":str(user.id),"display_name":f"{user.first_name} {user.last_name}","email":user.email,
                     "username":user.username,"phone":user.phone,"status":user.status,"state":state,
                     "can_invite":activation_eligible(user) and contact_is_usable(user.email) and not has_signed
                                  and ADMIN_ROLE not in get_user_role_names(db,user.id),
                     "can_prepare_contact":not has_signed and ADMIN_ROLE not in get_user_role_names(db,user.id),
                     "can_prepare_recovery":ADMIN_ROLE in actor_roles and has_signed and activation_eligible(user)
                                  and ADMIN_ROLE not in get_user_role_names(db,user.id)})
    return rows

@router.patch("/members/{user_id}/contact")
def prepare_contact(user_id:UUID,payload:FirstAccessContact,db:Session=Depends(get_db),
                    actor:User=Depends(require_sg_or_admin)):
    actor,user=lock_account_management(db,actor.id,user_id,allowed_roles=SECRETARIAT_ROLES)
    normalized=str(payload.email).strip().lower()
    if not contact_is_usable(normalized):raise HTTPException(422,"Renseignez une adresse email utilisable.")
    if ADMIN_ROLE in get_user_role_names(db,user.id):raise HTTPException(409,"Le compte administrateur utilise le parcours de récupération sécurisé.")
    if normalized!=user.email.lower() and (already_signed_in(db,user) or user.credential_activated_at):
        raise HTTPException(409,"Ce compte a déjà été utilisé. Sa récupération nécessite une vérification individuelle.")
    old_email=user.email
    changed_email=normalized!=old_email.lower()
    if changed_email:user.email=normalized
    if payload.phone is not None:user.phone=payload.phone.strip() or None
    if changed_email:
        user.email_verified=False
        user.credential_setup_required=True
        with db.no_autoflush:
            db.query(ActivationChallenge).filter_by(user_id=user.id).delete(synchronize_session=False)
    create_audit_log(db,"first_access_contact_prepared",actor.id,"user",user.id,
                     old_value={"email":old_email},new_value={"email":user.email})
    try:db.commit()
    except IntegrityError as exc:
        db.rollback();raise HTTPException(409,"Cette adresse est déjà liée à un compte.") from exc
    return {"message":"Contact enregistré. L'adresse sera vérifiée lors de l'activation."}

@router.post("/members/{user_id}/invite")
def invite_member(user_id:UUID,db:Session=Depends(get_db),actor:User=Depends(require_sg_or_admin)):
    actor,user=lock_account_management(db,actor.id,user_id,allowed_roles=SECRETARIAT_ROLES)
    if ADMIN_ROLE in get_user_role_names(db,user.id) or already_signed_in(db,user) or user.credential_activated_at:
        raise HTTPException(409,"Ce compte a déjà son parcours d'accès. Utilisez la récupération de mot de passe si nécessaire.")
    if not activation_eligible(user) or not contact_is_usable(user.email):
        raise HTTPException(409,"Validez le compte et renseignez son adresse email avant de l'inviter.")
    user.credential_setup_required=True;user.onboarding_required=True
    queued=issue_activation(db,user)
    create_audit_log(db,"first_access_invitation",actor.id,"user",user.id,new_value={"queued":queued})
    db.commit()
    return {"message":"Invitation préparée." if queued else "Un code vient déjà d'être préparé. Patientez une minute avant de le renouveler.","queued":queued}


@router.post("/members/{user_id}/recover-contact")
def recover_contact(user_id:UUID,payload:FirstAccessRecovery,db:Session=Depends(get_db),
                    actor:User=Depends(require_sg_or_admin)):
    # Recovery of an already-used account is deliberately narrower than contact preparation.
    actor,user=lock_account_management(db,actor.id,user_id,allowed_roles={ADMIN_ROLE})
    if ADMIN_ROLE in get_user_role_names(db,user.id):
        raise HTTPException(409,"Le compte administrateur utilise son parcours de récupération sécurisé.")
    if not activation_eligible(user) or not (already_signed_in(db,user) or user.credential_activated_at):
        raise HTTPException(409,"Préparez le contact et l'invitation de ce compte avant sa première utilisation.")
    if payload.expected_email.strip().lower()!=user.email.lower():
        raise HTTPException(409,"Le contact a changé. Actualisez la fiche avant de poursuivre.")
    normalized=str(payload.email).strip().lower()
    if not contact_is_usable(normalized):
        raise HTTPException(422,"Renseignez une adresse email utilisable.")
    old={"email":user.email,"activated_at":user.credential_activated_at.isoformat() if user.credential_activated_at else None}
    try:
        revoked=revoke_user_sessions(db,user.id)
        user.email=normalized
        if payload.phone is not None and payload.phone.strip():user.phone=payload.phone.strip()
        user.password_hash=hash_password(secrets.token_urlsafe(32))
        user.email_verified=False
        user.credential_setup_required=True
        user.credential_activated_at=None
        user.onboarding_required=user.onboarding_completed_at is None
        user.updated_at=utc_now()
        with db.no_autoflush:
            db.query(ActivationChallenge).filter_by(user_id=user.id).delete(synchronize_session=False)
        queued=issue_activation(db,user)
        if contact_is_usable(old["email"]):
            enqueue_email_delivery(db,recipient_email=old["email"],user_id=user.id,
                subject="Une récupération de votre accès EnactSpace a été préparée",
                text_body=("Après vérification de votre identité, un administrateur a préparé un nouvel accès personnel. "
                    "Vos anciennes sessions ont été fermées. Si vous n'êtes pas à l'origine de cette demande, contactez immédiatement la SG."),
                dedupe_key=f"contact-recovery-notice:{user.id}:{user.updated_at.isoformat()}")
        create_audit_log(db,"account_contact_recovery_prepared",actor.id,"user",user.id,old_value=old,
            new_value={"email":user.email,"verification_note":payload.verification_note.strip(),
                       "revoked_sessions":revoked,"queued":queued})
        db.commit()
    except IntegrityError as exc:
        db.rollback();raise HTTPException(409,"Cette adresse est déjà liée à un compte.") from exc
    return {"message":"Un nouvel accès personnel est préparé. Le membre vérifiera son adresse avec le code et choisira son mot de passe.","queued":queued}
