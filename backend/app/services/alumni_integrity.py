"""Authorization and root-lock order for Alumni profiles and mentorships."""
from fastapi import HTTPException
from sqlalchemy.orm import Session
from app.models.user import User
from app.models.alumni import AlumniProfile
from app.models.pole import Pole, PoleMember
from app.models.project import Project, ProjectMember
from app.core.roles import ENACCHEF_ROLES, SECRETARIAT_ROLES, SCOPED_RESPONSIBILITY_ROLES
from app.api.deps import get_user_role_names
from app.services.operational_integrity import assert_operational_actor, lock_row

def is_operational(user):
    return (user.status == "active" and user.is_active and user.email_verified
            and user.profile_type in {"enacteur", "enactrice"})

def is_valid_alumni(user):
    return (user.status == "alumni" and user.is_active and user.email_verified
            and user.profile_type == "alumni")

def assert_valid_reader(user):
    if not (is_operational(user) or is_valid_alumni(user)):
        raise HTTPException(403, "Cette action exige un compte actif et vérifié.")

def can_manage_profiles(db, user):
    return is_operational(user) and bool(get_user_role_names(db, user.id) & SECRETARIAT_ROLES)

def is_enacchef(db, user):
    return is_operational(user) and bool(get_user_role_names(db, user.id) & ENACCHEF_ROLES)

def lock_people(db, actor_id, target_id):
    people = {row.id: row for row in db.query(User).filter(User.id.in_({actor_id, target_id}))
              .order_by(User.id.asc()).populate_existing().with_for_update().all()}
    actor = people.get(actor_id)
    if actor is None:
        raise HTTPException(403, "Compte indisponible.")
    assert_valid_reader(actor)
    target = people.get(target_id)
    if target is None:
        raise HTTPException(404, "Utilisateur introuvable.")
    return actor, target

def lock_profile_write(db, actor_id, profile_id):
    reference = db.query(AlumniProfile.user_id).filter(AlumniProfile.id == profile_id).first()
    if reference is None:
        raise HTTPException(404, "Profil Alumni introuvable.")
    actor, target = lock_people(db, actor_id, reference[0])
    profile = lock_row(db, AlumniProfile, profile_id)
    if profile is None:
        raise HTTPException(404, "Profil Alumni introuvable.")
    if actor.id != target.id and not can_manage_profiles(db, actor):
        raise HTTPException(403, "Vous ne pouvez modifier que votre propre profil Alumni.")
    if not is_valid_alumni(target):
        raise HTTPException(409, "Ce compte n'est pas un compte Alumni actif et vérifié.")
    return actor, target, profile

def ensure_mentorship_scope(db, actor, project_id, pole_id):
    assert_operational_actor(actor)
    if project_id is None and pole_id is None:
        raise HTTPException(422, "Rattachez le mentorat à un pôle ou à un projet.")
    roles = get_user_role_names(db, actor.id)
    global_access = bool(roles & (ENACCHEF_ROLES - SCOPED_RESPONSIBILITY_ROLES))
    for model, member_model, key, identity, positions in (
        (Pole, PoleMember, "pole_id", pole_id, {"chef_pole", "adjoint_chef_pole"}),
        (Project, ProjectMember, "project_id", project_id, {"chef_projet", "adjoint_chef_projet"}),
    ):
        if identity is None:
            continue
        if db.query(model).filter(model.id == identity).with_for_update(read=True).first() is None:
            raise HTTPException(422, "Le pôle ou le projet sélectionné est introuvable.")
        if not global_access:
            leader = db.query(member_model.id).filter(
                getattr(member_model, key) == identity, member_model.user_id == actor.id,
                member_model.is_active.is_(True), member_model.left_at.is_(None),
                member_model.position.in_(positions)).first()
            if leader is None:
                raise HTTPException(403, "Ce mentorat relève d'une autre responsabilité.")

def assert_available_mentor(db, user):
    profile = db.query(AlumniProfile).filter(AlumniProfile.user_id == user.id).first()
    if not is_valid_alumni(user) or profile is None or not profile.available_for_mentoring:
        raise HTTPException(409, "Choisissez un Alumni actif et disponible pour le mentorat.")
    return profile

def assert_mentorship_dates(started_at, ended_at):
    if started_at is not None and ended_at is not None and ended_at < started_at:
        raise HTTPException(422, "La date de fin ne peut pas précéder la date de début.")
