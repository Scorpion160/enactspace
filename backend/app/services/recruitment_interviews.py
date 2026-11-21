"""Dakar appointments, flexible formats and conflict checks across campaigns."""
from datetime import timedelta
import secrets
import unicodedata
import re
from fastapi import HTTPException
from sqlalchemy import or_

from app.core.time import utc_now
from app.models.recruitment import (Application, ApplicationInterviewJuror, ApplicationInterviewTeam,
                                    RecruitmentCampaign, RecruitmentJuryMember, RecruitmentJuryTeam)
from app.models.user import User
from app.services.operational_integrity import to_naive_utc
from app.services.recruitment_access import eligible_juror


def effective_interview_end(start, end):
    return end if end is not None else start + timedelta(minutes=20)


def interview_completed(application, now):
    return (
        application.status == "interview_scheduled"
        and application.interview_at is not None
        and effective_interview_end(application.interview_at, application.interview_end_at) <= now
    )


def interview_roster(db, application):
    rows = db.query(RecruitmentJuryMember, User).join(
        ApplicationInterviewJuror, ApplicationInterviewJuror.jury_member_id == RecruitmentJuryMember.id
    ).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        ApplicationInterviewJuror.application_id == application.id,
    ).order_by(User.last_name, User.first_name).all()
    return [{"member_id": str(member.id), "user_id": str(user.id),
             "name": f"{user.first_name} {user.last_name}".strip(),
             "active": member.is_active and eligible_juror(user)} for member, user in rows]


def department_key(value):
    """Normalize ESP department names; Civil and GCBA remain distinct."""
    text = unicodedata.normalize("NFKD", (value or "").casefold())
    normalized = re.sub(r"[^a-z0-9]+", "", "".join(
        character for character in text if not unicodedata.combining(character)
    ))
    aliases = {
        "ge": "genieelectrique", "gi": "genieinformatique",
        "gm": "geniemecanique", "gc": "geniecivil",
    }
    return aliases.get(normalized, normalized)


def department_represented(application, jury_users):
    target = department_key(application.department)
    return bool(target and any(department_key(user.department) == target for user in jury_users))


def propose_interview_jury(db, application, *, start, end, size=3):
    """Read-only, load-aware random proposal with departmental coverage."""
    from sqlalchemy import func
    members = db.query(RecruitmentJuryMember, User).join(
        User, User.id == RecruitmentJuryMember.user_id
    ).filter(
        RecruitmentJuryMember.campaign_id == application.campaign_id,
        RecruitmentJuryMember.is_active.is_(True),
        User.is_active.is_(True),
        User.email_verified.is_(True),
        User.status.in_({"active", "alumni"}),
    ).all()
    eligible = [(member, user) for member, user in members
                if user.email.casefold() != application.email.casefold()]
    target = department_key(application.department)
    if not target or not any(department_key(user.department) == target for _, user in eligible):
        raise HTTPException(409, "Aucun juré du département du candidat n’est disponible dans la campagne.")
    # Existing appointments across campaigns count towards each juror's workload.
    loads = dict(db.query(RecruitmentJuryMember.user_id, func.count(ApplicationInterviewJuror.application_id))
        .join(ApplicationInterviewJuror,
              ApplicationInterviewJuror.jury_member_id == RecruitmentJuryMember.id)
        .group_by(RecruitmentJuryMember.user_id).all())
    concurrent = db.query(RecruitmentJuryMember.user_id, Application.interview_at,
                          Application.interview_end_at).join(
        ApplicationInterviewJuror,
        ApplicationInterviewJuror.jury_member_id == RecruitmentJuryMember.id
    ).join(Application, Application.id == ApplicationInterviewJuror.application_id).filter(
        Application.id != application.id,
        Application.status.in_({"interview_scheduled", "interview"}),
        Application.interview_at < end,
        RecruitmentJuryMember.user_id.in_([user.id for _, user in eligible]),
    ).all()
    occupied = {user_id for user_id, other_start, other_end in concurrent
                if effective_interview_end(other_start, other_end) > start}
    available = [(member, user) for member, user in eligible if user.id not in occupied]
    same = [(member, user) for member, user in available if department_key(user.department) == target]
    if len(available) < size:
        raise HTTPException(409, "Pas assez de jurés disponibles sur ce créneau. Réduis la taille du jury ou change d'horaire.")
    if not same:
        raise HTTPException(409, "Aucun membre du département n'est libre sur ce créneau.")
    rng = secrets.SystemRandom()
    def pick(pool):
        lightest = min(loads.get(user.id, 0) for _, user in pool)
        return rng.choice([pair for pair in pool if loads.get(pair[1].id, 0) == lightest])
    chosen = [pick(same)]
    remaining = [pair for pair in available if pair[0].id != chosen[0][0].id]
    while remaining and len(chosen) < size:
        pair = pick(remaining)
        chosen.append(pair)
        remaining = [row for row in remaining if row[0].id != pair[0].id]
    return {
        "candidate_department": application.department,
        "member_ids": [str(member.id) for member, _ in chosen],
        "department_juror_id": str(chosen[0][0].id),
        "count": len(chosen),
        "confirmed": False,
    }


