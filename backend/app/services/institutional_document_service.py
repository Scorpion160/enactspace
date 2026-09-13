import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.deps import get_user_role_names
from app.core.roles import (
    ADMIN_ROLE,
    POLE_LEAD_ROLES,
    PROJECT_LEAD_ROLES,
    SECRETARY_ROLE,
    TEAM_LEADER_ROLE,
)
from app.models.institutional_document import (
    InstitutionalDocumentRequest,
    InstitutionalDocumentSequence,
)
from app.models.pole import Pole, PoleMember
from app.models.project import ProjectMember
from app.models.season import Season
from app.models.user import User


INSTITUTIONAL_SLOGAN = "Empowering our society is our priority"
REQUEST_STATUSES = {
    "draft",
    "pending_sg_validation",
    "pending_approval",
    "validated",
    "generated",
    "rejected",
    "cancelled",
}


@dataclass(frozen=True)
class InstitutionalTemplateRule:
    code: str
    label: str
    version: str
    category: str
    visibility: str
    reference_prefix: str
    scope: str
    creator_policy: str
    submitter_policy: str
    requires_sg_validation: bool
    requires_tl_approval: bool
    required_payload_fields: tuple[str, ...]
    fields: tuple[dict[str, Any], ...]


def _f(name: str, label: str, field_type: str = "text", required: bool = False, **extra):
    return {
        "name": name,
        "label": label,
        "type": field_type,
        "required": required,
        **extra,
    }


