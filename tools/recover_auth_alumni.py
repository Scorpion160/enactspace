from pathlib import Path

ROOT = Path('/src')


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8-sig')


def write(rel, text):
    (ROOT / rel).write_text(text, encoding='utf-8', newline='\n')


def replace_once(text, old, new, rel):
    if old not in text:
        raise RuntimeError(f'marker missing in {rel}: {old[:80]!r}')
    return text.replace(old, new, 1)


# User model: restore the persisted unique username.
rel = 'backend/app/models/user.py'
text = read(rel)
if 'username: Mapped[' not in text:
    marker = '''    email: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
        unique=True,
        index=True,
    )
'''
    replacement = marker + '''\n    username: Mapped[str | None] = mapped_column(String(80), nullable=True)\n'''
    text = replace_once(text, marker, replacement, rel)
write(rel, text)
# Alumni profile: restore year joined Enactus ESP.
rel = 'backend/app/models/alumni.py'
text = read(rel)
text = text.replace(
    'from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean',
    'from sqlalchemy import String, Text, Date, DateTime, ForeignKey, Boolean, Integer',
)
if 'enactus_join_year: Mapped[' not in text:
    marker = '    graduation_year: Mapped[int | None] = mapped_column(nullable=True)\n'
    text = replace_once(
        text,
        marker,
        marker + '    enactus_join_year: Mapped[int | None] = mapped_column(Integer, nullable=True)\n',
        rel,
    )
write(rel, text)

# Auth schemas: match the contract already running in production.
rel = 'backend/app/schemas/auth.py'
text = read(rel)
start = text.index('class LoginRequest(BaseModel):')
end = text.index('\n\nclass TokenResponse', start)
text = text[:start] + '''class LoginRequest(BaseModel):
    identifier: str | None = None
    email: str | None = None
    password: str
    platform: Literal["web", "android", "ios", "api", "unknown"] | None = None
''' + text[end:]
start = text.index('class JoinRequestCreate(BaseModel):')
end = text.index('\n\nclass JoinRequestRead', start)
text = text[:start] + '''class JoinRequestCreate(BaseModel):
    profile_type: str = "enacteur"
    gender: str | None = None
    first_name: str
    last_name: str
    username: str
    email: EmailStr
    password: str
    phone: str
    photo_url: str | None = None
    department: str | None = None
    level: str | None = None
    promotion: str | None = None
    enactus_join_year: int | None = None
    skills: str | None = None
    linkedin_url: str | None = None
    github_url: str | None = None
    portfolio_url: str | None = None
    motivation: str | None = None
''' + text[end:]
write(rel, text)

# User read schemas expose the Alumni join year.
rel = 'backend/app/schemas/user.py'
text = read(rel)
if '    enactus_join_year: Optional[int] = None\n' not in text:
    marker = '    promotion: Optional[str] = None\n'
    text = replace_once(text, marker, marker + '    enactus_join_year: Optional[int] = None\n', rel)
# Add the same field to directory payloads if still missing there.
needle = '''class UserDirectoryRead(BaseModel):'''
pos = text.index(needle)
tail = text[pos:]
if '    enactus_join_year: Optional[int] = None\n' not in tail:
    marker = '    promotion: Optional[str] = None\n'
    tail = replace_once(tail, marker, marker + '    enactus_join_year: Optional[int] = None\n', rel)
    text = text[:pos] + tail
write(rel, text)

# Auth route: restore username/email identifier login and Alumni persistence.
rel = 'backend/app/api/routes/auth.py'
text = read(rel)
text = text.replace('from sqlalchemy import func\n', 'from sqlalchemy import func, or_\n')
if 'from app.models.alumni import AlumniProfile\n' not in text:
    text = text.replace(
        'from app.models.user import User, PasswordResetOtp\n',
        'from app.models.user import User, PasswordResetOtp\nfrom app.models.alumni import AlumniProfile\n',
        1,
    )
