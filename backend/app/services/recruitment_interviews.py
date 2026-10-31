"""Dakar appointments, flexible formats and conflict checks across campaigns."""
from datetime import timedelta
from fastapi import HTTPException
from sqlalchemy import or_

from app.core.time import utc_now
from app.models.recruitment import Application, ApplicationInterviewJuror, RecruitmentJuryMember
from app.models.user import User
from app.services.operational_integrity import to_naive_utc
from app.services.recruitment_access import eligible_juror


def interview_roster(db, application):
    rows = db.query(RecruitmentJuryMember, User).join(
        ApplicationInterviewJuror, ApplicationInterviewJuror.jury_member_id == RecruitmentJuryMember.id
    ).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        ApplicationInterviewJuror.application_id == application.id,
    ).order_by(User.last_name, User.first_name).all()
    return [{"member_id": str(member.id), "user_id": str(user.id),
             "name": f"{user.first_name} {user.last_name}".strip(),
             "active": member.is_active and eligible_juror(user)} for member, user in rows]


def assign_interview(db, application, payload):
    # Caller owns the campaign lock. All appointment and membership mutations
    # take that lock first; shared juror User locks serialize across campaigns.
    selected = payload.jury_member_ids
    if selected is None:
        selected = [row.jury_member_id for row in db.query(ApplicationInterviewJuror).filter_by(
            application_id=application.id)]
    rows = db.query(RecruitmentJuryMember, User).join(User, User.id == RecruitmentJuryMember.user_id).filter(
        RecruitmentJuryMember.id.in_(selected),
        RecruitmentJuryMember.campaign_id == application.campaign_id,
    ).all() if selected else []
    if len(rows) != len(selected) or any(not member.is_active or not eligible_juror(user) for member, user in rows):
        raise HTTPException(409, "Le jury a changé. Choisis des membres disponibles dans cette campagne.")
    user_ids = [user.id for _, user in rows]
    if user_ids:
        db.query(User).filter(User.id.in_(user_ids)).order_by(User.id).populate_existing().with_for_update().all()
        if any(not eligible_juror(user) for _, user in rows):
            raise HTTPException(409, "Un membre du jury n’est plus disponible.")
    start = to_naive_utc(payload.interview_at)
    end = to_naive_utc(payload.interview_end_at) if payload.interview_end_at else start + timedelta(minutes=20)
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
    if any((other.interview_end_at or other.interview_at + timedelta(minutes=20)) > start for other in candidates):
        raise HTTPException(409, "Un membre du jury a déjà un entretien sur ce créneau. Choisis une autre heure ou un autre jury.")
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


def interviews_needing_reassignment(db, campaign_id):
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
    return [{"application_id": str(row.id), "name": f"{row.first_name} {row.last_name}".strip(),
             "interview_at": row.interview_at.isoformat() + "Z"} for row in rows]
