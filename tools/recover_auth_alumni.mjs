import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const read = (rel) => fs.readFileSync(path.join(ROOT, rel), 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const write = (rel, text) => fs.writeFileSync(path.join(ROOT, rel), text.replace(/\r\n/g, '\n').replace(/\n+$/, '\n'), 'utf8');
function replaceOnce(text, oldText, newText, rel) {
  if (!text.includes(oldText)) throw new Error(`marker missing in ${rel}: ${oldText.slice(0, 80)}`);
  return text.replace(oldText, newText);
}

let rel = 'backend/app/models/user.py';
let text = read(rel);
if (!text.includes('username: Mapped[')) {
  const marker = `    email: Mapped[str] = mapped_column(\n        String(150),\n        nullable=False,\n        unique=True,\n        index=True,\n    )\n`;
  text = replaceOnce(text, marker, marker + `\n    username: Mapped[str | None] = mapped_column(String(80), nullable=True)\n`, rel);
}
write(rel, text);
rel = 'backend/app/models/alumni.py';
text = read(rel);
text = text.replace(
  'from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean',
  'from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean, Integer',
);
if (!text.includes('enactus_join_year: Mapped[')) {
  const marker = '    graduation_year: Mapped[int | None] = mapped_column(nullable=True)\n';
  text = replaceOnce(
    text,
    marker,
    marker + '    enactus_join_year: Mapped[int | None] = mapped_column(Integer, nullable=True)\n',
    rel,
  );
}
write(rel, text);

rel = 'backend/app/schemas/auth.py';
text = read(rel);
let start = text.indexOf('class LoginRequest(BaseModel):');
let end = text.indexOf('\n\nclass TokenResponse', start);
text = text.slice(0, start) + `class LoginRequest(BaseModel):\n    identifier: str | None = None\n    email: str | None = None\n    password: str\n    platform: Literal["web", "android", "ios", "api", "unknown"] | None = None\n` + text.slice(end);
start = text.indexOf('class JoinRequestCreate(BaseModel):');
end = text.indexOf('\n\nclass JoinRequestRead', start);
text = text.slice(0, start) + `class JoinRequestCreate(BaseModel):\n    profile_type: str = "enacteur"\n    gender: str | None = None\n    first_name: str\n    last_name: str\n    username: str\n    email: EmailStr\n    password: str\n    phone: str\n    photo_url: str | None = None\n    department: str | None = None\n    level: str | None = None\n    promotion: str | None = None\n    enactus_join_year: int | None = None\n    skills: str | None = None\n    linkedin_url: str | None = None\n    github_url: str | None = None\n    portfolio_url: str | None = None\n    motivation: str | None = None\n` + text.slice(end);
write(rel, text);

rel = 'backend/app/schemas/user.py';
text = read(rel);
let firstDir = text.indexOf('class UserDirectoryRead(BaseModel):');
let beforeDir = text.slice(0, firstDir);
let dirPart = text.slice(firstDir);
if (!beforeDir.includes('    enactus_join_year: Optional[int] = None\n')) {
  beforeDir = replaceOnce(
    beforeDir,
    '    promotion: Optional[str] = None\n',
    '    promotion: Optional[str] = None\n    enactus_join_year: Optional[int] = None\n',
    rel,
  );
}
if (!dirPart.includes('    enactus_join_year: Optional[int] = None\n')) {
  dirPart = replaceOnce(
    dirPart,
    '    promotion: Optional[str] = None\n',
    '    promotion: Optional[str] = None\n    enactus_join_year: Optional[int] = None\n',
    rel,
  );
}
text = beforeDir + dirPart;
write(rel, text);

rel = 'backend/app/api/routes/auth.py';
text = read(rel);
text = text.replace('from sqlalchemy import func\n', 'from sqlalchemy import func, or_\n');
if (!text.includes('from app.models.alumni import AlumniProfile\n')) {
  text = text.replace('from app.models.user import User, PasswordResetOtp\n', 'from app.models.user import User, PasswordResetOtp\nfrom app.models.alumni import AlumniProfile\n');
}
start = text.indexOf('def normalize_login_email(');
end = text.indexOf('\n\ndef authenticate_user', start);
const helper = `def normalize_login_identifier(identifier: str | None, email: str | None) -> str:\n    raw = identifier if identifier is not None else email\n    normalized = (raw or "").strip().lower()\n    if not normalized:\n        raise HTTPException(\n            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,\n            detail="Identifiant requis.",\n        )\n    return normalized\n`;
text = text.slice(0, start) + helper + text.slice(end);

text = replaceOnce(
  text,
  `def authenticate_user(email: str, password: str, db: Session) -> User:\n    normalized_email = normalize_login_email(email)\n    user = (\n        db.query(User)\n        .filter(func.lower(User.email) == normalized_email)\n`,
  `def authenticate_user(\n    password: str,\n    db: Session,\n    identifier: str | None = None,\n    email: str | None = None,\n) -> User:\n    normalized_identifier = normalize_login_identifier(identifier, email)\n    user = (\n        db.query(User)\n        .filter(\n            or_(\n                func.lower(User.email) == normalized_identifier,\n                func.lower(User.username) == normalized_identifier,\n            )\n        )\n`,
  rel,
);
text = text.replaceAll('detail="Email ou mot de passe incorrect"', 'detail="Identifiant ou mot de passe incorrect"');
text = replaceOnce(
  text,
  `    user = authenticate_user(\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`,
  `    user = authenticate_user(\n        identifier=payload.identifier,\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`,
  rel,
);
text = text.replace('    gender = payload.gender.strip().lower()\n', '    gender = (payload.gender or "").strip().lower()\n');

const oldJoin = `    first_name = payload.first_name.strip()\n    last_name = payload.last_name.strip()\n    department = optional_text(payload.department)\n    if not first_name or not last_name or not department:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="ComplÃƒÂ©tez au moins identitÃƒÂ©, email et filiÃƒÂ¨re",\n        )\n\n    normalized_email = payload.email.strip().lower()\n    existing = db.query(User).filter(func.lower(User.email) == normalized_email).first()\n    if existing:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un compte existe dÃƒÂ©jÃƒÂ  avec cet email",\n        )\n`;
const newJoin = `    first_name = payload.first_name.strip()\n    last_name = payload.last_name.strip()\n    username = payload.username.strip()\n    phone = payload.phone.strip()\n    department = optional_text(payload.department)\n    promotion = optional_text(payload.promotion)\n    if not first_name or not last_name or not department:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="ComplÃƒÂ©tez au moins identitÃƒÂ©, email et filiÃƒÂ¨re",\n        )\n    if not username or not phone:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Le nom dÃ¢â‚¬â„¢utilisateur et le tÃƒÂ©lÃƒÂ©phone sont obligatoires",\n        )\n    if profile_type == "alumni" and (not promotion or payload.enactus_join_year is None):\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un Alumni doit renseigner promotion et annÃƒÂ©e dÃ¢â‚¬â„¢entrÃƒÂ©e ÃƒÂ  Enactus ESP",\n        )\n\n    normalized_email = payload.email.strip().lower()\n    normalized_username = username.lower()\n    existing = db.query(User).filter(\n        or_(\n            func.lower(User.email) == normalized_email,\n            func.lower(User.username) == normalized_username,\n        )\n    ).first()\n    if existing:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un compte existe dÃƒÂ©jÃƒÂ  avec cet email ou ce nom dÃ¢â‚¬â„¢utilisateur",\n        )\n`;
text = replaceOnce(text, oldJoin, newJoin, rel);
text = replaceOnce(
  text,
  `        email=normalized_email,\n        phone=optional_text(payload.phone),\n`,
  `        email=normalized_email,\n        username=normalized_username,\n        phone=phone,\n`,
  rel,
);
text = text.replace('        promotion=optional_text(payload.promotion),\n', '        promotion=promotion,\n');
text = replaceOnce(
  text,
  `    db.add(user)\n    try:\n        db.commit()\n`,
  `    db.add(user)\n    try:\n        db.flush()\n        if profile_type == "alumni":\n            db.add(\n                AlumniProfile(\n                    user_id=user.id,\n                    enactus_join_year=payload.enactus_join_year,\n                )\n            )\n        db.commit()\n`,
  rel,
);
text = replaceOnce(
  text,
  `    user = authenticate_user(\n        email=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`,
  `    user = authenticate_user(\n        identifier=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`,
  rel,
);
write(rel, text);
console.log('recover_auth_alumni: OK');
