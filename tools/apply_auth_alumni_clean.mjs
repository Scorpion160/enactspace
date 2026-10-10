import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const file = (rel) => path.join(ROOT, rel);
const read = (rel) => fs.readFileSync(file(rel), 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const write = (rel, value) => fs.writeFileSync(file(rel), value.replace(/\n+$/, '\n'), 'utf8');
function replaceOnce(value, oldValue, newValue, label) {
  const next = value.replace(oldValue, newValue);
  if (next === value) throw new Error(`replacement failed: ${label}`);
  return next;
}

let rel = 'backend/app/models/user.py';
let s = read(rel);
s = replaceOnce(s, '    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)\n', '    username: Mapped[str | None] = mapped_column(String(80), nullable=True)\n    phone: Mapped[str | None] = mapped_column(String(30), nullable=True)\n', 'user username');
s = replaceOnce(s, '        Index("ux_users_lower_email", func.lower(email), unique=True),\n', '        Index("ux_users_lower_email", func.lower(email), unique=True),\n        Index("ux_users_lower_username", func.lower(username), unique=True),\n', 'username index');
write(rel, s);
rel = 'backend/app/models/alumni.py';
s = read(rel);
s = s.replace('from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean', 'from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean, Integer');
s = replaceOnce(s, '    graduation_year: Mapped[int | None] = mapped_column(nullable=True)\n', '    graduation_year: Mapped[int | None] = mapped_column(nullable=True)\n    enactus_join_year: Mapped[int | None] = mapped_column(Integer, nullable=True)\n', 'alumni join year');
write(rel, s);

rel = 'backend/app/schemas/auth.py';
s = read(rel);
s = s.replace(/class LoginRequest\(BaseModel\):[\s\S]*?\n\n(?=class TokenResponse)/, `class LoginRequest(BaseModel):\n    identifier: str | None = None\n    email: str | None = None\n    password: str\n    platform: Literal["web", "android", "ios", "api", "unknown"] | None = None\n\n`);
s = s.replace(/class JoinRequestCreate\(BaseModel\):[\s\S]*?\n\n(?=class JoinRequestRead)/, `class JoinRequestCreate(BaseModel):\n    profile_type: str = "enacteur"\n    gender: str | None = None\n    first_name: str\n    last_name: str\n    username: str\n    email: EmailStr\n    password: str\n    phone: str\n    photo_url: str | None = None\n    department: str | None = None\n    level: str | None = None\n    promotion: str | None = None\n    enactus_join_year: int | None = None\n    skills: str | None = None\n    linkedin_url: str | None = None\n    github_url: str | None = None\n    portfolio_url: str | None = None\n    motivation: str | None = None\n\n`);
write(rel, s);
rel = 'backend/app/schemas/user.py';
s = read(rel);
s = s.replace('    email: str\n    phone: Optional[str] = None\n', '    email: str\n    username: Optional[str] = None\n    phone: Optional[str] = None\n');
s = s.replace('    promotion: Optional[str] = None\n    bio: Optional[str] = None\n', '    promotion: Optional[str] = None\n    enactus_join_year: Optional[int] = None\n    bio: Optional[str] = None\n');
const directoryStart = s.indexOf('class UserDirectoryRead(BaseModel):');
let before = s.slice(0, directoryStart);
let directory = s.slice(directoryStart);
directory = directory.replace('    email: str\n    phone: Optional[str] = None\n', '    email: str\n    username: Optional[str] = None\n    phone: Optional[str] = None\n');
directory = directory.replace('    promotion: Optional[str] = None\n    bio: Optional[str] = None\n', '    promotion: Optional[str] = None\n    enactus_join_year: Optional[int] = None\n    bio: Optional[str] = None\n');
write(rel, before + directory);

rel = 'backend/app/api/routes/auth.py';
s = read(rel);
s = s.replace('from sqlalchemy import func\n', 'from sqlalchemy import func, or_\n');
s = s.replace('from app.models.user import User, PasswordResetOtp\n', 'from app.models.user import User, PasswordResetOtp\nfrom app.models.alumni import AlumniProfile\n');
s = s.replace(/def normalize_login_email\([\s\S]*?\n\n(?=def authenticate_user)/, `def normalize_login_identifier(identifier: str | None, email: str | None) -> str:\n    raw = identifier if identifier is not None else email\n    normalized = (raw or "").strip().lower()\n    if not normalized:\n        raise HTTPException(\n            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,\n            detail="Identifiant requis.",\n        )\n    return normalized\n\n`);
s = replaceOnce(s, `def authenticate_user(email: str, password: str, db: Session) -> User:\n    normalized_email = normalize_login_email(email)\n    user = (\n        db.query(User)\n        .filter(func.lower(User.email) == normalized_email)\n`, `def authenticate_user(\n    password: str,\n    db: Session,\n    identifier: str | None = None,\n    email: str | None = None,\n) -> User:\n    normalized_identifier = normalize_login_identifier(identifier, email)\n    user = (\n        db.query(User)\n        .filter(or_(\n            func.lower(User.email) == normalized_identifier,\n            func.lower(User.username) == normalized_identifier,\n        ))\n`, 'authenticate user');
s = s.replaceAll('detail="Email ou mot de passe incorrect"', 'detail="Identifiant ou mot de passe incorrect"');
s = replaceOnce(s, `    user = authenticate_user(\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`, `    user = authenticate_user(\n        identifier=payload.identifier,\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`, 'login request');
s = s.replace('    gender = payload.gender.strip().lower()\n', '    gender = (payload.gender or "").strip().lower()\n');
const joinBlock = `    first_name = payload.first_name.strip()\n    last_name = payload.last_name.strip()\n    username = payload.username.strip()\n    phone = payload.phone.strip()\n    department = optional_text(payload.department)\n    promotion = optional_text(payload.promotion)\n    if not first_name or not last_name or not department:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Complétez au moins identité, email et filière",\n        )\n    if not username or not phone:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Le nom d'utilisateur et le téléphone sont obligatoires",\n        )\n    if profile_type == "alumni" and (not promotion or payload.enactus_join_year is None):\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un Alumni doit renseigner promotion et année d'entrée à Enactus ESP",\n        )\n\n    normalized_email = payload.email.strip().lower()\n    normalized_username = username.lower()\n    existing = db.query(User).filter(or_(\n        func.lower(User.email) == normalized_email,\n        func.lower(User.username) == normalized_username,\n    )).first()\n    if existing:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un compte existe déjà avec cet email ou ce nom d'utilisateur",\n        )\n\n`;
s = s.replace(/    first_name = payload\.first_name\.strip\(\)[\s\S]*?\n(?=    user = User\()/, joinBlock);
s = replaceOnce(s, '        email=normalized_email,\n        phone=optional_text(payload.phone),\n', '        email=normalized_email,\n        username=normalized_username,\n        phone=phone,\n', 'user identity');
s = s.replace('        promotion=optional_text(payload.promotion),\n', '        promotion=promotion,\n');
s = replaceOnce(s, `    db.add(user)\n    try:\n        db.commit()\n`, `    db.add(user)\n    try:\n        db.flush()\n        if profile_type == "alumni":\n            db.add(AlumniProfile(\n                user_id=user.id,\n                enactus_join_year=payload.enactus_join_year,\n            ))\n        db.commit()\n`, 'alumni profile persistence');
s = replaceOnce(s, `    user = authenticate_user(\n        email=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`, `    user = authenticate_user(\n        identifier=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`, 'swagger identifier');
write(rel, s);

console.log('apply_auth_alumni_clean: OK');