INSTITUTIONAL_TEMPLATES: dict[str, InstitutionalTemplateRule] = {
    "pv_pole": InstitutionalTemplateRule(
        code="pv_pole",
        label="PV réunion de pôle",
        version="2.0",
        category="pv",
        visibility="pole_only",
        reference_prefix="PV-POLE",
        scope="pole_required",
        creator_policy="pole_member",
        submitter_policy="pole_lead",
        requires_sg_validation=True,
        requires_tl_approval=False,
        required_payload_fields=("meeting_date", "agenda", "discussion_points"),
        fields=(
            _f("meeting_date", "Date de la réunion", "date", True),
            _f("start_time", "Heure de début", "time"),
            _f("end_time", "Heure de fin", "time"),
            _f("location", "Lieu / mode de réunion"),
            _f("meeting_type", "Type de réunion"),
            _f("chairperson_id", "Président de séance", "user"),
            _f("secretary_id", "Responsable de la rédaction", "user"),
            _f("participants", "Présents", "users"),
            _f("absentees", "Absents / excusés", "users"),
            _f("agenda", "Ordre du jour", "list", True),
            _f("reminders", "Rappels", "rich_text"),
            _f("discussion_points", "Points discutés", "structured_list", True),
            _f("decisions", "Décisions / remarques", "structured_list"),
            _f("action_plan", "Plan d’action", "action_list"),
            _f("escalations", "Besoins / points à remonter", "rich_text"),
            _f("miscellaneous", "Divers", "rich_text"),
            _f("next_meeting", "Prochaine réunion", "datetime"),
            _f("enactor_minute", "Minute de l’Enacteur", "rich_text"),
        ),
    ),
    "pv_projet": InstitutionalTemplateRule(
        code="pv_projet",
        label="PV réunion de projet",
        version="2.0",
        category="pv",
        visibility="project_only",
        reference_prefix="PV-PROJ",
        scope="project_required",
        creator_policy="project_member",
        submitter_policy="project_lead",
        requires_sg_validation=True,
        requires_tl_approval=False,
        required_payload_fields=("meeting_date", "agenda", "discussion_points"),
        fields=(
            _f("meeting_date", "Date de la réunion", "date", True),
            _f("start_time", "Heure de début", "time"),
            _f("end_time", "Heure de fin", "time"),
            _f("location", "Lieu / mode de réunion"),
            _f("project_phase", "Phase du projet"),
            _f("chairperson_id", "Président de séance", "user"),
            _f("secretary_id", "Responsable de la rédaction", "user"),
            _f("participants", "Présents", "users"),
            _f("absentees", "Absents / excusés", "users"),
            _f("agenda", "Ordre du jour", "list", True),
            _f("deliverables", "Livrables / jalons", "structured_list"),
            _f("kpis", "Indicateurs / KPI", "structured_list"),
            _f("risks", "Difficultés / risques", "structured_list"),
            _f("needs", "Besoins / ressources", "rich_text"),
            _f("discussion_points", "Points discutés", "structured_list", True),
            _f("decisions", "Décisions", "structured_list"),
            _f("action_plan", "Plan d’action", "action_list"),
            _f("next_review", "Prochaine revue", "datetime"),
        ),
    ),
    "pv_reunion_generale": InstitutionalTemplateRule(
        code="pv_reunion_generale",
        label="PV réunion générale",
        version="2.0",
        category="pv",
        visibility="internal",
        reference_prefix="PV-RG",
        scope="club",
        creator_policy="sg_tl_admin",
        submitter_policy="sg_tl_admin",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=("meeting_date", "agenda", "discussion_points"),
        fields=(
            _f("meeting_date", "Date de la réunion", "date", True),
            _f("start_time", "Heure de début", "time"),
            _f("end_time", "Heure de fin", "time"),
            _f("location", "Lieu / mode de réunion"),
            _f("chairperson_id", "Président de séance", "user"),
            _f("secretary_id", "Responsable de la rédaction", "user"),
            _f("participants", "Présents", "users"),
            _f("absentees", "Absents / excusés", "users"),
            _f("quorum", "Quorum", "number"),
            _f("agenda", "Ordre du jour", "list", True),
            _f("announcements", "Annonces générales", "rich_text"),
            _f("pole_updates", "Points des pôles", "structured_list"),
            _f("project_updates", "Points des projets", "structured_list"),
            _f("votes", "Votes / résolutions", "vote_list"),
            _f("discussion_points", "Points discutés", "structured_list", True),
            _f("decisions", "Décisions", "structured_list"),
            _f("action_plan", "Plan d’action", "action_list"),
            _f("miscellaneous", "Questions diverses", "rich_text"),
            _f("enactor_minute", "Minute de l’Enacteur", "rich_text"),
            _f("next_meeting", "Prochaine réunion", "datetime"),
        ),
    ),
    "pv_enacchef": InstitutionalTemplateRule(
        code="pv_enacchef",
        label="PV Enac’Chefs",
        version="2.0",
        category="pv",
        visibility="enacchef_only",
        reference_prefix="PV-EC",
        scope="club",
        creator_policy="sg_tl",
        submitter_policy="sg_tl",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=("meeting_date", "agenda", "strategic_topics"),
        fields=(
            _f("meeting_date", "Date de la réunion", "date", True),
            _f("start_time", "Heure de début", "time"),
            _f("end_time", "Heure de fin", "time"),
            _f("location", "Lieu / mode de réunion"),
            _f("participants", "Enac’Chefs présents", "users"),
            _f("absentees", "Absents / excusés", "users"),
            _f("agenda", "Ordre du jour", "list", True),
            _f("strategic_topics", "Sujets stratégiques", "structured_list", True),
            _f("governance", "Gouvernance", "rich_text"),
            _f("pole_followup", "Suivi des pôles", "structured_list"),
            _f("project_followup", "Suivi des projets", "structured_list"),
            _f("member_cases", "Situations particulières", "structured_list"),
            _f("decisions", "Décisions", "decision_list"),
            _f("action_plan", "Plan d’action", "action_list"),
            _f("club_communications", "Éléments à communiquer au club", "rich_text"),
            _f("next_meeting", "Prochaine réunion", "datetime"),
        ),
    ),
    "autorisation_parentale_voyage": InstitutionalTemplateRule(
        code="autorisation_parentale_voyage",
        label="Autorisation parentale – voyage",
        version="2.0",
        category="voyage",
        visibility="private",
        reference_prefix="AUT-PAR",
        scope="optional",
        creator_policy="scope_lead_sg_tl",
        submitter_policy="scope_lead_sg_tl",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=(
            "member_id",
            "trip_purpose",
            "destination",
            "departure_at",
            "return_at",
        ),
        fields=(
            _f("member_id", "Enacteur / Enactrice concerné(e)", "user", True),
            _f("class_name", "Classe / filière"),
            _f("trip_type", "Nature du voyage"),
            _f("trip_purpose", "Objet / activité", "rich_text", True),
            _f("destination", "Destination / localités", "text", True),
            _f("departure_at", "Départ", "datetime", True),
            _f("return_at", "Retour", "datetime", True),
            _f("meeting_point", "Lieu de rassemblement"),
            _f("transport", "Moyen de transport"),
            _f("accommodation", "Hébergement"),
            _f("coverage", "Modalités de prise en charge", "rich_text"),
            _f("supervision", "Encadrement", "rich_text"),
            _f("trip_leader_id", "Responsable du voyage", "user"),
            _f("trip_leader_phone", "Téléphone du responsable", "phone"),
            _f("guardian_name", "Nom du parent / tuteur (optionnel)"),
            _f("additional_information", "Informations complémentaires", "rich_text"),
        ),
    ),
    "demande_rse": InstitutionalTemplateRule(
        code="demande_rse",
        label="Demande RSE",
        version="2.0",
        category="partenariat",
        visibility="internal",
        reference_prefix="RSE",
        scope="optional",
        creator_policy="scope_lead_sg_tl",
        submitter_policy="scope_lead_sg_tl",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=("company", "initiative", "request_description"),
        fields=(
            _f("company", "Entreprise", "text", True),
            _f("recipient_name", "Destinataire"),
            _f("recipient_role", "Fonction du destinataire"),
            _f("recipient_address", "Adresse"),
            _f("initiative", "Projet / initiative Enactus", "text", True),
            _f("context", "Contexte / problématique", "rich_text"),
            _f("beneficiaries", "Bénéficiaires", "rich_text"),
            _f("territory", "Zone d’intervention"),
            _f("objectives", "Objectifs", "list"),
            _f("expected_impact", "Impact attendu", "rich_text"),
            _f("sdgs", "ODD concernés", "list"),
            _f("measurable_results", "Résultats mesurables", "structured_list"),
            _f("request_description", "Accompagnement demandé", "rich_text", True),
            _f("requested_value", "Valeur / quantité demandée"),
            _f("implementation_period", "Période de mise en œuvre"),
            _f("partner_value", "Valorisation proposée au partenaire", "rich_text"),
            _f("attachments", "Pièces jointes", "list"),
            _f("contact_name", "Contact Enactus"),
            _f("contact_phone", "Téléphone", "phone"),
            _f("contact_email", "E-mail", "email"),
        ),
    ),
    "demande_bus": InstitutionalTemplateRule(
        code="demande_bus",
        label="Demande de mise à disposition de bus",
        version="2.0",
        category="voyage",
        visibility="internal",
        reference_prefix="BUS",
        scope="optional",
        creator_policy="scope_lead_sg_tl",
        submitter_policy="scope_lead_sg_tl",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=("recipient_organization", "trip_purpose", "departure_at", "return_at", "passenger_count"),
        fields=(
            _f("recipient_organization", "Structure destinataire", "text", True),
            _f("recipient_name", "Responsable destinataire"),
            _f("trip_purpose", "Motif du déplacement", "rich_text", True),
            _f("linked_activity", "Événement / projet lié"),
            _f("departure_at", "Date et heure de départ", "datetime", True),
            _f("departure_place", "Lieu de départ"),
            _f("return_at", "Date et heure de retour", "datetime", True),
            _f("return_place", "Lieu de retour"),
            _f("route", "Itinéraire / étapes", "route_list"),
            _f("passenger_count", "Nombre de voyageurs", "number", True),
            _f("requested_capacity", "Capacité souhaitée", "number"),
            _f("group_leader_id", "Responsable du groupe", "user"),
            _f("group_leader_phone", "Téléphone", "phone"),
            _f("justification", "Justification", "rich_text"),
            _f("observations", "Observations", "rich_text"),
        ),
    ),
    "notification_renvoi": InstitutionalTemplateRule(
        code="notification_renvoi",
        label="Notification de renvoi",
        version="2.0",
        category="discipline",
        visibility="private",
        reference_prefix="REN",
        scope="veille_required",
        creator_policy="veille_lead",
        submitter_policy="veille_lead",
        requires_sg_validation=True,
        requires_tl_approval=True,
        required_payload_fields=("member_id", "decision_date", "decision_body", "facts", "effective_date"),
        fields=(
            _f("member_id", "Membre concerné", "user", True),
            _f("member_role", "Fonction / pôle / projet"),
            _f("decision_date", "Date de la décision", "date", True),
            _f("decision_body", "Instance ayant pris la décision", "text", True),
            _f("effective_date", "Date d’effet", "date", True),
            _f("facts", "Faits établis", "rich_text", True),
            _f("prior_steps", "Rappels / avertissements antérieurs", "structured_list"),
            _f("procedure", "Éléments de procédure", "rich_text"),
            _f("decision", "Décision prononcée", "rich_text"),
            _f("administrative_consequences", "Conséquences administratives", "rich_text"),
            _f("return_instructions", "Matériel / documents à restituer", "rich_text"),
            _f("review_process", "Modalités éventuelles de réexamen", "rich_text"),
            _f("internal_notes", "Observations internes", "rich_text"),
        ),
    ),
}


