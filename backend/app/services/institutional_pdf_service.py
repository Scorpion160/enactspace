import shutil
import subprocess
import tempfile
from datetime import date, datetime
from pathlib import Path
from typing import Any
from uuid import UUID

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_user_role_names
from app.core.roles import SECRETARY_ROLE, TEAM_LEADER_ROLE
from app.models.document import Document
from app.models.institutional_document import InstitutionalDocumentRequest
from app.models.pole import Pole, PoleMember
from app.models.project import Project
from app.models.season import Season
from app.models.user import User
from app.services.file_storage_service import delete_physical_file, store_bytes
from app.services.institutional_document_service import get_template_rule


RESOURCE_ROOT = Path(__file__).resolve().parents[1] / "resources" / "institutional_documents"
TEMPLATE_ROOT = RESOURCE_ROOT / "templates"
PDFLATEX_TIMEOUT_SECONDS = 30


class InstitutionalPdfError(RuntimeError):
    pass


def latex_escape(value: Any) -> str:
    if value is None:
        return ""
    text = str(value)
    mapping = {
        "\\": r"\textbackslash{}",
        "{": r"\{",
        "}": r"\}",
        "$": r"\$",
        "&": r"\&",
        "#": r"\#",
        "_": r"\_",
        "%": r"\%",
        "~": r"\textasciitilde{}",
        "^": r"\textasciicircum{}",
    }
    return "".join(mapping.get(char, char) for char in text)


def latex_text(value: Any, fallback: str = "Non renseigné") -> str:
    text = "" if value is None else str(value).strip()
    if not text:
        text = fallback
    escaped = latex_escape(text)
    return escaped.replace("\r\n", "\n").replace("\r", "\n").replace("\n", r"\par ")


def _cmd(name: str, value: str, *, renew: bool = False) -> str:
    command = "renewcommand" if renew else "newcommand"
    return f"\\{command}{{\\{name}}}{{{value}}}"


def _parse_temporal(value: Any):
    if isinstance(value, (date, datetime)):
        return value
    if not isinstance(value, str) or not value.strip():
        return None
    raw = value.strip().replace("Z", "+00:00")
    for parser in (datetime.fromisoformat, date.fromisoformat):
        try:
            return parser(raw)
        except ValueError:
            pass
    return None


def format_date(value: Any, fallback: str = "Non renseignée") -> str:
    parsed = _parse_temporal(value)
    if parsed is None:
        return latex_text(value, fallback)
    return parsed.strftime("%d/%m/%Y")


def format_time(value: Any, fallback: str = "--") -> str:
    if isinstance(value, str):
        raw = value.strip()
        if len(raw) >= 5 and raw[2] == ":":
            return latex_escape(raw[:5].replace(":", "h"))
    parsed = _parse_temporal(value)
    if isinstance(parsed, datetime):
        return parsed.strftime("%Hh%M")
    return latex_text(value, fallback)


def format_datetime(value: Any, fallback: str = "Non renseignée") -> str:
    parsed = _parse_temporal(value)
    if isinstance(parsed, datetime):
        return parsed.strftime("%d/%m/%Y à %Hh%M")
    if isinstance(parsed, date):
        return parsed.strftime("%d/%m/%Y")
    return latex_text(value, fallback)


def format_long_date(value: Any, fallback: str = "Non renseignée") -> str:
    parsed = _parse_temporal(value)
    if parsed is None:
        return latex_text(value, fallback)
    months = (
        "janvier", "février", "mars", "avril", "mai", "juin",
        "juillet", "août", "septembre", "octobre", "novembre", "décembre",
    )
    return f"{parsed.day} {months[parsed.month - 1]} {parsed.year}"


def _uuid(value: Any) -> UUID | None:
    try:
        return UUID(str(value)) if value else None
    except (TypeError, ValueError, AttributeError):
        return None


def user_for_value(db: Session, value: Any) -> User | None:
    user_id = _uuid(value)
    if user_id is None:
        return None
    return db.query(User).filter(User.id == user_id).first()


def user_name(db: Session, value: Any, fallback: str = "Non renseigné") -> str:
    user = user_for_value(db, value)
    if user is not None:
        return latex_text(f"{user.first_name} {user.last_name}", fallback)
    if isinstance(value, dict):
        display = value.get("name") or value.get("label") or value.get("full_name")
        return latex_text(display, fallback)
    return latex_text(value, fallback)


