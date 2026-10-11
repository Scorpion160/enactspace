import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const write = (rel, text) => fs.writeFileSync(path.join(ROOT, rel), text.replace(/\r\n/g, '\n').replace(/\n*$/, '\n'), 'utf8');
function replaceOnce(text, oldText, newText, rel) {
  if (!text.includes(oldText)) throw new Error(`marker missing in ${rel}: ${oldText.slice(0, 100)}`);
  return text.replace(oldText, newText);
}

const outputs = new Map();

// MODEL
{
  const rel = 'backend/app/models/recruitment.py';
  let t = read(rel);
  t = replaceOnce(
    t,
    'from sqlalchemy import CheckConstraint, Index, String, Text, Date, DateTime, ForeignKey, Boolean, Numeric, UniqueConstraint, func',
    'from sqlalchemy import CheckConstraint, Index, String, Text, Date, DateTime, ForeignKey, Boolean, Integer, JSON, Numeric, UniqueConstraint, func',
    rel,
  );
  t = replaceOnce(
    t,
    '    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)\n    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)\n\n    is_active: Mapped[bool] = mapped_column(Boolean, default=True)',
    `    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)

    # Internal recruitment preparation. These fields never belong to the public campaign payload.
    target_headcount: Mapped[int | None] = mapped_column(Integer, nullable=True)
    positions: Mapped[list[dict] | None] = mapped_column(JSON, nullable=True)
    target_profiles: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    communication_actions: Mapped[list[dict] | None] = mapped_column(JSON, nullable=True)
    interview_questions: Mapped[list[dict] | None] = mapped_column(JSON, nullable=True)

    is_active: Mapped[bool] = mapped_column(Boolean, default=True)`,
    rel,
  );
  outputs.set(rel, t);
}

