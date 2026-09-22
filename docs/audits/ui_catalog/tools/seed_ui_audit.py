"""Deterministic, isolated fixture seed for the EnactSpace UI audit.

This tool is mounted read-only into the audit backend container. It deliberately
refuses any database URL except the isolated Compose database before dropping
tables. It never calls HTTP, SMTP, push, payment, Mobile Money, or production.
"""

from __future__ import annotations

import json
import os
import sys
import uuid
import hashlib
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path

from sqlalchemy import text
from sqlalchemy.engine import make_url

from app.core.security import hash_password
from app.core.config import settings
from app.db.database import Base, SessionLocal, engine
import app.models.base  # noqa: F401
from app.models.academy import AcademyCourse, AcademyLesson, AcademyProgress
from app.models.alumni import AlumniProfile, Mentorship
from app.models.archive import ArchiveItem, ArchivedProject, Award, HallOfFameEntry
from app.models.attendance import (
    AttendanceExpectedMember,
    AttendanceNfcTag,
    AttendanceRecord,
    AttendanceSession,
)
from app.models.chat import ChatMessage, ChatMessageReaction, ChatParticipant, ChatThread
from app.models.document import Document
from app.models.event import Event, EventParticipant
from app.models.finance import FinancialAccount, Fee, Payment
from app.models.gamification import Badge, EngagementPoint, UserBadge
from app.models.impact import ImpactEvidence, ImpactMetric, ImpactProject
from app.models.notification import Notification
from app.models.pole import Pole, PoleMember
from app.models.post import Post, PostComment, PostReaction
from app.models.project import Project, ProjectMember, ProjectPole
from app.models.recruitment import Application, ApplicationReview, RecruitmentCampaign
from app.models.role import Role, UserRole
from app.models.season import Season
from app.models.stored_file import StoredFile
from app.models.task import Task, TaskAssignee, TaskChecklistItem, TaskComment
from app.models.user import User

NOW = datetime(2026, 6, 15, 12, 0, 0)
TODAY = NOW.date()
NAMESPACE = uuid.UUID("c7b11b65-6718-4d5d-a2db-a47224a6a729")

ASSET_BYTES = {
    "audit-profile-0.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-0",
    "audit-profile-1.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-1",
    "audit-profile-2.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-2",
    "audit-profile-3.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-3",
    "audit-profile-4.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-4",
    "audit-profile-5.png": b"\x89PNG\r\n\x1a\nAUDIT-PROFILE-5",
    "audit-1.pdf": b"%PDF-1.4\n% EnactSpace audit PDF\n%%EOF\n",
    "audit-2.png": b"\x89PNG\r\n\x1a\nAUDIT-PNG",
    "audit-3.jpg": b"\xff\xd8\xff\xe0AUDIT-JPEG\xff\xd9",
    "audit-4.xlsx": b"PK\x03\x04AUDIT-XLSX",
    "audit-5.docx": b"PK\x03\x04AUDIT-DOCX",
    "audit-6.txt": b"EnactSpace audit text asset.\n",
    "audit-7.invalid": b"This intentionally invalid audit payload is never advertised as a valid media asset.\n",
    "audit-payment-proof.pdf": b"%PDF-1.4\n% EnactSpace payment proof\n%%EOF\n",
}


def audit_upload_root() -> Path:
    configured = Path(settings.FILE_STORAGE_PATH)
    return configured if configured.is_absolute() else Path(__file__).resolve().parents[4] / configured


def create_asset_files() -> dict[str, tuple[bytes, str]]:
    root = audit_upload_root()
    root.mkdir(parents=True, exist_ok=True)
    for name, payload in ASSET_BYTES.items():
        (root / name).write_bytes(payload)
    return {name: (payload, hashlib.sha256(payload).hexdigest()) for name, payload in ASSET_BYTES.items()}


def uid(key: str) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE, key)


def require_isolated_database() -> None:
    if os.environ.get("APP_ENV") != "ui_audit":
        raise RuntimeError("Refusing fixture seed outside APP_ENV=ui_audit.")

    url = make_url(os.environ.get("DATABASE_URL", ""))
    if url.drivername not in {"postgresql+psycopg", "postgresql"}:
        raise RuntimeError("UI audit requires the dedicated PostgreSQL database.")
    if url.host != "postgres" or url.database != "enactspace_ui_audit":
        raise RuntimeError("Refusing database URL outside postgres/enactspace_ui_audit.")
    if not os.environ.get("UI_AUDIT_PASSWORD"):
        raise RuntimeError("UI_AUDIT_PASSWORD is required in the ignored local env file.")


def reset_isolated_schema() -> None:
    """Reset only the dedicated audit PostgreSQL schema after URL validation."""
    with engine.begin() as connection:
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))


