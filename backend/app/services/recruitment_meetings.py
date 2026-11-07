"""Private interview rooms; candidates enter with their tracking credentials."""
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4
from urllib.parse import urlparse

from fastapi import Depends, HTTPException
from app.core.config import settings
from app.core.time import utc_now
from app.db.database import get_db
from app.models.meeting import Meeting, MeetingMember
from app.models.recruitment import ApplicationInterviewJuror, RecruitmentJuryMember
from app.schemas.meeting import MeetingJoinRead
from app.schemas.recruitment import ApplicationTrackingRequest
from app.services.email_templates import app_link
from app.services.request_rate_limit import protect_public_request
from app.services.operational_integrity import to_naive_utc
from app.services.recruitment_access import can_manage_jury


def candidate_interview_released(campaign, application):
    return bool(campaign.screening_published_at and campaign.identities_revealed_at
                and application.screening_decision == "shortlisted")


def candidate_interview_room(db, application):
    if application.status != "interview_scheduled" or application.interview_meeting_id is None:
        return None
    meeting = db.get(Meeting, application.interview_meeting_id)
    return meeting if meeting and meeting.status in {"scheduled", "live"} else None


def require_private_meet():
    hostname = urlparse(settings.MEET_SERVER_URL).hostname
    if (not hostname or hostname in {"meet.jit.si", "8x8.vc"} or hostname.endswith(".8x8.vc")
            or not settings.MEET_SERVER_URL.startswith("https://")
            or not settings.MEET_REQUIRE_JWT or not settings.MEET_JWT_APP_ID or not settings.MEET_JWT_SECRET):
        raise HTTPException(503, "Les entretiens EnactMeet nécessitent un serveur privé configuré. Choisis un autre lien en attendant sa mise en service.")


def sync_interview_meeting(db, application, payload, actor):
    if not payload.use_enactmeet:
        if application.interview_meeting_id:
            previous = db.get(Meeting, application.interview_meeting_id)
            if previous:
                previous.status, previous.updated_at = "cancelled", utc_now()
            application.interview_meeting_id = None
        return
    require_private_meet()
    if not can_manage_jury(db, actor):
        raise HTTPException(403, "La création des salles d’entretien est réservée aux responsables du recrutement.")
    db.flush()  # The appointment's jury is staged in this transaction.
    jurors = db.query(RecruitmentJuryMember.user_id).join(
        ApplicationInterviewJuror, ApplicationInterviewJuror.jury_member_id == RecruitmentJuryMember.id
    ).filter(ApplicationInterviewJuror.application_id == application.id, RecruitmentJuryMember.is_active.is_(True)).all()
    if not jurors:
        raise HTTPException(422, "Choisis le jury de l’entretien avant de créer sa salle EnactMeet.")
    desired = {user_id for user_id, in jurors} | {actor.id}
    starts = to_naive_utc(payload.interview_at)
    meeting = db.get(Meeting, application.interview_meeting_id) if application.interview_meeting_id else None
    if meeting is not None:
        previous_users = {user_id for user_id, in db.query(MeetingMember.user_id).filter_by(meeting_id=meeting.id)}
        if meeting.scheduled_start != starts or meeting.scheduled_end != application.interview_end_at or previous_users != desired:
            meeting.status, meeting.updated_at = "cancelled", utc_now()
    if meeting is None or meeting.status in {"ended", "cancelled"}:
        meeting = Meeting(room_key="enactspace-" + uuid4().hex, title="Entretien Enactus ESP",
                          scope_type="custom", server_url=settings.MEET_SERVER_URL.rstrip("/"),
                          created_by=actor.id, lobby_enabled=True, recording_enabled=False)
        db.add(meeting)
        db.flush()
        application.interview_meeting_id = meeting.id
    meeting.scheduled_start = starts
    meeting.scheduled_end = application.interview_end_at
    meeting.updated_at = utc_now()
    db.query(MeetingMember).filter(MeetingMember.meeting_id == meeting.id, MeetingMember.user_id.notin_(desired)).delete(synchronize_session=False)
    from app.api.routes.meetings import _add_member
    for user_id in desired:
        _add_member(db, meeting, user_id, role="host" if user_id == actor.id else "cohost")
    # The candidate receives the tracking page, never a reusable raw room link.
    payload.interview_link = app_link("application-tracking")


def register_recruitment_meetings(router):
    @router.post("/applications/interview/join", response_model=MeetingJoinRead,
                 dependencies=[Depends(protect_public_request)])
    def candidate_join(payload: ApplicationTrackingRequest, db=Depends(get_db)):
        from app.api.routes.recruitment import get_application_by_public_reference
        from app.services.recruitment_selection import campaign_for_application
        application = get_application_by_public_reference(db, payload.application_id, payload.email)
        if application is None or not application.tracking_code or payload.application_id.strip().upper() != application.tracking_code.upper():
            raise HTTPException(404, "Aucun entretien ne correspond à ces informations.")
        campaign = campaign_for_application(db, application)
        if not candidate_interview_released(campaign, application):
            raise HTTPException(409, "L’équipe n’a pas encore ouvert cet entretien.")
        meeting = candidate_interview_room(db, application)
        if meeting is None:
            raise HTTPException(409, "Cet entretien EnactMeet n’est pas disponible.")
        now = utc_now()
        start, end = application.interview_at, application.interview_end_at
        if start is None or end is None or now < start - timedelta(minutes=15) or now > end + timedelta(minutes=15):
            raise HTTPException(409, "La salle est accessible à partir de quinze minutes avant l’entretien et jusqu’à quinze minutes après sa fin prévue.")
        if meeting.status != "live":
            raise HTTPException(409, "Le jury n’a pas encore ouvert la salle. Réessaie dans quelques instants.")
        require_private_meet()
        from app.api.routes.meetings import _make_jitsi_token
        guest = SimpleNamespace(id="candidate:" + str(application.id), first_name=application.first_name,
                                last_name=application.last_name, email=application.email, photo_url=None)
        token = _make_jitsi_token(meeting, guest, moderator=False, expires_at=end + timedelta(minutes=15))
        return MeetingJoinRead(meeting_id=meeting.id, room_key=meeting.room_key, server_url=meeting.server_url,
                               jwt=token, display_name=f"{application.first_name} {application.last_name}",
                               email=application.email, avatar_url=None, moderator=False,
                               start_with_audio_muted=False, start_with_video_muted=True,
                               lobby_enabled=True, recording_enabled=False)