def assign_interview(db, application, payload):
    # Caller owns the campaign lock. All appointment and membership mutations
    # take that lock first; shared juror User locks serialize across campaigns.
    selected = payload.jury_member_ids
    from app.services.recruitment_teams import team_members
    snapshot = db.get(ApplicationInterviewTeam, application.id)
    team = None
    if payload.jury_team_id is not None or (selected is None and snapshot is not None):
        team_id = payload.jury_team_id or snapshot.team_id
        team = db.query(RecruitmentJuryTeam).filter_by(id=team_id, campaign_id=application.campaign_id).first()
        revision = payload.jury_team_revision if payload.jury_team_id is not None else snapshot.revision
        if team is None or not team.is_active or revision != team.revision:
            raise HTTPException(409, "Cette équipe a changé ou n’est plus disponible. Recharge le planning pour choisir sa composition actuelle.")
        selected = [member.id for member, _ in team_members(db, team)]
        if not selected:
            raise HTTPException(409, "Ajoute des membres à cette équipe avant de lui attribuer un entretien.")
    if selected is None:
        selected = [row.jury_member_id for row in db.query(ApplicationInterviewJuror).filter_by(
            application_id=application.id)]
    rows = db.query(RecruitmentJuryMember, User).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        RecruitmentJuryMember.id.in_(selected),
        RecruitmentJuryMember.campaign_id == application.campaign_id,
    ).all() if selected else []
    if len(rows) != len(selected) or any(not member.is_active or not eligible_juror(user) for member, user in rows):
        raise HTTPException(409, "Le jury a changé. Choisis des membres disponibles dans cette campagne.")
    if any(user.email.casefold() == application.email.casefold() for _, user in rows):
        raise HTTPException(409, "Un membre du jury ne peut pas participer à son propre entretien de recrutement.")
    if not department_represented(application, [user for _, user in rows]):
        raise HTTPException(409, "Choisis au moins un juré du département du candidat pour cet entretien.")
    user_ids = [user.id for _, user in rows]
    if user_ids:
        db.query(User).filter(User.id.in_(user_ids)).order_by(User.id).populate_existing().with_for_update().all()
        if any(not eligible_juror(user) for _, user in rows):
            raise HTTPException(409, "Un membre du jury n’est plus disponible.")
    start = to_naive_utc(payload.interview_at)
    end = effective_interview_end(start, to_naive_utc(payload.interview_end_at) if payload.interview_end_at else None)
    # No noon/evening restriction: the chosen interval is authoritative.
    # Historical appointments without an end use the conservative legacy 20 min.
    candidates = db.query(Application).join(
        ApplicationInterviewJuror, ApplicationInterviewJuror.application_id == Application.id
    ).join(RecruitmentJuryMember, RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id).filter(
        RecruitmentJuryMember.user_id.in_(user_ids),
        RecruitmentJuryMember.is_active.is_(True),
        Application.id != application.id,
        Application.status.in_({"interview_scheduled", "interview"}),
        Application.interview_at < end,
    ).all() if user_ids else []
    if any(effective_interview_end(other.interview_at, other.interview_end_at) > start for other in candidates):
        raise HTTPException(409, "Un membre du jury a déjà un entretien sur ce créneau. Choisis une autre heure ou un autre jury.")
    if team is not None:
        appointments = db.query(Application).join(ApplicationInterviewTeam,
            ApplicationInterviewTeam.application_id == Application.id).filter(
            ApplicationInterviewTeam.team_id == team.id, Application.id != application.id,
            Application.status.in_({"interview_scheduled", "interview"}), Application.interview_at < end,
        ).all()
        if any(effective_interview_end(other.interview_at, other.interview_end_at) > start for other in appointments):
            raise HTTPException(409, "Cette équipe a déjà un entretien sur ce créneau. Choisis une autre équipe ou une autre heure.")
        if snapshot is None:
            snapshot = ApplicationInterviewTeam(application_id=application.id)
            db.add(snapshot)
        snapshot.team_id, snapshot.revision, snapshot.name = team.id, team.revision, team.name
    elif snapshot is not None:
        db.delete(snapshot)
    db.query(ApplicationInterviewJuror).filter_by(application_id=application.id).delete(synchronize_session=False)
    for member, _ in rows:
        db.add(ApplicationInterviewJuror(application_id=application.id, jury_member_id=member.id))
    application.interview_end_at = end
    application.interview_mode = payload.interview_mode
    if rows:
        payload.interview_jury = ", ".join(f"{user.first_name} {user.last_name}" for _, user in rows)