def add(db, model, key: str, **values):
    return model(id=uid(key), **values)


def seed_roles(db):
    names = [
        "administrateur", "team_leader", "secretaire_generale", "financier",
        "chef_pole", "adjoint_chef_pole", "chef_projet", "adjoint_chef_projet",
        "enacteur", "alumni", "candidat",
    ]
    roles = {}
    for name in names:
        role = add(db, Role, f"role:{name}", name=name, description=f"Role audit {name}.")
        db.add(role)
        roles[name] = role
    return roles


def seed_users(db, roles):
    password_hash = hash_password(os.environ["UI_AUDIT_PASSWORD"])
    accounts = [
        ("audit.admin@example.test", "Audit", "Admin", "active", "enacteur", ["administrateur", "enacteur"]),
        ("audit.teamleader@example.test", "Audit", "TeamLeader", "active", "enacteur", ["team_leader", "enacteur"]),
        ("audit.secretary@example.test", "Audit", "Secretary", "active", "enacteur", ["secretaire_generale", "enacteur"]),
        ("audit.finance@example.test", "Audit", "Finance", "active", "enacteur", ["financier", "enacteur"]),
        ("audit.polelead@example.test", "Audit", "PoleLead", "active", "enacteur", ["chef_pole", "enacteur"]),
        ("audit.poledeputy@example.test", "Audit", "PoleDeputy", "active", "enacteur", ["adjoint_chef_pole", "enacteur"]),
        ("audit.projectlead@example.test", "Audit", "ProjectLead", "active", "enacteur", ["chef_projet", "enacteur"]),
        ("audit.member@example.test", "Audit", "Member", "active", "enacteur", ["enacteur"]),
        ("audit.alumni@example.test", "Audit", "Alumni", "alumni", "alumni", ["alumni"]),
        ("audit.candidate@example.test", "Audit", "Candidate", "active", "candidat", ["candidat"]),
        ("audit.multirole@example.test", "Audit", "MultiRole", "active", "enacteur", ["administrateur", "enacteur", "chef_pole"]),
    ]
    for index in range(25):
        accounts.append((
            f"audit.active{index + 1:02d}@example.test",
            "Audit",
            f"Active{index + 1:02d}",
            "active",
            "enacteur",
            ["enacteur"] + (["adjoint_chef_projet"] if index == 2 else []),
        ))
    for index in range(5):
        accounts.append((
            f"audit.inactive{index + 1:02d}@example.test",
            "Audit",
            f"Inactive{index + 1:02d}",
            "inactive",
            "enacteur",
            ["enacteur"],
        ))
    for index in range(9):
        accounts.append((
            f"audit.alumni{index + 1:02d}@example.test",
            "Audit",
            f"Alumni{index + 1:02d}",
            "alumni",
            "alumni",
            ["alumni"],
        ))

    users = {}
    for index, (email, first, last, status, profile_type, role_names) in enumerate(accounts):
        user = add(
            db,
            User,
            f"user:{email}",
            first_name=first,
            last_name=last if index != 34 else "A Very Long Synthetic Audit Name For Responsive Verification",
            email=email,
            phone=f"+22170000{index:04d}",
            gender="non_specifie",
            profile_type=profile_type,
            password_hash=password_hash,
            photo_url=None if index % 4 == 0 else f"/uploads/audit-profile-{index % 6}.png",
            department=["Technique", "Chimie", "Gestion", "IT", "Communication", "Veille", "Organisation"][index % 7],
            study_level="Audit level with deliberately descriptive content" if index == 34 else "Licence 2",
            promotion="Audit 2026",
            bio=None if index % 5 == 0 else f"Profil entierement fictif de validation #{index + 1}.",
            status=status,
            email_verified=status != "inactive",
            is_active=status != "inactive",
            created_at=NOW - timedelta(days=50 - index),
            updated_at=NOW,
        )
        db.add(user)
        users[email] = user
        for role_name in role_names:
            db.add(add(db, UserRole, f"user-role:{email}:{role_name}", user_id=user.id, role_id=roles[role_name].id))
    db.flush()
    return users