// SCHEMA
{
  const rel = 'backend/app/schemas/recruitment.py';
  let t = read(rel);
  t = replaceOnce(
    t,
    'from pydantic import BaseModel, EmailStr',
    'from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator',
    rel,
  );
  const marker = '\n\nclass RecruitmentCampaignCreate(BaseModel):\n';
  const block = `

def _clean_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    return cleaned or None


class RecruitmentPosition(BaseModel):
    title: str
    headcount: int = Field(default=1, ge=1)
    description: Optional[str] = None
    target_profile: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "title" not in value:
            value = dict(value)
            for alias in ("name", "position", "label"):
                if alias in value:
                    value["title"] = value[alias]
                    break
        return value

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("Le poste ne peut pas être vide")
        return cleaned

    @field_validator("description", "target_profile")
    @classmethod
    def clean_optional_fields(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentCommunicationAction(BaseModel):
    action: str
    channel: Optional[str] = None
    owner: Optional[str] = None
    timing: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "action" not in value:
            value = dict(value)
            for alias in ("title", "name", "label", "text"):
                if alias in value:
                    value["action"] = value[alias]
                    break
        return value

    @field_validator("action")
    @classmethod
    def validate_action(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("L'action de communication ne peut pas être vide")
        return cleaned

    @field_validator("channel", "owner", "timing")
    @classmethod
    def clean_optional_fields(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentInterviewQuestion(BaseModel):
    question: str
    category: Optional[str] = None

    @model_validator(mode="before")
    @classmethod
    def normalize_aliases(cls, value):
        if isinstance(value, dict) and "question" not in value:
            value = dict(value)
            for alias in ("text", "title", "label"):
                if alias in value:
                    value["question"] = value[alias]
                    break
        return value

    @field_validator("question")
    @classmethod
    def validate_question(cls, value: str) -> str:
        cleaned = value.strip()
        if not cleaned:
            raise ValueError("La question d'entretien ne peut pas être vide")
        return cleaned

    @field_validator("category")
    @classmethod
    def clean_category(cls, value: str | None) -> str | None:
        return _clean_optional_text(value)


class RecruitmentCampaignPublicRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    title: str
    description: Optional[str]
    start_date: Optional[date]
    end_date: Optional[date]
    is_active: bool
    created_by: Optional[UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
`;
  t = replaceOnce(t, marker, block + marker, rel);

  t = replaceOnce(
    t,
    '    end_date: Optional[date] = None\n    is_active: bool = True',
    `    end_date: Optional[date] = None
    target_headcount: Optional[int] = Field(default=None, ge=1)
    positions: list[RecruitmentPosition] = Field(default_factory=list)
    target_profiles: list[str] = Field(default_factory=list)
    communication_actions: list[RecruitmentCommunicationAction] = Field(default_factory=list)
    interview_questions: list[RecruitmentInterviewQuestion] = Field(default_factory=list)
    is_active: bool = True

    @field_validator("target_profiles")
    @classmethod
    def clean_target_profiles(cls, values: list[str]) -> list[str]:
        return [cleaned for value in values if (cleaned := value.strip())]`,
    rel,
  );

  t = replaceOnce(
    t,
    '    end_date: Optional[date] = None\n    is_active: Optional[bool] = None',
    `    end_date: Optional[date] = None
    target_headcount: Optional[int] = Field(default=None, ge=1)
    positions: Optional[list[RecruitmentPosition]] = None
    target_profiles: Optional[list[str]] = None
    communication_actions: Optional[list[RecruitmentCommunicationAction]] = None
    interview_questions: Optional[list[RecruitmentInterviewQuestion]] = None
    is_active: Optional[bool] = None

    @field_validator("target_profiles")
    @classmethod
    def clean_target_profiles(cls, values: list[str] | None) -> list[str] | None:
        if values is None:
            return None
        return [cleaned for value in values if (cleaned := value.strip())]`,
    rel,
  );

  const oldRead = `class RecruitmentCampaignRead(BaseModel):
    id: UUID
    season_id: Optional[UUID]
    title: str
    description: Optional[str]
    start_date: Optional[date]
    end_date: Optional[date]
    is_active: bool
    created_by: Optional[UUID]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True`;
  const newRead = `class RecruitmentCampaignRead(RecruitmentCampaignPublicRead):
    target_headcount: Optional[int] = None
    positions: Optional[list[RecruitmentPosition]] = None
    target_profiles: Optional[list[str]] = None
    communication_actions: Optional[list[RecruitmentCommunicationAction]] = None
    interview_questions: Optional[list[RecruitmentInterviewQuestion]] = None`;
  t = replaceOnce(t, oldRead, newRead, rel);
  outputs.set(rel, t);
}