def normalize_label(value: str | None) -> str:
    if not value:
        return ""
    without_accents = "".join(
        char
        for char in unicodedata.normalize("NFKD", value.strip().lower())
        if not unicodedata.combining(char)
    )
    return re.sub(r"[^a-z0-9]+", " ", without_accents).strip()


def get_template_rule(code: str) -> InstitutionalTemplateRule:
    rule = INSTITUTIONAL_TEMPLATES.get(code)
    if rule is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Modèle institutionnel inconnu.",
        )
    return rule


def is_veille_pole(pole: Pole | None) -> bool:
    if pole is None:
        return False
    values = (normalize_label(pole.name), normalize_label(pole.short_name))
    return any("veille" in value.split() for value in values if value)


def _active_pole_membership_query(db: Session, user_id):
    return db.query(PoleMember).filter(
        PoleMember.user_id == user_id,
        PoleMember.is_active.is_(True),
        PoleMember.left_at.is_(None),
    )


def _active_project_membership_query(db: Session, user_id):
    return db.query(ProjectMember).filter(
        ProjectMember.user_id == user_id,
        ProjectMember.is_active.is_(True),
        ProjectMember.left_at.is_(None),
    )


def user_is_pole_member(db: Session, user_id, pole_id) -> bool:
    if pole_id is None:
        return False
    return _active_pole_membership_query(db, user_id).filter(
        PoleMember.pole_id == pole_id
    ).first() is not None