def _names(db: Session, values: Any, fallback: str = "Néant") -> str:
    if not isinstance(values, list) or not values:
        return latex_text(fallback, fallback)
    names = [user_name(db, value, "") for value in values]
    names = [name for name in names if name]
    return ", ".join(names) if names else latex_text(fallback, fallback)


def _list_items(values: Any, *, numbered: bool = False, fallback: str = "Néant") -> str:
    if not isinstance(values, list) or not values:
        values = [fallback]
    environment = "enumerate" if numbered else "itemize"
    items = []
    for value in values:
        if isinstance(value, dict):
            value = value.get("label") or value.get("title") or value.get("text") or value.get("name") or str(value)
        items.append(f"\\item {latex_text(value, fallback)}")
    return f"\\begin{{{environment}}}" + "".join(items) + f"\\end{{{environment}}}"


def _dict_value(item: Any, keys: tuple[str, ...], fallback: str = "") -> Any:
    if isinstance(item, dict):
        for key in keys:
            value = item.get(key)
            if value not in (None, "", [], {}):
                return value
        return fallback
    return item if item not in (None, "") else fallback


def _rows_two(values: Any, *, fallback_left: str = "Néant", fallback_right: str = "Aucun détail") -> str:
    if not isinstance(values, list) or not values:
        values = [{"title": fallback_left, "details": fallback_right}]
    rows = []
    for item in values:
        left = _dict_value(item, ("title", "topic", "subject", "name", "point", "label"), fallback_left)
        right = _dict_value(item, ("details", "detail", "decision", "notes", "description", "summary", "value"), fallback_right)
        rows.append(f"{latex_text(left, fallback_left)} & {latex_text(right, fallback_right)}\\\\")
    return "\n".join(rows)


def _action_rows(db: Session, values: Any, *, fourth_default: str = "À faire") -> str:
    if not isinstance(values, list) or not values:
        values = [{"action": "Néant", "responsible": "-", "deadline": "-", "status": fourth_default}]
    rows = []
    for item in values:
        action = _dict_value(item, ("action", "task", "deliverable", "title", "name"), "Néant")
        responsible = _dict_value(item, ("responsible", "owner", "responsible_id", "owner_id"), "-")
        deadline = _dict_value(item, ("deadline", "due_date", "date"), "-")
        fourth = _dict_value(item, ("status", "diffusion", "visibility", "state"), fourth_default)
        rows.append(
            f"{latex_text(action)} & {user_name(db, responsible, '-')} & "
            f"{format_date(deadline, '-')} & {latex_text(fourth, fourth_default)}\\\\"
        )
    return "\n".join(rows)


def _route_items(values: Any) -> str:
    if not isinstance(values, list) or not values:
        values = ["Itinéraire à préciser"]
    parts = []
    for item in values:
        if isinstance(item, dict):
            start = item.get("from") or item.get("start") or item.get("departure")
            end = item.get("to") or item.get("end") or item.get("arrival")
            distance = item.get("distance") or item.get("distance_km")
            if start or end:
                label = f"{start or '?'} - {end or '?'}"
                if distance not in (None, ""):
                    label += f" : {distance} km"
            else:
                label = item.get("label") or item.get("text") or str(item)
        else:
            label = item
        parts.append(f"\\item {latex_text(label)}")
    return "".join(parts)


def _pole_name(db: Session, pole_id) -> str:
    if pole_id is None:
        return latex_text("Enactus ESP")
    pole = db.query(Pole).filter(Pole.id == pole_id).first()
    return latex_text(pole.name if pole else "Pôle Enactus ESP")


def _project_name(db: Session, project_id) -> str:
    if project_id is None:
        return latex_text("Projet Enactus ESP")
    project = db.query(Project).filter(Project.id == project_id).first()
    return latex_text(project.name if project else "Projet Enactus ESP")


def _season_name(db: Session, season_id) -> str:
    season = db.query(Season).filter(Season.id == season_id).first() if season_id else None
    return latex_text(season.name if season else "Saison non renseignée")


def _role_label_for_pole_lead(db: Session, user_id, pole_id) -> str:
    membership = (
        db.query(PoleMember)
        .filter(
            PoleMember.user_id == user_id,
            PoleMember.pole_id == pole_id,
            PoleMember.is_active.is_(True),
            PoleMember.left_at.is_(None),
        )
        .first()
    )
    if membership and membership.position == "adjoint_chef_pole":
        return "Adjoint(e) Chef(fe) du Pôle Veille"
    return "Chef(fe) du Pôle Veille"