// ROUTE
{
  const rel = 'backend/app/api/routes/recruitment.py';
  let t = read(rel);
  t = replaceOnce(
    t,
    '    RecruitmentCampaignRead,\n    ApplicationCreate,',
    '    RecruitmentCampaignRead,\n    RecruitmentCampaignPublicRead,\n    ApplicationCreate,',
    rel,
  );

  const constantsMarker = 'RECRUITMENT_NOTIFICATION_ROLES = RECRUITMENT_ACCESS_ROLES\n';
  const onboarding = `MEMBER_ONBOARDING_CHECKLIST = [
    {
        "id": "beginner-guide",
        "title": "Guide du débutant",
        "route": "/help",
    },
    {
        "id": "academy-new-enacteur",
        "title": "Parcours Academy — Nouveau Enacteur",
        "route": "/academy",
    },
    {
        "id": "discover-pole",
        "title": "Découvrir mon pôle",
        "route": "/poles",
    },
    {
        "id": "meet-team",
        "title": "Découvrir l'équipe et mon parrain",
        "route": "/members",
    },
    {
        "id": "useful-documents",
        "title": "Consulter les documents utiles",
        "route": "/documents",
    },
    {
        "id": "first-project",
        "title": "Rejoindre un projet ou une première mission",
        "route": "/projects",
    },
]


def member_onboarding_payload() -> dict:
    return {
        "academy_path_id": "new-enacteur",
        "academy_path_title": "Nouveau Enacteur",
        "checklist": [dict(item) for item in MEMBER_ONBOARDING_CHECKLIST],
    }


`;
  t = replaceOnce(t, constantsMarker, onboarding + constantsMarker, rel);

  t = replaceOnce(
    t,
    '        end_date=payload.end_date,\n        is_active=payload.is_active,',
    `        end_date=payload.end_date,
        target_headcount=payload.target_headcount,
        positions=[item.model_dump() for item in payload.positions],
        target_profiles=payload.target_profiles,
        communication_actions=[item.model_dump() for item in payload.communication_actions],
        interview_questions=[item.model_dump() for item in payload.interview_questions],
        is_active=payload.is_active,`,
    rel,
  );

  t = replaceOnce(
    t,
    '@router.get("/campaigns/public", response_model=list[RecruitmentCampaignRead])',
    '@router.get("/campaigns/public", response_model=list[RecruitmentCampaignPublicRead])',
    rel,
  );

  t = replaceOnce(
    t,
    '    if payload.end_date is not None:\n        campaign.end_date = payload.end_date\n\n    if payload.is_active is not None:',
    `    if payload.end_date is not None:
        campaign.end_date = payload.end_date

    if payload.target_headcount is not None:
        campaign.target_headcount = payload.target_headcount

    if payload.positions is not None:
        campaign.positions = [item.model_dump() for item in payload.positions]

    if payload.target_profiles is not None:
        campaign.target_profiles = payload.target_profiles

    if payload.communication_actions is not None:
        campaign.communication_actions = [
            item.model_dump() for item in payload.communication_actions
        ]

    if payload.interview_questions is not None:
        campaign.interview_questions = [
            item.model_dump() for item in payload.interview_questions
        ]

    if payload.is_active is not None:`,
    rel,
  );

  // Existing compatible user: ensure member role and expose onboarding.
  t = replaceOnce(
    t,
    '        application.converted_user_id = existing_user.id\n        existing_user.gender = existing_user.gender or application.gender',
    '        application.converted_user_id = existing_user.id\n        ensure_user_role(db, existing_user, BASE_ACTIVE_ROLE)\n        existing_user.gender = existing_user.gender or application.gender',
    rel,
  );

  t = replaceOnce(
    t,
    '            "project_id": None,\n        }\n\n    user = User(',
    '            "project_id": None,\n            "onboarding": member_onboarding_payload(),\n        }\n\n    user = User(',
    rel,
  );

  // IntegrityError compatible-user branch.
  const errorBranch = `        application.converted_user_id = existing_user.id
        application.updated_at = utc_now()`;
  t = replaceOnce(
    t,
    errorBranch,
    `        application.converted_user_id = existing_user.id
        ensure_user_role(db, existing_user, BASE_ACTIVE_ROLE)
        application.updated_at = utc_now()`,
    rel,
  );
  t = replaceOnce(
    t,
    '            "project_id": None,\n        }\n    ensure_user_role(db, user, BASE_ACTIVE_ROLE)',
    '            "project_id": None,\n            "onboarding": member_onboarding_payload(),\n        }\n    ensure_user_role(db, user, BASE_ACTIVE_ROLE)',
    rel,
  );

  t = replaceOnce(
    t,
    '        "project_id": str(payload.project_id) if payload.project_id else None,\n    }\n',
    '        "project_id": str(payload.project_id) if payload.project_id else None,\n        "onboarding": member_onboarding_payload(),\n    }\n',
    rel,
  );
  outputs.set(rel, t);
}

// MIGRATION
outputs.set('backend/alembic/versions/20260926_0013_recruitment_preparation.py', `"""Add structured recruitment preparation fields.

Revision ID: 20260926_0013
Revises: 20260926_0012
"""

from alembic import op
import sqlalchemy as sa

revision = "20260926_0013"
down_revision = "20260926_0012"
branch_labels = None
depends_on = None

FIELDS = {
    "target_headcount": sa.Integer(),
    "positions": sa.JSON(),
    "target_profiles": sa.JSON(),
    "communication_actions": sa.JSON(),
    "interview_questions": sa.JSON(),
}


def _columns() -> set[str]:
    return {
        item["name"]
        for item in sa.inspect(op.get_bind()).get_columns("recruitment_campaigns")
    }


def upgrade() -> None:
    columns = _columns()
    for name, column_type in FIELDS.items():
        if name not in columns:
            op.add_column(
                "recruitment_campaigns",
                sa.Column(name, column_type, nullable=True),
            )


def downgrade() -> None:
    columns = _columns()
    for name in reversed(tuple(FIELDS)):
        if name in columns:
            with op.batch_alter_table("recruitment_campaigns") as batch:
                batch.drop_column(name)
`);