def seed_structure(db, users):
    admin = users["audit.admin@example.test"]
    leader = users["audit.teamleader@example.test"]
    season = add(
        db, Season, "season:2025-2026",
        name="Saison Audit 2025-2026", start_date=date(2025, 10, 1),
        end_date=date(2026, 9, 30), is_current=True, archived=False,
    )
    db.add(season)
    db.flush()
    pole_specs = [
        ("Technique", "Tech", "metier"), ("Chimie", "Chimie", "metier"),
        ("Gestion", "Gestion", "metier"), ("IT", "IT", "metier"),
        ("Communication", "Com", "support"), ("Veille", "Veille", "support"),
        ("Organisation", "Orga", "support"),
    ]
    poles = []
    for index, (name, short, kind) in enumerate(pole_specs):
        pole = add(
            db, Pole, f"pole:{name}", season_id=season.id, name=name, short_name=short,
            type=kind, description=f"Pole audit {name}.", objectives=f"Objectifs deterministes de {name}.",
            created_at=NOW, updated_at=NOW,
        )
        db.add(pole)
        poles.append(pole)

    project_specs = [
        ("Audit Horizon", "active"), ("Audit Rivage", "active"),
        ("Audit Canopée", "suspended"), ("Audit Solstice", "completed"),
        ("Audit Passage", "active"), ("Audit Mosaic", "completed"),
        ("Audit Dense Budget", "active"), ("Audit Sans Impact", "suspended"),
    ]
    projects = []
    for index, (name, status) in enumerate(project_specs):
        project = add(
            db, Project, f"project:{index}", season_id=season.id, name=name,
            description=f"Projet fictif {name} avec une description de test.",
            problem_statement="Probleme fictif documente pour le test.",
            solution="Solution fictive testable.", objectives="Objectifs fictifs.",
            expected_impact=None if index == 7 else "Impact previsionnel fictif.",
            budget_estimated=Decimal((index + 1) * 150000),
            status=status, started_at=TODAY - timedelta(days=180 - index * 7),
            ended_at=TODAY - timedelta(days=10) if status == "completed" else None,
            created_at=NOW, updated_at=NOW,
        )
        db.add(project)
        projects.append(project)
    db.flush()

    active_users = [
        user for user in users.values()
        if user.status == "active" and user.profile_type == "enacteur"
    ]
    pole_assignments = {
        "audit.polelead@example.test": (0, "chef"),
        "audit.poledeputy@example.test": (0, "adjoint"),
        "audit.multirole@example.test": (0, "membre"),
        "audit.secretary@example.test": (6, "membre"),
        "audit.finance@example.test": (2, "membre"),
    }
    project_assignments = {
        "audit.projectlead@example.test": (0, "chef"),
        "audit.multirole@example.test": (0, "membre"),
        "audit.finance@example.test": (6, "membre"),
        "audit.secretary@example.test": (0, "membre"),
    }
    for index, user in enumerate(active_users):
        pole_index, pole_position = pole_assignments.get(
            user.email, (index % len(poles), "membre")
        )
        pole = poles[pole_index]
        db.add(add(
            db, PoleMember, f"pole-member:{pole.id}:{user.id}", pole_id=pole.id, user_id=user.id,
            position=pole_position,
            joined_at=TODAY - timedelta(days=90), is_active=True,
        ))
        if user.email != "audit.candidate@example.test":
            project_index, project_position = project_assignments.get(
                user.email, (index % len(projects), "membre")
            )
            project = projects[project_index]
            db.add(add(
                db, ProjectMember, f"project-member:{project.id}:{user.id}", project_id=project.id, user_id=user.id,
                position=project_position,
                joined_at=TODAY - timedelta(days=80), is_active=True,
            ))
    for index, project in enumerate(projects):
        db.add(add(db, ProjectPole, f"project-pole:{project.id}:{poles[index % 7].id}", project_id=project.id, pole_id=poles[index % 7].id))
    db.flush()
    return season, poles, projects, admin, leader, active_users


