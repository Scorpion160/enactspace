"""Campaign-scoped recruitment access with EnacChef, jury and revocable readers.

Reading a dossier never grants authority to evaluate, decide, export or publish.
"""
import re
import unicodedata

from fastapi import HTTPException
from sqlalchemy import select, union

from app.core.roles import RECRUITMENT_ACCESS_ROLES, is_veille_pole_name
from app.models.pole import Pole, PoleMember
from app.models.project import ProjectMember
from app.models.recruitment import RecruitmentJuryMember, RecruitmentViewerAccess


ENACHEF_ROLES = frozenset({
    "administrateur", "team_leader", "secretaire_generale", "financier",
    "chef_pole", "adjoint_chef_pole", "chef_projet", "adjoint_chef_projet",
})


def eligible_juror(user):
    return bool(user and user.is_active and user.email_verified
                and user.status in {"active", "alumni"})


def _position_is_current_enachef(value):
    if not value:
        return False
    ascii_position = unicodedata.normalize("NFKD", value.casefold())
    normalized = re.sub(r"[^a-z0-9]+", "_", "".join(
        c for c in ascii_position if not unicodedata.combining(c)
    )).strip("_")
    if normalized.startswith(("ancien_", "ancienne_", "ex_")):
        return False
    return normalized.startswith((
        "chef_pole", "chef_de_pole", "cheffe_de_pole",
        "chef_projet", "chef_de_projet", "cheffe_de_projet",
        "adjoint_chef", "adjointe_chef", "adjoint_de_chef",
        "adjointe_de_chef",
    ))


def is_enachef(db, user):
    """Identify current bureau members, including project/pole posts without a role."""
    if not eligible_juror(user) or user.status != "active":
        return False
    from app.api.deps import get_user_role_names
    if get_user_role_names(db, user.id).intersection(ENACHEF_ROLES):
        return True
    memberships = (
        db.query(PoleMember.position).filter(
            PoleMember.user_id == user.id, PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        ).all()
        + db.query(ProjectMember.position).filter(
            ProjectMember.user_id == user.id, ProjectMember.is_active.is_(True),
            ProjectMember.left_at.is_(None),
        ).all()
    )
    return any(_position_is_current_enachef(row[0]) for row in memberships)


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


def active_jury_member(db, user, campaign_id):
    return eligible_juror(user) and db.query(RecruitmentJuryMember.id).filter(
        RecruitmentJuryMember.campaign_id == campaign_id,
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None


def active_reader(db, user, campaign_id):
    return eligible_juror(user) and db.query(RecruitmentViewerAccess.id).filter(
        RecruitmentViewerAccess.campaign_id == campaign_id,
        RecruitmentViewerAccess.user_id == user.id,
        RecruitmentViewerAccess.is_active.is_(True),
    ).first() is not None


def assigned_campaign_ids(db, user):
    """Read-access campaign IDs, not screening assignments."""
    return union(
        select(RecruitmentJuryMember.campaign_id).where(
            RecruitmentJuryMember.user_id == user.id,
            RecruitmentJuryMember.is_active.is_(True),
        ),
        select(RecruitmentViewerAccess.campaign_id).where(
            RecruitmentViewerAccess.user_id == user.id,
            RecruitmentViewerAccess.is_active.is_(True),
        ),
    )


def can_access_campaign(db, user, campaign_id):
    if not eligible_juror(user):
        return False
    return (is_recruitment_staff(db, user) or is_enachef(db, user)
            or active_jury_member(db, user, campaign_id)
            or active_reader(db, user, campaign_id))


def require_campaign_access(db, user, campaign_id):
    if not can_access_campaign(db, user, campaign_id):
        raise HTTPException(403, "Ce dossier est réservé aux membres habilités de la campagne.")


def require_staff(db, user):
    if not is_recruitment_staff(db, user):
        raise HTTPException(403, "Cette action est réservée aux responsables du recrutement.")


def capabilities(db, user):
    from app.api.deps import get_user_role_names
    staff = is_recruitment_staff(db, user)
    manager = can_manage_jury(db, user)
    enachef = is_enachef(db, user)
    jury = eligible_juror(user) and db.query(RecruitmentJuryMember.id).filter(
        RecruitmentJuryMember.user_id == user.id,
        RecruitmentJuryMember.is_active.is_(True),
    ).first() is not None
    return {
        "can_manage_campaigns": staff,
        "can_manage_jury": manager,
        "can_manage_readers": manager,
        "can_view_all_applications": staff or enachef or jury,
        "can_review_any": jury,
        "is_enachef": enachef,
        "can_schedule": staff,
        "can_export": staff,
        "can_decide": staff,
        "can_convert": staff and bool(get_user_role_names(db, user.id).intersection({
            "administrateur", "team_leader", "secretaire_generale",
        })),
        "assigned_campaign_ids": [str(value) for value in db.execute(
            assigned_campaign_ids(db, user)).scalars()],
    }
