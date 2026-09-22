param(
    [switch]$Reset
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
$backend = Join-Path $root "backend"
$envDirectory = Join-Path $backend ".ui_audit"
$envFile = Join-Path $envDirectory ".env"
$composeFile = Join-Path $PSScriptRoot "docker-compose.ui_audit.yml"

function New-LocalSecret {
    $bytes = [byte[]]::new(32)
    $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        $generator.GetBytes($bytes)
    } finally {
        $generator.Dispose()
    }
    return [Convert]::ToBase64String($bytes).Replace("+", "A").Replace("/", "B").Replace("=", "")
}

if (-not (Test-Path $envFile)) {
    New-Item -ItemType Directory -Path $envDirectory -Force | Out-Null
    $databasePassword = New-LocalSecret
    $appSecret = New-LocalSecret
    $jwtSecret = New-LocalSecret
    $qrSecret = New-LocalSecret
    $nfcSecret = New-LocalSecret
    $auditPassword = New-LocalSecret
    @(
        "APP_NAME=EnactSpace UI Audit"
        "APP_ENV=ui_audit"
        "APP_DEBUG=true"
        "APP_VERSION=ui-audit"
        "DATABASE_URL=postgresql+psycopg://enactspace_ui_audit:$databasePassword@postgres:5432/enactspace_ui_audit"
        "SECRET_KEY=$appSecret"
        "JWT_SECRET_KEY=$jwtSecret"
        "CORS_ORIGINS=http://127.0.0.1:18080,http://localhost:18080"
        "PUBLIC_API_BASE_URL=http://127.0.0.1:18002"
        "FILE_STORAGE_PATH=/audit/uploads"
        "AUTO_CREATE_TABLES=true"
        "ENABLE_SEED=false"
        "EMAIL_ENABLED=false"
        "NOTIFICATION_EMAIL_ENABLED=false"
        "PUSH_ENABLED=false"
        "NOTIFICATION_PUSH_ENABLED=false"
        "PAYMENT_PROVIDER_ENABLED=false"
        "PAYMENT_PROVIDER=manual_proof"
        "MOBILE_MONEY_ENABLED=false"
        "MOBILE_MONEY_PROVIDER=mock"
        "PAYDUNYA_MODE=test"
        "ATTENDANCE_QR_ENABLED=true"
        "ATTENDANCE_NFC_ENABLED=true"
        "ATTENDANCE_QR_SECRET=$qrSecret"
        "ATTENDANCE_NFC_HASH_SECRET=$nfcSecret"
        "POSTGRES_DB=enactspace_ui_audit"
        "POSTGRES_USER=enactspace_ui_audit"
        "POSTGRES_PASSWORD=$databasePassword"
        "UI_AUDIT_PASSWORD=$auditPassword"
    ) | Set-Content -LiteralPath $envFile -Encoding ascii
    Write-Output "Created ignored local audit environment file."
}

if ($Reset) {
    docker compose --project-name enactspace_ui_audit --file $composeFile down --volumes
}

docker compose --project-name enactspace_ui_audit --file $composeFile up --detach --build
if ($LASTEXITCODE -ne 0) { throw "UI-audit Docker startup failed." }
docker compose --project-name enactspace_ui_audit --file $composeFile exec --workdir /app/backend --env PYTHONPATH=/app/backend backend python /audit-tools/seed_ui_audit.py
if ($LASTEXITCODE -ne 0) { throw "UI-audit fixture seed failed." }
docker compose --project-name enactspace_ui_audit --file $composeFile ps
if ($LASTEXITCODE -ne 0) { throw "UI-audit Docker status check failed." }