def seed_files_documents_tasks_events(db, season, poles, projects, admin, active_users, assets):
    files = []
    asset_names = [
        "audit-1.pdf", "audit-2.png", "audit-3.jpg", "audit-4.xlsx",
        "audit-5.docx", "audit-6.txt", "audit-7.invalid", "audit-payment-proof.pdf",
    ]
    extensions = [name.rsplit(".", 1)[1] for name in asset_names]
    mime_types = {
        "pdf": "application/pdf", "png": "image/png", "jpg": "image/jpeg",
        "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        "txt": "text/plain", "invalid": "application/octet-stream",
    }
    for index, name in enumerate(asset_names):
        ext = name.rsplit(".", 1)[1]
        payload, checksum = assets[name]
        stored = add(
            db, StoredFile, f"file:{index}", original_filename=name,
            stored_filename=name, mime_type=mime_types[ext],
            file_size=len(payload), extension=ext,
            storage_path=name, storage_scope="audit",
            uploaded_by_id=admin.id, is_temporary=False, visibility="internal",
            entity_type="audit", checksum=checksum, created_at=NOW, updated_at=NOW,
        )
        db.add(stored)
        files.append(stored)

    db.flush()
    documents = []
    for index in range(30):
        document = add(
            db, Document, f"document:{index}", title=f"Document audit {index + 1}",
            description="Document local fictif pour validation visuelle.",
            file_url=f"/uploads/{asset_names[index % len(asset_names)]}",
            file_id=files[index % len(files)].id, file_type=extensions[index % len(extensions)],
            category=["Rapport", "Budget", "Visuel", "Modele"][index % 4],
            status=["validated", "pending_validation", "rejected"][index % 3],
            uploaded_by=admin.id, validated_by=admin.id if index % 3 == 0 else None,
            validated_at=NOW if index % 3 == 0 else None,
            rejection_reason="Fichier fictif invalide." if index % 3 == 2 else None,
            visibility="public" if index % 5 == 0 else "internal",
            pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id,
            season_id=season.id, is_official=index % 7 == 0,
            created_at=NOW - timedelta(days=index), updated_at=NOW,
        )
        db.add(document)
        documents.append(document)

    for index in range(50):
        task = add(
            db, Task, f"task:{index}", title=f"Tache audit {index + 1}",
            description="Tache fictive de test avec du contenu reproductible.",
            creator_id=admin.id, assigned_by=admin.id,
            pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id,
            priority=["basse", "normale", "haute", "urgente"][index % 4],
            status=["a_faire", "en_cours", "terminee", "bloquee"][index % 4],
            due_date=NOW - timedelta(days=3) if index % 7 == 0 else NOW + timedelta(days=index + 1),
            completed_at=NOW if index % 4 == 2 else None, proof_required=index % 2 == 0,
            proof_url="/uploads/audit-1.pdf" if index % 2 == 0 else None,
            created_at=NOW - timedelta(days=index), updated_at=NOW,
        )
        db.add(task)
        db.flush()
        db.add(add(db, TaskAssignee, f"task-assignee:{index}", task_id=task.id, user_id=active_users[index % len(active_users)].id, assigned_at=NOW))
        db.add(add(db, TaskChecklistItem, f"task-check:{index}", task_id=task.id, title="Verifier le livrable fictif", is_done=index % 3 == 0, created_at=NOW, updated_at=NOW))
        if index < 15:
            db.add(add(db, TaskComment, f"task-comment:{index}", task_id=task.id, user_id=active_users[(index + 1) % len(active_users)].id, content="Commentaire fictif de suivi.", created_at=NOW))
    db.flush()

    events = []
    for index in range(10):
        event = add(
            db, Event, f"event:{index}", season_id=season.id, title=f"Evenement audit {index + 1}",
            description="Evenement synthétique pour le pilote.", event_type="atelier",
            location="Salle Audit", start_time=NOW + timedelta(days=(index - 4) * 7),
            end_time=NOW + timedelta(days=(index - 4) * 7, hours=2), created_by=admin.id,
            pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id,
            budget=Decimal(index * 25000), max_participants=5 if index == 2 else 80,
            requires_registration=index % 2 == 0, attendance_enabled=True,
            report_url="/uploads/audit-1.pdf" if index < 4 else None,
            created_at=NOW, updated_at=NOW,
        )
        db.add(event)
        events.append(event)
        db.flush()
        for offset in range(min(4, len(active_users))):
            db.add(add(db, EventParticipant, f"event-participant:{index}:{offset}", event_id=event.id, user_id=active_users[(index + offset) % len(active_users)].id, registered_at=NOW))
    db.flush()
    return files, documents, events


