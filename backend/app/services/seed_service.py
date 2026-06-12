from datetime import date
from sqlalchemy.orm import Session

from app.models.role import Role, UserRole
from app.models.user import User
from app.models.season import Season
from app.models.pole import Pole
from app.models.project import Project
from app.models.gamification import Badge
from app.core.security import hash_password


DEFAULT_ROLES = [
    {
        "name": "enacteur",
        "description": "Membre actif de Enactus ESP.",
    },
    {
        "name": "chef_pole",
        "description": "Responsable principal d'un pôle.",
    },
    {
        "name": "adjoint_chef_pole",
        "description": "Adjoint du chef de pôle.",
    },
    {
        "name": "chef_projet",
        "description": "Responsable principal d'un projet.",
    },
    {
        "name": "adjoint_chef_projet",
        "description": "Adjoint du chef de projet.",
    },
    {
        "name": "secretaire_generale",
        "description": "Responsable des PV, réunions, présences et coordination administrative.",
    },
    {
        "name": "financier",
        "description": "Responsable des cotisations, pénalités, paiements et finances du club.",
    },
    {
        "name": "team_leader",
        "description": "Responsable global du club Enactus ESP.",
    },
    {
        "name": "alumni",
        "description": "Ancien enacteur pouvant contribuer comme mentor ou conseiller.",
    },
    {
        "name": "administrateur",
        "description": "Administrateur technique et fonctionnel de la plateforme.",
    },
    {
        "name": "candidat",
        "description": "Candidat au recrutement Enactus ESP.",
    },
    {
        "name": "faculty_advisor",
        "description": "Professeur accompagnateur et trait d'union avec l'école.",
    },
]


DEFAULT_POLES = [
    {
        "name": "Technique",
        "short_name": "Tech",
        "type": "metier",
        "description": "Pôle regroupant les étudiants de Génie électrique, Génie civil et Génie mécanique.",
        "objectives": "Accompagner les projets sur les aspects techniques, prototypage, tests atelier et transferts de technologie.",
    },
    {
        "name": "Chimie",
        "short_name": "Chimie",
        "type": "metier",
        "description": "Pôle regroupant les étudiants de Génie chimique et Biologie appliquée.",
        "objectives": "Accompagner les projets nécessitant des tests laboratoire, formulations, analyses et validations scientifiques.",
    },
    {
        "name": "Gestion",
        "short_name": "Gestion",
        "type": "metier",
        "description": "Pôle regroupant les étudiants en gestion.",
        "objectives": "Accompagner les projets sur les modèles économiques, études de marché, budget et stratégie.",
    },
    {
        "name": "IT",
        "short_name": "IT",
        "type": "metier",
        "description": "Pôle regroupant les étudiants en génie informatique.",
        "objectives": "Accompagner les projets sur les outils numériques, plateformes, données, applications et systèmes informatiques.",
    },
    {
        "name": "Communication",
        "short_name": "Com",
        "type": "support",
        "description": "Pôle support chargé de la communication du club et des différents projets.",
        "objectives": "Gérer l'image du club, les supports visuels, publications, réseaux sociaux et valorisation des activités.",
    },
    {
        "name": "Veille",
        "short_name": "Veille",
        "type": "support",
        "description": "Pôle support chargé de l'assiduité, de la ponctualité, du respect des tâches et délais, de la verbalisation, des opportunités et partenariats.",
        "objectives": "Suivre l'engagement, relancer les membres, détecter les retards et contribuer à la recherche d'opportunités.",
    },
    {
        "name": "Organisation",
        "short_name": "Orga",
        "type": "support",
        "description": "Pôle support chargé de l'organisation des activités, rencontres, voyages et événements.",
        "objectives": "Planifier et coordonner la logistique des activités internes et externes du club.",
    },
]


DEFAULT_PROJECTS = [
    {
        "name": "Aquatus",
        "description": "Projet actif de Enactus ESP.",
        "status": "prototype",
    },
    {
        "name": "Men Nan",
        "description": "Projet actif de Enactus ESP.",
        "status": "prototype",
    },
    {
        "name": "Terassen",
        "description": "Projet actif de Enactus ESP.",
        "status": "prototype",
    },
    {
        "name": "Cherry",
        "description": "Projet actif de Enactus ESP.",
        "status": "prototype",
    },
    {
        "name": "Dimbali",
        "description": "Ancien projet de Enactus ESP arrivé à terme.",
        "status": "termine",
    },
]


