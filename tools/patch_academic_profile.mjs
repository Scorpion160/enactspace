import fs from 'node:fs';
import path from 'node:path';

const root = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const read = rel => fs.readFileSync(path.join(root, rel), 'utf8')
  .replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const write = (rel, text) => fs.writeFileSync(
  path.join(root, rel), text.replace(/\n*$/, '\n'), 'utf8');
const once = (text, before, after, rel) => {
  const count = text.split(before).length - 1;
  if (count !== 1) throw new Error(`${rel}: expected 1 marker, got ${count}`);
  return text.replace(before, after);
};

let user = read('backend/app/models/user.py');
const oldAcademic = `    department: Mapped[str | None] = mapped_column(String(150), nullable=True)
    study_level: Mapped[str | None] = mapped_column(String(100), nullable=True)
    promotion: Mapped[str | None] = mapped_column(String(100), nullable=True)`;
const newAcademic = `    department: Mapped[str | None] = mapped_column(String(150), nullable=True)
    cursus: Mapped[str | None] = mapped_column(String(80), nullable=True)
    study_level: Mapped[str | None] = mapped_column(String(100), nullable=True)
    specialty: Mapped[str | None] = mapped_column(String(150), nullable=True)
    promotion: Mapped[str | None] = mapped_column(String(100), nullable=True)
    academic_confirmed_season_id: Mapped[uuid.UUID | None] = mapped_column(
        GUID(), ForeignKey("seasons.id", ondelete="SET NULL"), nullable=True
    )
    academic_confirmed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)`;
user = once(user, oldAcademic, newAcademic, 'user.py');
write('backend/app/models/user.py', user);

let schema = read('backend/app/schemas/user.py');
schema = once(schema,
`    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None`,
`    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None`, 'schemas/user.py base');
schema = once(schema,
`    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None
    bio: Optional[str] = None`,
`    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None
    bio: Optional[str] = None`, 'schemas/user.py update');
schema = once(schema,
`    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None


class UserRoleAssign`,
`    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None


class UserRoleAssign`, 'schemas/user.py admin');
schema = once(schema,
`    department: Optional[str] = None
    study_level: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None`,
`    department: Optional[str] = None
    cursus: Optional[str] = None
    study_level: Optional[str] = None
    specialty: Optional[str] = None
    promotion: Optional[str] = None
    enactus_join_year: Optional[int] = None`, 'schemas/user.py directory');
write('backend/app/schemas/user.py', schema);

let base = read('backend/app/models/base.py');
base = once(base,
`from app.models.user import User, PasswordResetOtp`,
`from app.models.user import User, PasswordResetOtp
from app.models.academic import UserAcademicHistory`, 'models/base.py');
write('backend/app/models/base.py', base);