def seed_attendance_finance(db, season, poles, projects, events, files, admin, active_users):
    sessions = []
    for index in range(20):
        session = add(
            db, AttendanceSession, f"attendance-session:{index}", title=f"Session audit {index + 1}",
            description="Session deterministe pour QR NFC et justificatifs.",
            session_type="general_meeting", scope_type=["club", "pole", "project"][index % 3],
            group_name=None if index % 3 == 0 else f"Groupe audit {index % 3}",
            status=["planned", "open", "closed"][index % 3], event_id=events[index % len(events)].id,
            pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id,
            created_by=admin.id, qr_token=f"AUDIT-QR-{index:02d}", scheduled_at=NOW + timedelta(days=index - 10),
            checkin_start=NOW - timedelta(hours=1), checkin_end=NOW + timedelta(hours=1),
            is_closed=index % 3 == 2, notes="Notes de test.", created_at=NOW, updated_at=NOW,
        )
        db.add(session)
        sessions.append(session)
        db.flush()
        for offset in range(15):
            user = active_users[(index + offset) % len(active_users)]
            db.add(add(db, AttendanceExpectedMember, f"attendance-expected:{index}:{offset}", session_id=session.id, user_id=user.id, is_required=True, created_at=NOW))
            if index * 15 + offset < 300:
                status = ["present", "absent", "late"][offset % 3]
                db.add(add(
                    db, AttendanceRecord, f"attendance-record:{index}:{offset}", session_id=session.id, user_id=user.id,
                    status=status, checkin_time=NOW if status != "absent" else None,
                    delay_minutes=12 if status == "late" else 0, recorded_by=admin.id,
                    source="qr" if offset % 5 == 0 else "manual", recorded_at=NOW,
                    justification="Justification fictive." if status == "absent" else None,
                    justification_status=["pending", "approved", "rejected"][offset % 3] if status == "absent" else "not_submitted",
                    justification_file_id=files[offset % len(files)].id if status == "absent" else None,
                    justification_file_url="/uploads/audit-1.pdf" if status == "absent" else None,
                    is_justified=status == "absent" and offset % 3 == 1, penalty_amount=Decimal("1500") if status == "absent" else Decimal("0"),
                    note="Enregistrement de test.", created_at=NOW, updated_at=NOW,
                ))
    for index in range(4):
        db.add(add(db, AttendanceNfcTag, f"nfc:{index}", member_id=active_users[index].id, tag_uid_hash=f"audit-nfc-hash-{index}", tag_label=f"Audit NFC {index}", assigned_by_id=admin.id, assigned_at=NOW, created_at=NOW, updated_at=NOW))

    for index, user in enumerate(active_users):
        db.add(add(db, FinancialAccount, f"account:{user.id}", user_id=user.id, balance_due=Decimal((index % 5) * 5000), total_paid=Decimal((index + 1) * 2000), updated_at=NOW))
    for index in range(60):
        fine = index >= 40
        db.add(add(
            db, Fee, f"fee:{index}", user_id=active_users[index % len(active_users)].id, season_id=season.id,
            type="fine" if fine else "membership", category="absence" if fine else "cotisation",
            label=f"{'Amende' if fine else 'Cotisation'} audit {index + 1}", description="Element financier fictif.",
            amount=Decimal("0") if index == 0 else Decimal((index % 9 + 1) * 2500),
            amount_paid=Decimal("0") if index % 3 else Decimal((index % 9 + 1) * 2500),
            currency="FCFA", status=["unpaid", "paid", "partial"][index % 3],
            due_date=TODAY - timedelta(days=20 - index), paid_at=NOW if index % 3 == 1 else None,
            proof_file_id=files[index % len(files)].id if index % 4 == 0 else None, created_by=admin.id,
            created_at=NOW, updated_at=NOW,
        ))
    for index in range(40):
        status = ["pending", "validated", "rejected"][index % 3]
        db.add(add(
            db, Payment, f"payment:{index}", user_id=active_users[index % len(active_users)].id,
            amount=Decimal((index % 10 + 1) * 3000), currency="FCFA", method="manual_proof",
            status=status, reference=f"AUDIT-PAY-{index:03d}",
            proof_url="/uploads/audit-payment-proof.pdf", proof_file_id=files[index % len(files)].id,
            validated_by=admin.id if status == "validated" else None, validated_at=NOW if status == "validated" else None,
            rejected_at=NOW if status == "rejected" else None, rejection_reason="Preuve fictive refusee." if status == "rejected" else None,
            created_at=NOW,
        ))
    db.flush()
    return sessions


