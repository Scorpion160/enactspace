import unicodedata


BASE_ACTIVE_ROLE = "enacteur"
ALUMNI_ROLE = "alumni"
CANDIDATE_ROLE = "candidate"

ADMIN_ROLE = "administrateur"
TEAM_LEADER_ROLE = "team_leader"
SECRETARY_ROLE = "secretaire_generale"
FINANCE_ROLE = "financier"

POLE_LEAD_ROLES = {
    "chef_pole",
    "adjoint_chef_pole",
}

PROJECT_LEAD_ROLES = {
    "chef_projet",
    "adjoint_chef_projet",
}

SCOPED_RESPONSIBILITY_ROLES = POLE_LEAD_ROLES | PROJECT_LEAD_ROLES

RESPONSIBILITY_ROLES = {
    TEAM_LEADER_ROLE,
    SECRETARY_ROLE,
    FINANCE_ROLE,
    *SCOPED_RESPONSIBILITY_ROLES,
}

ENACCHEF_ROLES = RESPONSIBILITY_ROLES | {
    ADMIN_ROLE,
    "faculty_advisor",
}

GLOBAL_MANAGEMENT_ROLES = {
    ADMIN_ROLE,
    TEAM_LEADER_ROLE,
}

SECRETARIAT_ROLES = {
    ADMIN_ROLE,
    TEAM_LEADER_ROLE,
    SECRETARY_ROLE,
}

FINANCE_MANAGEMENT_ROLES = {
    ADMIN_ROLE,
    TEAM_LEADER_ROLE,
    FINANCE_ROLE,
}

RECRUITMENT_ACCESS_ROLES = ENACCHEF_ROLES | {
    "pole_veille",
    "veille",
    "chef_pole_veille",
    "adjoint_pole_veille",
    "recrutement",
    "recruiter",
}

JOIN_REQUEST_REVIEWER_ROLES = {
    ADMIN_ROLE,
    TEAM_LEADER_ROLE,
    SECRETARY_ROLE,
}

ADMIN_MANAGED_ROLES = {
    ADMIN_ROLE,
    TEAM_LEADER_ROLE,
    SECRETARY_ROLE,
    FINANCE_ROLE,
    "faculty_advisor",
    BASE_ACTIVE_ROLE,
}

TEAM_LEADER_MANAGED_ROLES = {
    SECRETARY_ROLE,
    FINANCE_ROLE,
    "faculty_advisor",
    BASE_ACTIVE_ROLE,
}

SECRETARY_MANAGED_ROLES = {
    FINANCE_ROLE,
    BASE_ACTIVE_ROLE,
}


def normalize_role_name(value: str) -> str:
    without_accents = "".join(
        char
        for char in unicodedata.normalize("NFKD", value.strip().lower())
        if not unicodedata.combining(char)
    )
    return without_accents.replace("-", "_").replace(" ", "_")


def normalize_role_names(values) -> set[str]:
    return {normalize_role_name(value) for value in values if value}
