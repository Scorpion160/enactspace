"""Campaign-scoped jury access. Appointments never grant a global role."""
from fastapi import HTTPException
from sqlalchemy import select

from app.core.roles import RECRUITMENT_ACCESS_ROLES, is_veille_pole_name
from app.models.pole import Pole, PoleMember
from app.models.recruitment import RecruitmentJuryMember


def eligible_juror(user):
    return bool(user and user.is_active and user.email_verified
                and user.status in {"active", "alumni"})


def is_recruitment_staff(db, user):
    from app.api.deps import get_user_role_names
    if not eligible_juror(user) or user.status != "active":
        return False
    if get_user_role_names(db, user.id).intersection(RECRUITMENT_ACCESS_ROLES):
        return True
    names = db.query(Pole.name).join(PoleMember, PoleMember.pole_id == Pole.id).filter(
        PoleMember.user_id == user.id, PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
    ).all()
    return any(is_veille_pole_name(name) for name, in names)


def can_manage_jury(db, user):
    from app.api.deps import get_user_role_names
    if not eligible_juror(user) or user.status != "active":
        return False
    if get_user_role_names(db, user.id).intersection({
        "administrateur", "team_leader", "secretaire_generale",
        "chef_pole_veille", "adjoint_pole_veille",
    }):
        return True
    names = db.query(Pole.name).join(PoleMember, PoleMember.pole_id == Pole.id).filter(
        PoleMember.user_id == user.id, PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
        PoleMember.position.in_({"chef_pole", "adjoint_chef_pole"}),
    ).all()
    return any(is_veille_pole_name(name) for name, in names)


def assigned_campaign_ids(db, user):
    return select(RecruitmentJuryMember.campaign_id).where(
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    )


def can_access_campaign(db, user, campaign_id):
    if not eligible_juror(user):
        return False
    if is_recruitment_staff(db, user):
        return True
    return db.query(RecruitmentJuryMember.id).filter(
        RecruitmentJuryMember.campaign_id == campaign_id,
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None


def require_campaign_access(db, user, campaign_id):
    if not can_access_campaign(db, user, campaign_id):
        raise HTTPException(403, "Ce dossier est réservé au jury de cette campagne.")


def require_staff(db, user):
    if not is_recruitment_staff(db, user):
        raise HTTPException(403, "Cette action est réservée aux responsables du recrutement.")


def capabilities(db, user):
    from app.api.deps import get_user_role_names
    staff = is_recruitment_staff(db, user)
    return {
        "can_manage_campaigns": staff,
        "can_manage_jury": can_manage_jury(db, user),
        "can_schedule": staff,
        "can_export": staff,
        "can_decide": staff,
        "can_convert": staff and bool(get_user_role_names(db, user.id).intersection({
            "administrateur", "team_leader", "secretaire_generale",
        })),
        "assigned_campaign_ids": [str(value) for value in db.execute(
            assigned_campaign_ids(db, user)).scalars()],
    }