def seed_community(db, season, poles, projects, files, admin, active_users):
    campaigns = []
    for index in range(4):
        campaign = add(db, RecruitmentCampaign, f"campaign:{index}", season_id=season.id, title=f"Campagne audit {index + 1}", description="Campagne fictive.", start_date=TODAY - timedelta(days=30 - index * 10), end_date=TODAY + timedelta(days=10 - index * 10), is_active=index == 1, created_by=admin.id, created_at=NOW, updated_at=NOW)
        db.add(campaign)
        campaigns.append(campaign)
    db.flush()
    for index in range(30):
        application = add(db, Application, f"application:{index}", campaign_id=campaigns[index % 4].id, first_name="Candidat", last_name=f"Audit{index + 1:02d}", email=f"applicant{index + 1:02d}@example.test", phone=f"+22171111{index:04d}", department="Audit", study_level="Licence 1", motivation="Motivation fictive." if index % 5 else None, preferred_pole=poles[index % len(poles)].name, project_interest=projects[index % len(projects)].name, status=["accepted", "rejected", "received", "reviewing"][index % 4], tracking_code=f"AUDIT-{index + 1000}", final_score=Decimal("75.00") if index % 4 == 0 else None, created_at=NOW, updated_at=NOW)
        db.add(application)
        db.flush()
        if index < 12:
            db.add(add(db, ApplicationReview, f"review:{index}", application_id=application.id, reviewer_id=admin.id, score=Decimal(60 + index), comment="Evaluation fictive.", recommendation="accept" if index % 2 == 0 else "reserve", created_at=NOW, updated_at=NOW))

    posts = []
    for index in range(30):
        post = add(db, Post, f"post:{index}", author_id=active_users[index % len(active_users)].id, title=f"Publication audit {index + 1}" if index % 3 else None, content=("Contenu audit long. " * 30) if index == 29 else f"Publication fictive #{index + 1}.", post_type="official" if index % 7 == 0 else "general", pole_id=poles[index % len(poles)].id if index % 3 == 0 else None, project_id=projects[index % len(projects)].id if index % 4 == 0 else None, media_file_id=files[1].id if index % 2 == 0 else None, media_url="/uploads/audit-2.png" if index % 2 == 0 else None, media_name="audit-2.png" if index % 2 == 0 else None, media_mime_type="image/png" if index % 2 == 0 else None, media_size_bytes=files[1].file_size if index % 2 == 0 else None, is_official=index % 7 == 0, is_pinned=index in {0, 1}, visibility="internal", created_at=NOW - timedelta(hours=index), updated_at=NOW)
        db.add(post)
        posts.append(post)
        db.flush()
        if index < 15:
            db.add(add(db, PostComment, f"post-comment:{index}", post_id=post.id, user_id=active_users[(index + 1) % len(active_users)].id, content="Commentaire audit.", created_at=NOW))
            db.add(add(db, PostReaction, f"post-reaction:{index}", post_id=post.id, user_id=active_users[(index + 2) % len(active_users)].id, reaction_type="like", created_at=NOW))

    threads = []
    for index in range(10):
        thread = add(db, ChatThread, f"thread:{index}", title=None if index == 0 else f"Conversation audit {index}", thread_type="private" if index < 2 else "group", scope_type="pole" if index == 2 else None, scope_id=poles[0].id if index == 2 else None, created_by=admin.id, created_at=NOW, updated_at=NOW)
        db.add(thread)
        threads.append(thread)
        db.flush()
        for offset in range(2 if index < 2 else 5):
            db.add(add(db, ChatParticipant, f"participant:{index}:{offset}", thread_id=thread.id, user_id=active_users[(index + offset) % len(active_users)].id, participant_role="admin" if offset == 0 else "member", joined_at=NOW))
    db.flush()
    for index in range(100):
        # The tenth conversation stays intentionally empty; the first nine hold all 100 messages.
        thread = threads[index % 9]
        message = add(db, ChatMessage, f"message:{index}", thread_id=thread.id, author_id=active_users[index % len(active_users)].id, content=f"Message audit {index + 1}", message_type=["text", "image", "file"][index % 3], created_at=NOW - timedelta(minutes=100 - index))
        db.add(message)
        db.flush()
        if index < 20:
            db.add(add(db, ChatMessageReaction, f"message-reaction:{index}", message_id=message.id, user_id=active_users[(index + 1) % len(active_users)].id, reaction_type="like", created_at=NOW))
    for index in range(30):
        db.add(add(db, Notification, f"notification:{index}", user_id=active_users[index % len(active_users)].id, title=f"Notification audit {index + 1}", message="Notification locale fictive.", type="audit", is_read=index % 2 == 0, related_type="post" if index < 20 else "deleted_target", related_id=posts[index % len(posts)].id if index < 20 else uid(f"missing:{index}"), created_at=NOW - timedelta(hours=index), read_at=NOW if index % 2 == 0 else None))
    db.flush()
    return posts