// TEST
outputs.set('backend/test_recruitment_preparation.py', `import unittest

from pydantic import ValidationError

from app.api.routes import academy, recruitment
from app.schemas.recruitment import (
    RecruitmentCampaignCreate,
    RecruitmentCampaignPublicRead,
    RecruitmentCommunicationAction,
    RecruitmentInterviewQuestion,
    RecruitmentPosition,
)


class RecruitmentPreparationTests(unittest.TestCase):
    def test_campaign_preparation_is_structured_and_profiles_are_cleaned(self):
        payload = RecruitmentCampaignCreate(
            title="Campagne 2026",
            target_headcount=20,
            positions=[
                {"title": "  Responsable terrain  ", "headcount": 2},
            ],
            target_profiles=["  Technique  ", " ", "Gestion"],
            communication_actions=[
                {"action": "  Publication de lancement  ", "channel": " Instagram "},
            ],
            interview_questions=[
                {"question": "  Pourquoi Enactus ?  ", "category": " Motivation "},
            ],
        )
        self.assertEqual(payload.positions[0].title, "Responsable terrain")
        self.assertEqual(payload.positions[0].headcount, 2)
        self.assertEqual(payload.target_profiles, ["Technique", "Gestion"])
        self.assertEqual(payload.communication_actions[0].action, "Publication de lancement")
        self.assertEqual(payload.communication_actions[0].channel, "Instagram")
        self.assertEqual(payload.interview_questions[0].question, "Pourquoi Enactus ?")
        self.assertEqual(payload.interview_questions[0].category, "Motivation")

    def test_position_headcount_must_be_positive(self):
        with self.assertRaises(ValidationError):
            RecruitmentPosition(title="Membre terrain", headcount=0)
        with self.assertRaises(ValidationError):
            RecruitmentCampaignCreate(title="Campagne", target_headcount=0)

    def test_structured_required_text_rejects_whitespace_only(self):
        invalid_factories = (
            lambda: RecruitmentPosition(title="   "),
            lambda: RecruitmentCommunicationAction(action="   "),
            lambda: RecruitmentInterviewQuestion(question="   "),
        )
        for factory in invalid_factories:
            with self.subTest(factory=factory):
                with self.assertRaises(ValidationError):
                    factory()

    def test_public_campaign_schema_does_not_expose_internal_preparation(self):
        internal_fields = {
            "target_headcount",
            "positions",
            "target_profiles",
            "communication_actions",
            "interview_questions",
        }
        self.assertTrue(
            internal_fields.isdisjoint(RecruitmentCampaignPublicRead.model_fields)
        )

    def test_academy_new_member_path_is_the_enacteur_path(self):
        path = academy.ROLE_BASED_PATHS["enacteur"]
        self.assertEqual(path["id"], "new-enacteur")
        self.assertEqual(path["title"], "Nouveau Enacteur")
        self.assertTrue(path["course_ids"])

    def test_member_onboarding_payload_points_to_existing_product_surfaces(self):
        payload = recruitment.member_onboarding_payload()
        self.assertEqual(payload["academy_path_id"], "new-enacteur")
        routes = {item["route"] for item in payload["checklist"]}
        self.assertEqual(
            routes,
            {"/help", "/academy", "/poles", "/members", "/documents", "/projects"},
        )


if __name__ == "__main__":
    unittest.main()
`);

for (const [rel, text] of outputs) {
  write(rel, text);
}
console.log(`recover_recruitment_prep: wrote ${outputs.size} files`);