DEFAULT_BADGES = [
    {
        "name": "membre_actif",
        "label": "Membre actif",
        "description": "Attribué aux enacteurs très engagés dans les activités du club.",
    },
    {
        "name": "ponctuel",
        "label": "Ponctuel",
        "description": "Attribué aux enacteurs réguliers et ponctuels.",
    },
    {
        "name": "leader",
        "label": "Leader",
        "description": "Attribué aux enacteurs qui prennent des initiatives et encadrent les autres.",
    },
    {
        "name": "innovateur",
        "label": "Innovateur",
        "description": "Attribué aux enacteurs qui proposent des idées nouvelles.",
    },
    {
        "name": "finisher",
        "label": "Finisher",
        "description": "Attribué aux enacteurs qui terminent et livrent leurs tâches.",
    },
    {
        "name": "mentor",
        "label": "Mentor",
        "description": "Attribué aux alumni ou enacteurs qui accompagnent les autres.",
    },
    {
        "name": "communicateur",
        "label": "Communicateur",
        "description": "Attribué aux enacteurs actifs dans la communication.",
    },
    {
        "name": "batisseur",
        "label": "Bâtisseur",
        "description": "Attribué aux enacteurs qui construisent concrètement les projets.",
    },
]


def seed_roles(db: Session) -> int:
    created = 0

    for item in DEFAULT_ROLES:
        existing = db.query(Role).filter(Role.name == item["name"]).first()

        if existing:
            continue

        role = Role(
            name=item["name"],
            description=item["description"],
        )

        db.add(role)
        created += 1

    db.flush()
    return created


def seed_current_season(db: Session) -> tuple[Season, bool]:
    existing = db.query(Season).filter(Season.is_current == True).first()

    if existing:
        return existing, False

    season = Season(
        name="Saison 2025-2026",
        start_date=date(2025, 10, 1),
        end_date=date(2026, 9, 30),
        is_current=True,
        archived=False,
    )

    db.add(season)
    db.flush()

    return season, True


def seed_poles(db: Session, season: Season) -> int:
    created = 0

    for item in DEFAULT_POLES:
        existing = db.query(Pole).filter(
            Pole.name == item["name"],
            Pole.season_id == season.id,
        ).first()

        if existing:
            continue

        pole = Pole(
            season_id=season.id,
            name=item["name"],
            short_name=item["short_name"],
            type=item["type"],
            description=item["description"],
            objectives=item["objectives"],
        )

        db.add(pole)
        created += 1

    db.flush()
    return created


def seed_projects(db: Session, season: Season) -> int:
    created = 0

    for item in DEFAULT_PROJECTS:
        existing = db.query(Project).filter(
            Project.name == item["name"],
            Project.season_id == season.id,
        ).first()

        if existing:
            continue

        project = Project(
            season_id=season.id,
            name=item["name"],
            description=item["description"],
            status=item["status"],
        )

        db.add(project)
        created += 1

    db.flush()
    return created


def seed_badges(db: Session) -> int:
    created = 0

    for item in DEFAULT_BADGES:
        existing = db.query(Badge).filter(Badge.name == item["name"]).first()

        if existing:
            continue

        badge = Badge(
            name=item["name"],
            label=item["label"],
            description=item["description"],
        )

        db.add(badge)
        created += 1

    db.flush()
    return created


def seed_admin_user(
    db: Session,
    first_name: str,
    last_name: str,
    email: str,
    password: str,
) -> tuple[User, bool]:
    existing = db.query(User).filter(User.email == email).first()

    if existing:
        return existing, False

    user = User(
        first_name=first_name,
        last_name=last_name,
        email=email,
        password_hash=hash_password(password),
        status="active",
        email_verified=True,
        is_active=True,
        department="IT",
        study_level="Admin",
        promotion="EnactSpace",
        bio="Premier administrateur EnactSpace.",
    )

    db.add(user)
    db.flush()

    role_names = [
        "administrateur",
        "team_leader",
        "enacteur",
    ]

    roles = db.query(Role).filter(Role.name.in_(role_names)).all()

    for role in roles:
        link = UserRole(
            user_id=user.id,
            role_id=role.id,
        )
        db.add(link)

    db.flush()

    return user, True


def run_initial_seed(
    db: Session,
    admin_first_name: str,
    admin_last_name: str,
    admin_email: str,
    admin_password: str,
) -> dict:
    roles_created = seed_roles(db)

    season, season_created = seed_current_season(db)

    poles_created = seed_poles(db, season)
    projects_created = seed_projects(db, season)
    badges_created = seed_badges(db)

    admin_user, admin_created = seed_admin_user(
        db=db,
        first_name=admin_first_name,
        last_name=admin_last_name,
        email=admin_email,
        password=admin_password,
    )

    db.commit()

    return {
        "ok": True,
        "roles_created": roles_created,
        "season_created": season_created,
        "season_id": str(season.id),
        "poles_created": poles_created,
        "projects_created": projects_created,
        "badges_created": badges_created,
        "admin_created": admin_created,
        "admin_user_id": str(admin_user.id),
        "admin_email": admin_user.email,
    }