def _user_with_role(db: Session, request: InstitutionalDocumentRequest, role: str) -> User | None:
    candidates = (
        request.approved_by,
        request.sg_validated_by,
        request.submitted_by,
        request.requested_by,
    )
    for user_id in candidates:
        if not user_id:
            continue
        user = db.query(User).filter(User.id == user_id).first()
        if user and role in get_user_role_names(db, user.id):
            return user
    return None


def _signer(db: Session, request: InstitutionalDocumentRequest) -> tuple[str, str, str]:
    user = _user_with_role(db, request, TEAM_LEADER_ROLE)
    if user is None:
        return (latex_text("Responsable habilité"), latex_text("Team Leader"), "")
    return (
        latex_text(f"{user.first_name} {user.last_name}"),
        latex_text("Team Leader - Club Enactus ESP"),
        latex_text(user.phone, ""),
    )


def _sg_name(db: Session, request: InstitutionalDocumentRequest) -> str:
    user = _user_with_role(db, request, SECRETARY_ROLE)
    if user is None:
        return latex_text("Secrétariat Général")
    return latex_text(f"{user.first_name} {user.last_name}")


def _common_lines(db: Session, request: InstitutionalDocumentRequest) -> list[str]:
    if not request.official_reference:
        raise InstitutionalPdfError("La demande n'a pas encore de référence officielle.")
    return [
        _cmd("DocReference", latex_escape(request.official_reference), renew=True),
        _cmd("DocStatus", "OFFICIEL", renew=True),
        _cmd("DocVersion", latex_escape(request.template_version), renew=True),
        _cmd("Season", _season_name(db, request.season_id), renew=True),
        _cmd("GeneratedDate", datetime.utcnow().strftime("%d/%m/%Y"), renew=True),
        _cmd("GeneratedBy", "EnactSpace", renew=True),
    ]


def _pv_pole_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    chair = p.get("chairperson_id") or request.submitted_by or request.requested_by
    secretary = p.get("secretary_id") or request.requested_by
    present = p.get("participants") or []
    return [
        _cmd("PoleName", _pole_name(db, request.pole_id)),
        _cmd("MeetingDate", format_date(p.get("meeting_date"))),
        _cmd("MeetingLocation", latex_text(p.get("location"))),
        _cmd("StartTime", format_time(p.get("start_time"))),
        _cmd("EndTime", format_time(p.get("end_time"))),
        _cmd("MeetingChair", user_name(db, chair)),
        _cmd("MeetingSecretary", user_name(db, secretary)),
        _cmd("ApprovalText", f"Validé par {_sg_name(db, request)}"),
        _cmd("Attendees", _names(db, present)),
        _cmd("ExcusedAbsentees", _names(db, p.get("excused_absentees") or p.get("absentees"))),
        _cmd("UnexcusedAbsentees", _names(db, p.get("unexcused_absentees"))),
        _cmd("Agenda", _list_items(p.get("agenda"), numbered=True)),
        _cmd("Reminders", _list_items(p.get("reminders"), fallback="Aucun rappel particulier")),
        _cmd("DiscussionRows", _rows_two(p.get("discussion_points"))),
        _cmd("ActionRows", _action_rows(db, p.get("action_plan"))),
        _cmd("Miscellaneous", latex_text(p.get("miscellaneous") or p.get("escalations"), "Néant")),
        _cmd("EnactorMinute", latex_text(p.get("enactor_minute"), "Néant")),
        _cmd("NextMeeting", format_datetime(p.get("next_meeting"), "À déterminer")),
        _cmd("PresentCount", latex_text(len(present), "0")),
    ]