def user_is_pole_lead(db: Session, user_id, pole_id) -> bool:
    if pole_id is None:
        return False
    return _active_pole_membership_query(db, user_id).filter(
        PoleMember.pole_id == pole_id,
        PoleMember.position.in_(POLE_LEAD_ROLES),
    ).first() is not None


def user_is_project_member(db: Session, user_id, project_id) -> bool:
    if project_id is None:
        return False
    return _active_project_membership_query(db, user_id).filter(
        ProjectMember.project_id == project_id
    ).first() is not None


def user_is_project_lead(db: Session, user_id, project_id) -> bool:
    if project_id is None:
        return False
    return _active_project_membership_query(db, user_id).filter(
        ProjectMember.project_id == project_id,
        ProjectMember.position.in_(PROJECT_LEAD_ROLES),
    ).first() is not None


def user_is_veille_lead(db: Session, user_id, pole_id=None) -> bool:
    query = (
        _active_pole_membership_query(db, user_id)
        .join(Pole, Pole.id == PoleMember.pole_id)
        .filter(PoleMember.position.in_(POLE_LEAD_ROLES))
    )
    if pole_id is not None:
        query = query.filter(PoleMember.pole_id == pole_id)
    memberships = query.all()
    return any(
        is_veille_pole(
            db.query(Pole).filter(Pole.id == membership.pole_id).first()
        )
        for membership in memberships
    )


def _has_scope_leadership(db: Session, user_id, pole_id=None, project_id=None) -> bool:
    return user_is_pole_lead(db, user_id, pole_id) or user_is_project_lead(
        db, user_id, project_id
    )


