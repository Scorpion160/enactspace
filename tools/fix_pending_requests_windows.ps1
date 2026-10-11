param([string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927')
$ErrorActionPreference = 'Stop'
$commit = '3aca4c63bdcaa93555de9d33f9817d39e15e596f'
$files = @(
    @{ Path='frontend/lib/features/members/screens/members_screen.dart'; Old='bdb9fb89f08ea2157d6de4581bb6f4d20a5476479e819e350c27bea03a85ea72'; New='e75394befb73f55dceca9fbd324df588ba0e998b47cbefc170a2bfb7243727da' },
    @{ Path='frontend/lib/features/members/models/member_model.dart'; Old='aab2026cb9129d41e533dddf8c8e7053bab79bac45aa0f359f9821dc5238c106'; New='b28d2a908a9db02ff4ea13004688a355d4edb2b035c23f86138a70c357d93c6e' },
    @{ Path='frontend/test/member_join_requests_test.dart'; Old=$null; New='ff36ac991b55cc38973ea6920446cac73db78566445c1fba970cfbe5d19cb3a7' }
)
function Get-CanonicalHash([string]$Path) {
    $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
# Read-only production diagnostic, even if local test tools later fail.
$code = @'
import json
from datetime import datetime, timedelta, timezone
from sqlalchemy import text
from app.db.database import engine
from app.core.config import settings

since = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(hours=4)
with engine.connect() as c:
    tx = c.begin()
    try:
        c.execute(text("SET TRANSACTION READ ONLY"))
        c.execute(text("SET LOCAL statement_timeout = '20s'"))
        users = c.execute(text("""
            SELECT u.id, u.first_name, u.last_name, u.status, u.profile_type,
                   u.credential_setup_required, u.credential_activated_at,
                   u.email_verified, u.onboarding_completed_at
            FROM users u
            WHERE u.credential_activated_at >= :since
               OR EXISTS (SELECT 1 FROM activation_challenges a
                          WHERE a.user_id = u.id AND a.created_at >= :since)
               OR EXISTS (SELECT 1 FROM email_deliveries e
                          WHERE e.user_id = u.id AND e.created_at >= :since)
               OR EXISTS (SELECT 1 FROM auth_sessions s
                          WHERE s.user_id = u.id AND
                          (s.created_at >= :since OR s.last_used_at >= :since))
            ORDER BY u.last_name, u.first_name
        """), {"since": since}).mappings().all()
        results = []
        for u in users:
            params = {"id": u["id"], "since": since}
            mails = c.execute(text("""
                SELECT subject, status, attempt_count, last_error_code,
                       created_at, sent_at
                FROM email_deliveries
                WHERE user_id = :id AND created_at >= :since
                ORDER BY created_at DESC
            """), params).mappings().all()
            challenge = c.execute(text("""
                SELECT created_at, expires_at, failed_attempts
                FROM activation_challenges WHERE user_id = :id
            """), {"id": u["id"]}).mappings().first()
            sessions = c.execute(text("""
                SELECT COUNT(*) FROM auth_sessions
                WHERE user_id = :id AND
                      (created_at >= :since OR last_used_at >= :since)
            """), params).scalar_one()
            results.append({
                "name": u["first_name"] + " " + u["last_name"],
                "status": u["status"], "profile_type": u["profile_type"],
                "activation_required": u["credential_setup_required"],
                "activated_at": u["credential_activated_at"],
                "email_verified": u["email_verified"],
                "onboarding_completed_at": u["onboarding_completed_at"],
                "recent_sessions": sessions,
                "activation_challenge": dict(challenge) if challenge else None,
                "emails": [dict(m) for m in mails]
            })
        print(json.dumps({
            "status": "RECENT_ACCESS_DIAGNOSTIC",
            "since_utc": since,
            "email_redirection_enabled": settings.EMAIL_RESTRICT_TO_TEST_RECIPIENT,
            "accounts_with_recent_activity": results,
            "modification_performed": False, "messages_sent": False,
            "codes_printed": False,
            "limit": "Requests rejected before challenge creation may leave no record here; SMTP sent does not prove inbox receipt."
        }, default=str, ensure_ascii=False, indent=2))
    finally:
        tx.rollback()
'@
$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($code))
& ssh vps "printf '%s' '$encoded' | base64 -d | docker exec -i enactspace_backend python -"
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic des acces interrompu.' }

$temp = Join-Path $env:TEMP ('EnactSpace-Requests-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\requests-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            if ((Get-CanonicalHash $local) -notin @($item.Old, $item.New)) {
                throw "Source locale differente : $($item.Path). Aucun remplacement."
            }
        } elseif ($null -ne $item.Old) {
            throw "Source requise absente : $($item.Path)"
        }
        $download = Join-Path $temp $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.New) {
            throw "Integrite incorrecte : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $files) {
        Copy-Item -LiteralPath (Join-Path $temp $item.Path) -Destination (Join-Path $Repo $item.Path) -Force
    }
    "SAUVEGARDE_CODE=$backup"
    'CORRECTIF_DEMANDES_INTEGRE'
    Push-Location (Join-Path $Repo 'frontend')
    try {
        dart format lib/features/members/screens/members_screen.dart lib/features/members/models/member_model.dart test/member_join_requests_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        flutter analyze lib/features/members/screens/members_screen.dart lib/features/members/models/member_model.dart test/member_join_requests_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        flutter test --reporter expanded test/member_join_requests_test.dart test/first_access_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'DEMANDES_ALUMNI_ET_ENACTEURS_TESTS_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