def seed_learning_impact_archive(db, season, poles, projects, files, admin, active_users, all_users):
    courses = []
    for index in range(15):
        course = add(db, AcademyCourse, f"course:{index}", title=f"Cours audit {index + 1}", description=None if index == 14 else "Cours fictif pour tester progression et indisponibilite.", category=["Vie interne", "Projet", "Leadership"][index % 3], level="debutant", target_roles=["enacteur"], estimated_duration_minutes=30 + index, points=10 + index, is_required=index % 4 == 0, is_published=index != 14, is_archived=False, pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id, created_by_id=admin.id, created_at=NOW, updated_at=NOW)
        db.add(course)
        courses.append(course)
        db.flush()
        lesson = add(db, AcademyLesson, f"lesson:{index}", course_id=course.id, title=f"Lecon audit {index + 1}", summary="Resume fictif.", content="Contenu fictif.", lesson_type="texte", order_index=1, duration_minutes=15, resource_file_id=files[index % len(files)].id, is_published=index != 14, created_at=NOW, updated_at=NOW)
        db.add(lesson)
        db.flush()
        db.add(add(db, AcademyProgress, f"progress:{index}", user_id=active_users[index % len(active_users)].id, course_id=course.id, lesson_id=lesson.id, status=["not_started", "in_progress", "completed"][index % 3], progress_percent=Decimal([0, 45, 100][index % 3]), started_at=NOW if index % 3 else None, completed_at=NOW if index % 3 == 2 else None, updated_at=NOW))

    for index, project in enumerate(projects[:7]):
        impact = add(db, ImpactProject, f"impact:{index}", project_id=project.id, season_id=season.id, title=f"Impact audit {index + 1}", summary="Impact fictif.", direct_beneficiaries=(index + 1) * 120, indirect_beneficiaries=(index + 1) * 350, reach=(index + 1) * 500, jobs_created=index, lives_impacted=(index + 1) * 400, revenue_generated=Decimal((index + 1) * 100000), waste_reduced=Decimal(index * 10), water_saved=Decimal(index * 100), sdgs=[1, 8, 13], status="validated" if index % 2 == 0 else "draft", created_by_id=admin.id, validated_by_id=admin.id if index % 2 == 0 else None, validated_at=NOW if index % 2 == 0 else None, created_at=NOW, updated_at=NOW)
        db.add(impact)
        db.flush()
        metric = add(db, ImpactMetric, f"impact-metric:{index}", impact_project_id=impact.id, title="Beneficiaires directs", category="social", unit="personnes", value=Decimal((index + 1) * 120), source="Audit local", status="validated", evidence_file_id=files[index % len(files)].id, created_by_id=admin.id, validated_by_id=admin.id, validated_at=NOW, created_at=NOW, updated_at=NOW)
        db.add(metric)
        db.flush()
        db.add(add(db, ImpactEvidence, f"impact-evidence:{index}", impact_project_id=impact.id, metric_id=metric.id, file_id=files[index % len(files)].id, title="Preuve audit", description="Preuve fictive.", category="proof", status="validated", submitted_by_id=admin.id, validated_by_id=admin.id, validated_at=NOW, created_at=NOW, updated_at=NOW))

    archive_items = []
    for index, year in enumerate(range(2021, 2026)):
        item = add(db, ArchiveItem, f"archive:{year}", title=f"Archive audit {year}", description=("Recit audit long. " * 25) if index == 4 else "Recit fictif.", category="Historique", year=year, season_id=season.id, project_id=projects[index].id, pole_id=poles[index].id, file_id=files[index].id, visibility="internal", status="validated", is_featured=index % 2 == 0, is_public=False, created_by_id=admin.id, validated_by_id=admin.id, validated_at=NOW, tags=["audit", str(year)], metadata_json={"synthetic": True}, created_at=NOW, updated_at=NOW)
        db.add(item)
        archive_items.append(item)
        db.flush()
        archived = add(db, ArchivedProject, f"archived-project:{year}", archive_item_id=item.id, name=f"Projet historique audit {year}", year=year, season_label=f"Saison {year}-{year + 1}", description="Projet historique fictif.", status="historique", linked_project_id=projects[index].id, key_members=["Audit Admin"], awards=["Prix audit"], created_at=NOW, updated_at=NOW)
        db.add(archived)
        db.flush()
        db.add(add(db, Award, f"award:{year}", archive_item_id=item.id, title=f"Prix audit {year}", year=year, competition="Concours audit", rank="Finaliste", result="Distinction fictive", description="Prix fictif.", archived_project_id=archived.id, file_id=files[index].id if index != 3 else None, media_url=None if index == 3 else "/uploads/audit-2.png", is_featured=index % 2 == 0, created_at=NOW, updated_at=NOW))
        db.add(add(db, HallOfFameEntry, f"hall:{year}", archive_item_id=item.id, title=f"Moment audit {year}", subtitle="Hall of Fame fictif", entry_type="Prix", year=year, description="Recit historique fictif.", score_value=Decimal(index + 1), score_label="Points audit", file_id=files[index].id if index != 4 else None, order_index=index, is_featured=True, created_at=NOW, updated_at=NOW))

    badges = []
    for index, name in enumerate(["leader", "mentor", "finisher", "innovator", "communicator"]):
        badge = add(db, Badge, f"badge:{name}", name=name, label=f"Badge {name}", description="Badge audit.", icon_url=None, created_at=NOW)
        db.add(badge)
        badges.append(badge)
    db.flush()
    for index in range(40):
        user = active_users[index % len(active_users)]
        db.add(add(db, EngagementPoint, f"point:{index}", user_id=user.id, season_id=season.id, pole_id=poles[index % len(poles)].id, project_id=projects[index % len(projects)].id, source_type="audit", source_id=None, points=(index % 8) + 1, reason="Point de test.", awarded_by=admin.id, created_at=NOW))
        if index < len(badges):
            db.add(add(db, UserBadge, f"user-badge:{index}", user_id=user.id, badge_id=badges[index].id, season_id=season.id, awarded_by=admin.id, awarded_at=NOW))
    alumni = [user for user in all_users.values() if user.profile_type == "alumni"]
    for index, user in enumerate(alumni):
        db.add(add(db, AlumniProfile, f"alumni-profile:{user.id}", user_id=user.id, graduation_year=2020 + index, current_company="Entreprise Audit", current_position="Mentor", domain="Audit", skills="Mentorat, audit", experience_summary="Experience fictive.", available_for_mentoring=index % 2 == 0, visibility="internal", created_at=NOW, updated_at=NOW))
    return courses