def affected_future_interviews(db, member):
    return db.query(Application).join(ApplicationInterviewJuror,
        ApplicationInterviewJuror.application_id == Application.id).filter(
        ApplicationInterviewJuror.jury_member_id == member.id,
        Application.status.in_({"interview_scheduled", "interview"}),
        or_(Application.interview_at >= utc_now(), Application.interview_end_at > utc_now()),
    ).order_by(Application.interview_at).all()


def interviews_needing_reassignment(db, campaign_id, user):
    from app.services.recruitment_selection import (
        identity_is_visible, interview_candidate_label, uses_blind_selection,
    )
    campaign = db.get(RecruitmentCampaign, campaign_id)
    anonymized = uses_blind_selection(campaign) and not identity_is_visible(db, user, campaign)
    rows = db.query(Application).join(ApplicationInterviewJuror,
        ApplicationInterviewJuror.application_id == Application.id).join(RecruitmentJuryMember,
        RecruitmentJuryMember.id == ApplicationInterviewJuror.jury_member_id).join(User,
        User.id == RecruitmentJuryMember.user_id).filter(
        Application.campaign_id == campaign_id,
        Application.status.in_({"interview_scheduled", "interview"}),
        or_(Application.interview_at >= utc_now(), Application.interview_end_at > utc_now()),
        or_(RecruitmentJuryMember.is_active.is_(False), User.is_active.is_(False),
            User.email_verified.is_(False), User.status.notin_({"active", "alumni"})),
    ).order_by(Application.interview_at).all()
    stale_teams = db.query(Application).join(ApplicationInterviewTeam,
        ApplicationInterviewTeam.application_id == Application.id).join(RecruitmentJuryTeam,
        RecruitmentJuryTeam.id == ApplicationInterviewTeam.team_id).filter(
        Application.campaign_id == campaign_id,
        Application.status.in_({"interview_scheduled", "interview"}),
        or_(Application.interview_at >= utc_now(), Application.interview_end_at > utc_now()),
        or_(RecruitmentJuryTeam.is_active.is_(False), RecruitmentJuryTeam.revision != ApplicationInterviewTeam.revision),
    ).all()
    unique = {row.id: row for row in [*rows, *stale_teams]}
    return [{"application_id": str(row.id), "name": interview_candidate_label(row, anonymized=anonymized),
             "interview_at": row.interview_at.isoformat() + "Z"}
            for row in sorted(unique.values(), key=lambda app: (app.interview_at, str(app.id)))]