start = text.index('def normalize_login_email(')
end = text.index('\n\ndef authenticate_user', start)
helper = '''def normalize_login_identifier(identifier: str | None, email: str | None) -> str:
    raw = identifier if identifier is not None else email
    normalized = (raw or "").strip().lower()
    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Identifiant requis.",
        )
    return normalized
'''
text = text[:start] + helper + text[end:]
text = replace_once(
    text,
    '''def authenticate_user(email: str, password: str, db: Session) -> User:
    normalized_email = normalize_login_email(email)
    user = (
        db.query(User)
        .filter(func.lower(User.email) == normalized_email)
''',
    '''def authenticate_user(
    password: str,
    db: Session,
    identifier: str | None = None,
    email: str | None = None,
) -> User:
    normalized_identifier = normalize_login_identifier(identifier, email)
    user = (
        db.query(User)
        .filter(
            or_(
                func.lower(User.email) == normalized_identifier,
                func.lower(User.username) == normalized_identifier,
            )
        )
''',
    rel,
)
text = text.replace('detail="Email ou mot de passe incorrect"', 'detail="Identifiant ou mot de passe incorrect"')
text = replace_once(
    text,
    '''    user = authenticate_user(
        email=payload.email,
        password=payload.password,
        db=db,
    )
''',
    '''    user = authenticate_user(
        identifier=payload.identifier,
        email=payload.email,
        password=payload.password,
        db=db,
    )
''',
    rel,
)
text = text.replace(
    '    gender = payload.gender.strip().lower()\n',
    '    gender = (payload.gender or "").strip().lower()\n',
    1,
)
old = '''    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()
    department = optional_text(payload.department)
    if not first_name or not last_name or not department:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complétez au moins identité, email et filière",
        )

    normalized_email = payload.email.strip().lower()
    existing = db.query(User).filter(func.lower(User.email) == normalized_email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email",
        )
'''
new = '''    first_name = payload.first_name.strip()
    last_name = payload.last_name.strip()
    username = payload.username.strip()
    phone = payload.phone.strip()
    department = optional_text(payload.department)
    promotion = optional_text(payload.promotion)
    if not first_name or not last_name or not department:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Complétez au moins identité, email et filière",
        )
    if not username or not phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le nom d’utilisateur et le téléphone sont obligatoires",
        )
    if profile_type == "alumni" and (not promotion or payload.enactus_join_year is None):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un Alumni doit renseigner promotion et année d’entrée à Enactus ESP",
        )

    normalized_email = payload.email.strip().lower()
    normalized_username = username.lower()
    existing = db.query(User).filter(
        or_(
            func.lower(User.email) == normalized_email,
            func.lower(User.username) == normalized_username,
        )
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Un compte existe déjà avec cet email ou ce nom d’utilisateur",
        )
'''
text = replace_once(text, old, new, rel)
text = replace_once(
    text,
    '''        email=normalized_email,
        phone=optional_text(payload.phone),
''',
    '''        email=normalized_email,
        username=normalized_username,
        phone=phone,
''',
    rel,
)
text = text.replace('        promotion=optional_text(payload.promotion),\n', '        promotion=promotion,\n', 1)
text = replace_once(
    text,
    '''    db.add(user)
    try:
        db.commit()
''',
    '''    db.add(user)
    try:
        db.flush()
        if profile_type == "alumni":
            db.add(
                AlumniProfile(
                    user_id=user.id,
                    enactus_join_year=payload.enactus_join_year,
                )
            )
        db.commit()
''',
    rel,
)
text = replace_once(
    text,
    '''    user = authenticate_user(
        email=form_data.username,
        password=form_data.password,
        db=db,
    )
''',
    '''    user = authenticate_user(
        identifier=form_data.username,
        password=form_data.password,
        db=db,
    )
''',
    rel,
)
write(rel, text)

print('recover_auth_alumni: OK')
