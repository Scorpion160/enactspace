import fs from 'node:fs';
import path from 'node:path';

const ROOT = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927';
const rel = 'backend/app/api/routes/auth.py';
const file = path.join(ROOT, rel);
let text = fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');

function mustReplace(oldValue, newValue, label) {
  const next = text.replace(oldValue, newValue);
  if (next === text) throw new Error(`replacement failed: ${label}`);
  text = next;
}

text = text.replace('from sqlalchemy import func\n', 'from sqlalchemy import func, or_\n');
if (!text.includes('from app.models.alumni import AlumniProfile\n')) {
  text = text.replace(
    'from app.models.user import User, PasswordResetOtp\n',
    'from app.models.user import User, PasswordResetOtp\nfrom app.models.alumni import AlumniProfile\n',
  );
}
mustReplace(
  /def normalize_login_email\([\s\S]*?\n\n(?=def authenticate_user)/,
  `def normalize_login_identifier(identifier: str | None, email: str | None) -> str:\n    raw = identifier if identifier is not None else email\n    normalized = (raw or "").strip().lower()\n    if not normalized:\n        raise HTTPException(\n            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,\n            detail="Identifiant requis.",\n        )\n    return normalized\n\n`,
  'normalize helper',
);

mustReplace(
  `def authenticate_user(email: str, password: str, db: Session) -> User:\n    normalized_email = normalize_login_email(email)\n    user = (\n        db.query(User)\n        .filter(func.lower(User.email) == normalized_email)\n`,
  `def authenticate_user(\n    password: str,\n    db: Session,\n    identifier: str | None = None,\n    email: str | None = None,\n) -> User:\n    normalized_identifier = normalize_login_identifier(identifier, email)\n    user = (\n        db.query(User)\n        .filter(or_(\n            func.lower(User.email) == normalized_identifier,\n            func.lower(User.username) == normalized_identifier,\n        ))\n`,
  'authenticate query',
);
text = text.replaceAll('detail="Email ou mot de passe incorrect"', 'detail="Identifiant ou mot de passe incorrect"');
mustReplace(
  `    user = authenticate_user(\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`,
  `    user = authenticate_user(\n        identifier=payload.identifier,\n        email=payload.email,\n        password=payload.password,\n        db=db,\n    )\n`,
  'login payload',
);
text = text.replace('    gender = payload.gender.strip().lower()\n', '    gender = (payload.gender or "").strip().lower()\n');

const joinBlock = `    first_name = payload.first_name.strip()\n    last_name = payload.last_name.strip()\n    username = payload.username.strip()\n    phone = payload.phone.strip()\n    department = optional_text(payload.department)\n    promotion = optional_text(payload.promotion)\n    if not first_name or not last_name or not department:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Complétez au moins identité, email et filière",\n        )\n    if not username or not phone:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Le nom d’utilisateur et le téléphone sont obligatoires",\n        )\n    if profile_type == "alumni" and (not promotion or payload.enactus_join_year is None):\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un Alumni doit renseigner promotion et année d’entrée à Enactus ESP",\n        )\n\n    normalized_email = payload.email.strip().lower()\n    normalized_username = username.lower()\n    existing = db.query(User).filter(or_(\n        func.lower(User.email) == normalized_email,\n        func.lower(User.username) == normalized_username,\n    )).first()\n    if existing:\n        raise HTTPException(\n            status_code=status.HTTP_400_BAD_REQUEST,\n            detail="Un compte existe déjà avec cet email ou ce nom d’utilisateur",\n        )\n\n`;
mustReplace(
  /    first_name = payload\.first_name\.strip\(\)[\s\S]*?\n(?=    user = User\()/,
  joinBlock,
  'join validation',
);
mustReplace(
  `        email=normalized_email,\n        phone=optional_text(payload.phone),\n`,
  `        email=normalized_email,\n        username=normalized_username,\n        phone=phone,\n`,
  'user username phone',
);
text = text.replace('        promotion=optional_text(payload.promotion),\n', '        promotion=promotion,\n');
mustReplace(
  `    db.add(user)\n    try:\n        db.commit()\n`,
  `    db.add(user)\n    try:\n        db.flush()\n        if profile_type == "alumni":\n            db.add(AlumniProfile(\n                user_id=user.id,\n                enactus_join_year=payload.enactus_join_year,\n            ))\n        db.commit()\n`,
  'alumni persistence',
);
mustReplace(
  `    user = authenticate_user(\n        email=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`,
  `    user = authenticate_user(\n        identifier=form_data.username,\n        password=form_data.password,\n        db=db,\n    )\n`,
  'swagger login',
);
text = text.replace(/\n+$/, '\n');
fs.writeFileSync(file, text, 'utf8');
console.log('recover_auth_route: OK');