def _pv_project_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    chair = p.get("chairperson_id") or request.submitted_by or request.requested_by
    secretary = p.get("secretary_id") or request.requested_by
    discussions = p.get("discussion_points") or p.get("deliverables")
    risk_parts = []
    for key in ("risks", "needs"):
        if p.get(key):
            risk_parts.append(latex_text(p.get(key)))
    return [
        _cmd("ProjectName", _project_name(db, request.project_id)),
        _cmd("ProjectPhase", latex_text(p.get("project_phase"), "Non renseignée")),
        _cmd("MeetingDate", format_date(p.get("meeting_date"))),
        _cmd("MeetingLocation", latex_text(p.get("location"))),
        _cmd("StartTime", format_time(p.get("start_time"))),
        _cmd("EndTime", format_time(p.get("end_time"))),
        _cmd("MeetingChair", user_name(db, chair)),
        _cmd("MeetingSecretary", user_name(db, secretary)),
        _cmd("ApprovalText", f"Validé par {_sg_name(db, request)}"),
        _cmd("Attendees", _names(db, p.get("participants"))),
        _cmd("Absentees", _names(db, p.get("absentees"))),
        _cmd("Agenda", _list_items(p.get("agenda"), numbered=True)),
        _cmd("DiscussionRows", _rows_two(discussions)),
        _cmd("ActionRows", _action_rows(db, p.get("action_plan"))),
        _cmd("RisksNeeds", r"\par ".join(risk_parts) if risk_parts else latex_text("Néant")),
        _cmd("Miscellaneous", latex_text(p.get("miscellaneous"), "Néant")),
        _cmd("NextMeeting", format_datetime(p.get("next_review"), "À déterminer")),
    ]


def _pv_general_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    chair = p.get("chairperson_id") or _user_with_role(db, request, TEAM_LEADER_ROLE)
    secretary = p.get("secretary_id") or _user_with_role(db, request, SECRETARY_ROLE)
    present = p.get("participants") or []
    discussions = list(p.get("discussion_points") or [])
    for key, label in (("pole_updates", "Point des pôles"), ("project_updates", "Point des projets"), ("votes", "Votes / résolutions")):
        value = p.get(key)
        if value:
            discussions.append({"title": label, "details": value})
    return [
        _cmd("MeetingDate", format_date(p.get("meeting_date"))),
        _cmd("MeetingLocation", latex_text(p.get("location"))),
        _cmd("StartTime", format_time(p.get("start_time"))),
        _cmd("EndTime", format_time(p.get("end_time"))),
        _cmd("MeetingChair", user_name(db, chair)),
        _cmd("MeetingSecretary", user_name(db, secretary)),
        _cmd("ApprovalText", "Les Enacteurs présents"),
        _cmd("Attendees", _names(db, present)),
        _cmd("ExcusedAbsentees", _names(db, p.get("excused_absentees") or p.get("absentees"))),
        _cmd("UnexcusedAbsentees", _names(db, p.get("unexcused_absentees"))),
        _cmd("Agenda", _list_items(p.get("agenda"), numbered=True)),
        _cmd("Reminders", _list_items(p.get("reminders") or p.get("announcements"), fallback="Aucun rappel particulier")),
        _cmd("DiscussionRows", _rows_two(discussions)),
        _cmd("ActionRows", _action_rows(db, p.get("action_plan"))),
        _cmd("Miscellaneous", latex_text(p.get("miscellaneous"), "Néant")),
        _cmd("EnactorMinute", latex_text(p.get("enactor_minute"), "Néant")),
        _cmd("PresentCount", latex_text(len(present), "0")),
    ]


def _pv_enacchef_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    chair = p.get("chairperson_id") or _user_with_role(db, request, TEAM_LEADER_ROLE)
    secretary = p.get("secretary_id") or _user_with_role(db, request, SECRETARY_ROLE)
    followup = []
    for key, label in (("governance", "Gouvernance"), ("pole_followup", "Suivi des pôles"), ("project_followup", "Suivi des projets"), ("member_cases", "Situations particulières")):
        if p.get(key):
            followup.append(f"{label} : {latex_text(p.get(key))}")
    return [
        _cmd("MeetingDate", format_date(p.get("meeting_date"))),
        _cmd("MeetingLocation", latex_text(p.get("location"))),
        _cmd("StartTime", format_time(p.get("start_time"))),
        _cmd("EndTime", format_time(p.get("end_time"))),
        _cmd("MeetingChair", user_name(db, chair)),
        _cmd("MeetingSecretary", user_name(db, secretary)),
        _cmd("ApprovalText", "Enac'chefs présents"),
        _cmd("Attendees", _names(db, p.get("participants"))),
        _cmd("Agenda", _list_items(p.get("agenda"), numbered=True)),
        _cmd("DiscussionRows", _rows_two(p.get("strategic_topics") or p.get("decisions"))),
        _cmd("ActionRows", _action_rows(db, p.get("action_plan"), fourth_default="Enac'chefs")),
        _cmd("ProjectPoleFollowUp", r"\par ".join(followup) if followup else latex_text("Néant")),
        _cmd("ConfidentialNotes", latex_text(p.get("confidential_notes") or p.get("club_communications"), "Néant")),
        _cmd("NextMeeting", format_datetime(p.get("next_meeting"), "À déterminer")),
    ]


