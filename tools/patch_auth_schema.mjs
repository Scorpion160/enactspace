import fs from 'node:fs';
const p = 'C:/Users/DIOP/Documents/EnactSpaceRecovery/enactspace-20260927/backend/app/schemas/auth.py';
let s = fs.readFileSync(p, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
s = s.replace(
  /class LoginRequest\(BaseModel\):[\s\S]*?\n\n(?=class TokenResponse)/,
  `class LoginRequest(BaseModel):\n    identifier: str | None = None\n    email: str | None = None\n    password: str\n    platform: Literal["web", "android", "ios", "api", "unknown"] | None = None\n\n`,
);
s = s.replace(
  /class JoinRequestCreate\(BaseModel\):[\s\S]*?\n\n(?=class JoinRequestRead)/,
  `class JoinRequestCreate(BaseModel):\n    profile_type: str = "enacteur"\n    gender: str | None = None\n    first_name: str\n    last_name: str\n    username: str\n    email: EmailStr\n    password: str\n    phone: str\n    photo_url: str | None = None\n    department: str | None = None\n    level: str | None = None\n    promotion: str | None = None\n    enactus_join_year: int | None = None\n    skills: str | None = None\n    linkedin_url: str | None = None\n    github_url: str | None = None\n    portfolio_url: str | None = None\n    motivation: str | None = None\n\n`,
);
fs.writeFileSync(p, s.replace(/\n+$/, '\n'), 'utf8');
console.log('auth schema patched');