def can_start_template(db: Session, user: User, rule: InstitutionalTemplateRule) -> bool:
    roles = get_user_role_names(db, user.id)
    policy = rule.creator_policy
    if policy == "pole_member":
        return _active_pole_membership_query(db, user.id).first() is not None
    if policy == "project_member":
        return _active_project_membership_query(db, user.id).first() is not None
    if policy == "sg_tl_admin":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE, ADMIN_ROLE}))
    if policy == "sg_tl":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE}))
    if policy == "scope_lead_sg_tl":
        if roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE}):
            return True
        return (
            _active_pole_membership_query(db, user.id)
            .filter(PoleMember.position.in_(POLE_LEAD_ROLES))
            .first()
            is not None
            or _active_project_membership_query(db, user.id)
            .filter(ProjectMember.position.in_(PROJECT_LEAD_ROLES))
            .first()
            is not None
        )
    if policy == "veille_lead":
        return user_is_veille_lead(db, user.id)
    return False


def can_create_request(
    db: Session,
    user: User,
    rule: InstitutionalTemplateRule,
    *,
    pole_id=None,
    project_id=None,
) -> bool:
    roles = get_user_role_names(db, user.id)
    policy = rule.creator_policy
    if policy == "pole_member":
        return user_is_pole_member(db, user.id, pole_id)
    if policy == "project_member":
        return user_is_project_member(db, user.id, project_id)
    if policy == "sg_tl_admin":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE, ADMIN_ROLE}))
    if policy == "sg_tl":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE}))
    if policy == "scope_lead_sg_tl":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE})) or _has_scope_leadership(
            db, user.id, pole_id, project_id
        )
    if policy == "veille_lead":
        return user_is_veille_lead(db, user.id, pole_id)
    return False


def can_submit_request(db: Session, user: User, request: InstitutionalDocumentRequest) -> bool:
    rule = get_template_rule(request.template_code)
    roles = get_user_role_names(db, user.id)
    policy = rule.submitter_policy
    if policy == "pole_lead":
        return user_is_pole_lead(db, user.id, request.pole_id)
    if policy == "project_lead":
        return user_is_project_lead(db, user.id, request.project_id)
    if policy == "sg_tl_admin":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE, ADMIN_ROLE}))
    if policy == "sg_tl":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE}))
    if policy == "scope_lead_sg_tl":
        return bool(roles.intersection({SECRETARY_ROLE, TEAM_LEADER_ROLE})) or _has_scope_leadership(
            db, user.id, request.pole_id, request.project_id
        )
    if policy == "veille_lead":
        return user_is_veille_lead(db, user.id, request.pole_id)
    return False


def can_access_request(db: Session, user: User, request: InstitutionalDocumentRequest) -> bool:
    if request.requested_by == user.id:
        return True
    roles = get_user_role_names(db, user.id)
    if roles.intersection({ADMIN_ROLE, SECRETARY_ROLE, TEAM_LEADER_ROLE}):
        return True
    if user_is_pole_lead(db, user.id, request.pole_id):
        return True
    if user_is_project_lead(db, user.id, request.project_id):
        return True
    return False


def validate_request_scope(
    db: Session,
    rule: InstitutionalTemplateRule,
    *,
    pole_id=None,
    project_id=None,
) -> None:
    if rule.scope == "pole_required" and pole_id is None:
        raise HTTPException(status_code=400, detail="Le pôle est obligatoire pour ce modèle.")
    if rule.scope == "project_required" and project_id is None:
        raise HTTPException(status_code=400, detail="Le projet est obligatoire pour ce modèle.")
    if rule.scope == "veille_required":
        if pole_id is None:
            raise HTTPException(status_code=400, detail="Le Pôle Veille est obligatoire.")
        pole = db.query(Pole).filter(Pole.id == pole_id).first()
        if not is_veille_pole(pole):
            raise HTTPException(
                status_code=400,
                detail="Une notification de renvoi doit être rattachée au Pôle Veille.",
            )


def validate_payload(rule: InstitutionalTemplateRule, payload: dict[str, Any]) -> None:
    missing = []
    for field_name in rule.required_payload_fields:
        value = payload.get(field_name)
        if value is None or value == "" or value == [] or value == {}:
            missing.append(field_name)
    if missing:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={
                "message": "Le formulaire institutionnel est incomplet.",
                "missing_fields": missing,
            },
        )