def _parental_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    signer_name, signer_role, signer_phone = _signer(db, request)
    member = user_for_value(db, p.get("member_id"))
    class_name = p.get("class_name") or (member.study_level if member else None)
    department = p.get("department") or (member.department if member else None)
    departure = format_long_date(p.get("departure_at"))
    return_at = format_long_date(p.get("return_at"))
    period = f"du {departure} au {return_at}"
    parent = p.get("guardian_name")
    recipient = f"Madame / Monsieur {latex_text(parent)}" if parent else "Madame / Monsieur le parent ou représentant légal"
    return [
        _cmd("LetterDate", format_long_date(datetime.utcnow())),
        _cmd("ParentRecipient", recipient),
        _cmd("ParticipantName", user_name(db, p.get("member_id"))),
        _cmd("ParticipantClass", latex_text(class_name, "classe / niveau non renseigné")),
        _cmd("ParticipantDepartment", latex_text(department, "département non renseigné")),
        _cmd("TripPurpose", latex_text(p.get("trip_type") or p.get("trip_purpose"))),
        _cmd("TravelPeriod", period),
        _cmd("TravelLocations", latex_text(p.get("destination"))),
        _cmd("TravelFunding", latex_text(p.get("coverage"), "La prise en charge sera assurée conformément aux modalités communiquées par Enactus ESP")),
        _cmd("OrderMissionInfo", latex_text(p.get("supervision"), "un encadrement assuré par les responsables désignés")),
        _cmd("TripContactName", user_name(db, p.get("trip_leader_id"), "le responsable du voyage")),
        _cmd("TripContactPhone", latex_text(p.get("trip_leader_phone"), "le contact officiel d'Enactus ESP")),
        _cmd("SignerName", signer_name),
        _cmd("SignerRole", signer_role),
        _cmd("SignerPhone", signer_phone),
    ]


def _bus_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    signer_name, signer_role, signer_phone = _signer(db, request)
    recipient_name = p.get("recipient_name") or "la personne responsable"
    period = f"du {format_long_date(p.get('departure_at'))} au {format_long_date(p.get('return_at'))}"
    return [
        _cmd("LetterDate", format_long_date(datetime.utcnow())),
        _cmd("RecipientTitle", latex_text(recipient_name)),
        _cmd("RecipientOrganization", latex_text(p.get("recipient_organization"))),
        _cmd("PassengerCount", latex_text(p.get("passenger_count"))),
        _cmd("TripPurpose", latex_text(p.get("trip_purpose"))),
        _cmd("TravelPeriod", period),
        _cmd("RouteItems", _route_items(p.get("route"))),
        _cmd("AdditionalNeed", latex_text(p.get("observations") or p.get("justification"), "Aucune contrainte particulière signalée")),
        _cmd("SignerName", signer_name),
        _cmd("SignerRole", signer_role),
        _cmd("SignerPhone", signer_phone),
    ]


def _rse_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    signer_name, signer_role, signer_phone = _signer(db, request)
    impact_objectives = p.get("expected_impact") or p.get("objectives") or p.get("measurable_results")
    attachments = p.get("attachments")
    if isinstance(attachments, list):
        attachments = ", ".join(str(item) for item in attachments)
    return [
        _cmd("LetterDate", format_long_date(datetime.utcnow())),
        _cmd("RecipientName", latex_text(p.get("recipient_name"), "Madame, Monsieur")),
        _cmd("RecipientRole", latex_text(p.get("recipient_role"), "Responsable RSE")),
        _cmd("CompanyName", latex_text(p.get("company"))),
        _cmd("InitiativeName", latex_text(p.get("initiative"))),
        _cmd("ContextNeed", latex_text(p.get("context"), "Contexte à préciser")),
        _cmd("Beneficiaries", latex_text(p.get("beneficiaries"), "À préciser")),
        _cmd("ImpactArea", latex_text(p.get("territory"), "À préciser")),
        _cmd("ImpactObjectives", latex_text(impact_objectives, "À préciser")),
        _cmd("SupportRequested", latex_text(p.get("request_description"))),
        _cmd("SupportAmount", latex_text(p.get("requested_value"), "À définir avec le partenaire")),
        _cmd("PartnerValue", latex_text(p.get("partner_value"), "un suivi d'impact et une valorisation adaptée au partenariat")),
        _cmd("Attachments", latex_text(attachments, "selon disponibilité")),
        _cmd("SignerName", signer_name),
        _cmd("SignerRole", signer_role),
        _cmd("ContactPhone", latex_text(p.get("contact_phone"), signer_phone)),
    ]