def assert_fixture_integrity(db, users: dict[str, User]) -> dict[str, int]:
    technique = db.query(Pole).filter(Pole.name == "Technique").one()
    horizon = db.query(Project).filter(Project.name == "Audit Horizon").one()
    checks = {
        "candidate_pole_memberships": db.query(PoleMember).filter(
            PoleMember.user_id == users["audit.candidate@example.test"].id
        ).count(),
        "candidate_project_memberships": db.query(ProjectMember).filter(
            ProjectMember.user_id == users["audit.candidate@example.test"].id
        ).count(),
        "multirole_technique_memberships": db.query(PoleMember).filter(
            PoleMember.pole_id == technique.id,
            PoleMember.user_id == users["audit.multirole@example.test"].id,
            PoleMember.is_active.is_(True),
        ).count(),
        "technique_lead": db.query(PoleMember).filter(
            PoleMember.pole_id == technique.id,
            PoleMember.user_id == users["audit.polelead@example.test"].id,
            PoleMember.position == "chef",
        ).count(),
        "technique_deputy": db.query(PoleMember).filter(
            PoleMember.pole_id == technique.id,
            PoleMember.user_id == users["audit.poledeputy@example.test"].id,
            PoleMember.position == "adjoint",
        ).count(),
        "horizon_project_lead": db.query(ProjectMember).filter(
            ProjectMember.project_id == horizon.id,
            ProjectMember.user_id == users["audit.projectlead@example.test"].id,
            ProjectMember.position == "chef",
        ).count(),
        "threads": db.query(ChatThread).count(),
        "messages": db.query(ChatMessage).count(),
        "empty_threads": db.query(ChatThread).filter(~ChatThread.messages.any()).count(),
        "stored_assets": db.query(StoredFile).count(),
        "physical_assets": sum((audit_upload_root() / name).is_file() for name in ASSET_BYTES),
    }
    expected = {
        "candidate_pole_memberships": 0,
        "candidate_project_memberships": 0,
        "multirole_technique_memberships": 1,
        "technique_lead": 1,
        "technique_deputy": 1,
        "horizon_project_lead": 1,
        "threads": 10,
        "messages": 100,
        "empty_threads": 1,
        "physical_assets": len(ASSET_BYTES),
    }
    failures = {key: checks[key] for key, value in expected.items() if checks[key] != value}
    if failures:
        raise RuntimeError(f"Fixture assertions failed: {failures}")
    return checks


def main() -> None:
    require_isolated_database()
    reset_isolated_schema()
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        assets = create_asset_files()
        roles = seed_roles(db)
        users = seed_users(db, roles)
        season, poles, projects, admin, _leader, active_users = seed_structure(db, users)
        files, _documents, events = seed_files_documents_tasks_events(db, season, poles, projects, admin, active_users, assets)
        seed_attendance_finance(db, season, poles, projects, events, files, admin, active_users)
        seed_community(db, season, poles, projects, files, admin, active_users)
        seed_learning_impact_archive(db, season, poles, projects, files, admin, active_users, users)
        db.commit()
        assertions = assert_fixture_integrity(db, users)
        summary = {
            "users": db.query(User).count(),
            "poles": db.query(Pole).count(),
            "projects": db.query(Project).count(),
            "tasks": db.query(Task).count(),
            "attendance_sessions": db.query(AttendanceSession).count(),
            "attendance_records": db.query(AttendanceRecord).count(),
            "fees": db.query(Fee).count(),
            "payments": db.query(Payment).count(),
            "campaigns": db.query(RecruitmentCampaign).count(),
            "applications": db.query(Application).count(),
            "posts": db.query(Post).count(),
            "threads": db.query(ChatThread).count(),
            "messages": db.query(ChatMessage).count(),
            "documents": db.query(Document).count(),
            "events": db.query(Event).count(),
            "courses": db.query(AcademyCourse).count(),
            "archives": db.query(ArchiveItem).count(),
            "fixture_assertions": assertions,
            "asset_files_written": len(assets),
        }
        print(json.dumps(summary, sort_keys=True))
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()


if __name__ == "__main__":
    main()