def get_current_season(db: Session) -> Season | None:
    return (
        db.query(Season)
        .filter(Season.is_current.is_(True), Season.archived.is_(False))
        .order_by(Season.start_date.desc())
        .first()
    )


def requester_roles(db: Session, request: InstitutionalDocumentRequest) -> set[str]:
    return get_user_role_names(db, request.requested_by)


def should_skip_sg_self_validation(db: Session, request: InstitutionalDocumentRequest) -> bool:
    return SECRETARY_ROLE in requester_roles(db, request)


def should_skip_tl_self_approval(db: Session, request: InstitutionalDocumentRequest) -> bool:
    return TEAM_LEADER_ROLE in requester_roles(db, request)


def next_status_after_submit(db: Session, request: InstitutionalDocumentRequest) -> str:
    rule = get_template_rule(request.template_code)
    roles = requester_roles(db, request)
    if (
        rule.requires_sg_validation
        and rule.requires_tl_approval
        and {SECRETARY_ROLE, TEAM_LEADER_ROLE}.issubset(roles)
    ):
        return "pending_approval"
    if rule.requires_sg_validation and SECRETARY_ROLE not in roles:
        return "pending_sg_validation"
    if rule.requires_tl_approval and TEAM_LEADER_ROLE not in roles:
        return "pending_approval"
    return "validated"


def next_status_after_sg_validation(db: Session, request: InstitutionalDocumentRequest) -> str:
    rule = get_template_rule(request.template_code)
    if rule.requires_tl_approval and not should_skip_tl_self_approval(db, request):
        return "pending_approval"
    return "validated"


def _season_reference_slug(name: str) -> str:
    normalized = unicodedata.normalize("NFKD", name)
    ascii_text = "".join(char for char in normalized if not unicodedata.combining(char))
    slug = re.sub(r"[^A-Za-z0-9]+", "-", ascii_text).strip("-")
    return slug or "SAISON"


def allocate_official_reference(db: Session, request: InstitutionalDocumentRequest) -> str:
    if request.official_reference:
        return request.official_reference
    if request.season_id is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Impossible d’officialiser sans saison.",
        )
    rule = get_template_rule(request.template_code)
    if db.get_bind().dialect.name == "postgresql":
        db.execute(
            text("SELECT pg_advisory_xact_lock(hashtext(:key))"),
            {"key": f"institutional:{request.season_id}:{request.template_code}"},
        )
    season = db.query(Season).filter(Season.id == request.season_id).first()
    if season is None:
        raise HTTPException(status_code=409, detail="Saison introuvable.")

    sequence = (
        db.query(InstitutionalDocumentSequence)
        .filter(
            InstitutionalDocumentSequence.season_id == request.season_id,
            InstitutionalDocumentSequence.template_code == request.template_code,
        )
        .with_for_update()
        .first()
    )
    if sequence is None:
        sequence = InstitutionalDocumentSequence(
            season_id=request.season_id,
            template_code=request.template_code,
            last_number=0,
        )
        db.add(sequence)
        db.flush()

    sequence.last_number += 1
    sequence.updated_at = datetime.utcnow()
    request.sequence_number = sequence.last_number
    request.official_reference = (
        f"EESP/{rule.reference_prefix}/{_season_reference_slug(season.name)}/"
        f"{sequence.last_number:03d}"
    )
    return request.official_reference


def request_flags(db: Session, user: User, request: InstitutionalDocumentRequest) -> dict[str, bool]:
    roles = get_user_role_names(db, user.id)
    return {
        "can_edit": request.requested_by == user.id and request.status in {"draft", "rejected"},
        "can_submit": request.status in {"draft", "rejected"} and can_submit_request(db, user, request),
        "can_sg_validate": (
            request.status == "pending_sg_validation"
            and SECRETARY_ROLE in roles
            and request.requested_by != user.id
        ),
        "can_approve": (
            request.status == "pending_approval"
            and TEAM_LEADER_ROLE in roles
            and request.requested_by != user.id
        ),
        "can_cancel": request.requested_by == user.id
        and request.status in {"draft", "rejected", "pending_sg_validation"},
    }