def _renvoi_data(db: Session, request: InstitutionalDocumentRequest, p: dict[str, Any]) -> list[str]:
    issuer = db.query(User).filter(User.id == request.requested_by).first()
    approver = _user_with_role(db, request, TEAM_LEADER_ROLE)
    member = user_for_value(db, p.get("member_id"))
    issuer_name = latex_text(f"{issuer.first_name} {issuer.last_name}" if issuer else "Responsable Pôle Veille")
    approval_name = latex_text(f"{approver.first_name} {approver.last_name}" if approver else "Team Leader")
    return [
        _cmd("LetterDate", format_long_date(datetime.utcnow())),
        _cmd("IssuingScope", _pole_name(db, request.pole_id)),
        _cmd("MemberName", user_name(db, p.get("member_id"))),
        _cmd("MemberFirstName", latex_text(member.first_name if member else "Membre")),
        _cmd("NotificationObject", "Notification de fin du statut de membre actif"),
        _cmd("Facts", latex_text(p.get("facts"))),
        _cmd("EffectiveDate", format_long_date(p.get("effective_date"))),
        _cmd("AppreciationText", latex_text("Nous tenons néanmoins à souligner que votre présence passée, votre intérêt pour Enactus et toute contribution apportée au club restent considérés et appréciés. Cette décision ne remet pas en cause la valeur de votre passage au sein de l'équipe.")),
        _cmd("IssuerLabel", "Pour le Pôle Veille"),
        _cmd("IssuerName", issuer_name),
        _cmd("IssuerRole", latex_text(_role_label_for_pole_lead(db, request.requested_by, request.pole_id))),
        _cmd("ApprovalLabel", "Vu et approuvé"),
        _cmd("ApprovalName", approval_name),
        _cmd("ApprovalRole", "Team Leader -- Club Enactus ESP"),
        _cmd("AdministrativeNote", latex_text("La présente notification est établie sur la base du suivi des présences, de l'implication et des informations disponibles auprès du Pôle Veille. Toute remarque administrative ou justificatif non encore transmis peut être adressé aux instances compétentes du club.")),
    ]


DATA_BUILDERS = {
    "pv_pole": _pv_pole_data,
    "pv_projet": _pv_project_data,
    "pv_reunion_generale": _pv_general_data,
    "pv_enacchef": _pv_enacchef_data,
    "autorisation_parentale_voyage": _parental_data,
    "demande_bus": _bus_data,
    "demande_rse": _rse_data,
    "notification_renvoi": _renvoi_data,
}


def build_data_tex(db: Session, request: InstitutionalDocumentRequest) -> str:
    builder = DATA_BUILDERS.get(request.template_code)
    if builder is None:
        raise InstitutionalPdfError("Aucun générateur PDF n'est défini pour ce modèle.")
    lines = _common_lines(db, request)
    lines.extend(builder(db, request, request.payload_json or {}))
    return "\n".join(lines) + "\n"


def _copy_optional_assets(work_dir: Path) -> None:
    target = work_dir / "assets"
    target.mkdir(parents=True, exist_ok=True)
    resource_assets = RESOURCE_ROOT / "assets"
    if resource_assets.is_dir():
        for source in resource_assets.iterdir():
            if source.is_file():
                shutil.copy2(source, target / source.name)

    repo_root = Path(__file__).resolve().parents[3]
    app_logo = repo_root / "frontend" / "assets" / "img" / "logo_enactus_esp.png"
    if app_logo.is_file() and not (target / "enactus_esp_round.png").exists():
        shutil.copy2(app_logo, target / "enactus_esp_round.png")


def compile_request_pdf(db: Session, request: InstitutionalDocumentRequest) -> bytes:
    if request.status != "validated":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Le PDF officiel ne peut être généré qu'après validation finale.",
        )
    if not request.official_reference:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La référence officielle doit être attribuée avant la génération.",
        )
    executable = shutil.which("pdflatex")
    if executable is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Le moteur LaTeX pdflatex n'est pas installé sur le serveur.",
        )

    template_path = TEMPLATE_ROOT / f"{request.template_code}.tex"
    if not template_path.is_file():
        raise HTTPException(status_code=500, detail="Modèle LaTeX serveur introuvable.")

    with tempfile.TemporaryDirectory(prefix="enactspace-institutional-") as tmp:
        work_dir = Path(tmp)
        (work_dir / "config").mkdir()
        (work_dir / "data").mkdir()
        shutil.copy2(RESOURCE_ROOT / "enactus_esp.sty", work_dir / "enactus_esp.sty")
        shutil.copy2(RESOURCE_ROOT / "config" / "institution.tex", work_dir / "config" / "institution.tex")
        shutil.copy2(template_path, work_dir / "document.tex")
        _copy_optional_assets(work_dir)
        (work_dir / "data" / f"{request.template_code}_data.tex").write_text(
            build_data_tex(db, request), encoding="utf-8"
        )

        command = [
            executable,
            "-halt-on-error",
            "-interaction=nonstopmode",
            "-no-shell-escape",
            "document.tex",
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=work_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                check=False,
                timeout=PDFLATEX_TIMEOUT_SECONDS,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        except subprocess.TimeoutExpired as exc:
            raise HTTPException(
                status_code=status.HTTP_504_GATEWAY_TIMEOUT,
                detail="La génération du PDF a dépassé le délai autorisé.",
            ) from exc

        pdf_path = work_dir / "document.pdf"
        if completed.returncode != 0 or not pdf_path.is_file():
            log_tail = completed.stdout[-3000:] if completed.stdout else ""
            raise InstitutionalPdfError(f"Échec de compilation LaTeX.\n{log_tail}")
        pdf_bytes = pdf_path.read_bytes()
        if len(pdf_bytes) < 1000 or not pdf_bytes.startswith(b"%PDF-"):
            raise InstitutionalPdfError("Le moteur LaTeX n'a pas produit un PDF valide.")
        return pdf_bytes


def persist_official_pdf(
    db: Session,
    request: InstitutionalDocumentRequest,
) -> Document:
    if request.generated_document_id:
        document = db.query(Document).filter(Document.id == request.generated_document_id).first()
        if document is not None:
            return document

    pdf_bytes = compile_request_pdf(db, request)
    rule = get_template_rule(request.template_code)
    requester = db.query(User).filter(User.id == request.requested_by).first()
    if requester is None:
        raise InstitutionalPdfError("Auteur de la demande introuvable.")

    safe_ref = (request.official_reference or request.template_code).replace("/", "-")
    stored_file = None
    try:
        stored_file = store_bytes(
            db,
            data=pdf_bytes,
            original_filename=f"{safe_ref}.pdf",
            uploaded_by=requester,
            mime_type="application/pdf",
            storage_scope="official",
            visibility=rule.visibility,
            entity_type="institutional_document_request",
            entity_id=request.id,
            is_temporary=False,
            is_ephemeral=False,
        )
        validator_id = request.approved_by or request.sg_validated_by
        validated_at = request.approved_at or request.sg_validated_at or datetime.utcnow()
        document = Document(
            title=f"{rule.label} - {request.official_reference}",
            description=(
                f"Document officiel généré automatiquement par EnactSpace à partir "
                f"du modèle {request.template_code} v{request.template_version}."
            ),
            file_url=f"/api/files/{stored_file.id}/download",
            file_id=stored_file.id,
            file_type="pdf",
            category=rule.category,
            status="validated",
            uploaded_by=request.requested_by,
            validated_by=validator_id,
            validated_at=validated_at,
            visibility=rule.visibility,
            pole_id=request.pole_id,
            project_id=request.project_id,
            event_id=request.event_id,
            season_id=request.season_id,
            is_template=False,
            is_official=True,
            is_permanent=True,
            expires_at=None,
        )
        db.add(document)
        db.flush()
        stored_file.entity_type = "document"
        stored_file.entity_id = document.id
        stored_file.updated_at = datetime.utcnow()
        request.generated_document_id = document.id
        request.generated_at = datetime.utcnow()
        request.status = "generated"
        request.updated_at = datetime.utcnow()
        return document
    except Exception:
        if stored_file is not None:
            delete_physical_file(stored_file)
        raise
