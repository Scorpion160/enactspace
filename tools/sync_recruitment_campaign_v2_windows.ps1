[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend'
)
$ErrorActionPreference = 'Stop'
$manifestHash = '6c469e4b22e12bcc32bf9b96adc3f680c3326d45794a984c4ca76b7efb64c387'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentClients\$id"
$stage = Join-Path $local 'frontend'
$payload = Join-Path $local 'candidate'
$baseline = Join-Path $local 'baseline'
$canonical = Join-Path $local 'current'
$before = @{}
$Frontend = [IO.Path]::GetFullPath($Frontend)
if (!(Test-Path -LiteralPath (Join-Path $Frontend 'pubspec.yaml'))) { throw 'Frontend introuvable.' }
New-Item -ItemType Directory -Path $local -Force | Out-Null

function Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function DownloadChecked([string]$Ref, [string]$Relative, [string]$Destination, [string]$Expected) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Destination)) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Ref/$Relative" `
        -OutFile $Destination -UseBasicParsing
    if ((Hash $Destination) -ne $Expected) { throw "Integrite incorrecte : $Relative" }
}
function FormatChecked([string]$Path) {
    & dart format $Path | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Formatage de la copie de verification echoue.' }
}

$manifest = Join-Path $local 'manifest.json'
DownloadChecked $Commit 'tools/recruitment_campaign_v2_manifest.json' $manifest $manifestHash
$data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
foreach ($entry in $data.frontend) {
    if ($entry.path -notmatch '^frontend/(lib|test)/.+\.dart$' -or $entry.path -match '(^|/)\.\.(/|$)') {
        throw 'Portee du paquet frontend incorrecte.'
    }
    $relative = $entry.path.Substring('frontend/'.Length)
    $candidateFile = Join-Path $payload $relative
    DownloadChecked $Commit $entry.path $candidateFile $entry.sha256
    FormatChecked $candidateFile
    $currentFile = Join-Path $Frontend $relative
    $before[$relative] = if (Test-Path -LiteralPath $currentFile) { Hash $currentFile } else { $null }
    if (Test-Path -LiteralPath $currentFile) {
        $currentCopy = Join-Path $canonical $relative
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($currentCopy)) -Force | Out-Null
        Copy-Item -LiteralPath $currentFile -Destination $currentCopy
        FormatChecked $currentCopy
        if ((Hash $currentCopy) -eq (Hash $candidateFile)) { continue }
        if (!$entry.baseline_sha256) { throw "Un fichier local different existe deja : $relative" }
        $baselineFile = Join-Path $baseline $relative
        DownloadChecked $data.frontend_base_revision $entry.path $baselineFile $entry.baseline_sha256
        FormatChecked $baselineFile
        if ((Hash $currentCopy) -ne (Hash $baselineFile)) {
            throw "Source locale differente : $relative. Aucun remplacement."
        }
    }
    elseif ($entry.baseline_sha256) { throw "Source locale manquante : $relative. Aucun remplacement." }
}

# Work on a complete source copy. No original file is replaced before checks pass.
& robocopy $Frontend $stage /E /XD .git .dart_tool build .idea node_modules /R:1 /W:1 /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw 'Copie des sources de verification echouee.' }
foreach ($entry in $data.frontend) {
    $relative = $entry.path.Substring('frontend/'.Length)
    $target = Join-Path $stage $relative
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $payload $relative) -Destination $target -Force
}
Push-Location $stage
try {
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Preparation des dependances echouee.' }
    $tests = @(Get-ChildItem -Path (Join-Path $stage 'test\recruitment*_test.dart') -File | ForEach-Object { $_.FullName })
    $tests += @((Join-Path $stage 'test\alumni_day_demo_test.dart'), (Join-Path $stage 'test\ui_final_acceptance_test.dart'))
    & flutter analyze --no-pub lib/features/recruitment lib/core/auth/user_experience.dart lib/features/demo @tests
    if ($LASTEXITCODE -ne 0) { throw 'Analyse de la copie echouee. Sources originales conservees.' }
    & flutter test --no-pub --reporter expanded @tests
    if ($LASTEXITCODE -ne 0) { throw 'Tests de la copie echoues. Sources originales conservees.' }
}
finally { Pop-Location }

foreach ($relative in $before.Keys) {
    $currentFile = Join-Path $Frontend $relative
    $now = if (Test-Path -LiteralPath $currentFile) { Hash $currentFile } else { $null }
    if ($now -ne $before[$relative]) { throw "Source modifiee pendant les controles : $relative. Aucun remplacement." }
}
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\recruitment-campaign-$id"
New-Item -ItemType Directory -Path $backup | Out-Null
$installed = @()
try {
    foreach ($entry in $data.frontend) {
        $relative = $entry.path.Substring('frontend/'.Length)
        $target = Join-Path $Frontend $relative
        if ($null -ne $before[$relative]) {
            $saved = Join-Path $backup $relative
            New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($saved)) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $saved
        }
        New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($target)) -Force | Out-Null
        $installed += $relative
        Copy-Item -LiteralPath (Join-Path $payload $relative) -Destination $target -Force
    }
    $before | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $backup 'previous-files.json') -Encoding UTF8
}
catch {
    foreach ($relative in $installed) {
        $target = Join-Path $Frontend $relative
        if ($null -ne $before[$relative]) { Copy-Item -LiteralPath (Join-Path $backup $relative) -Destination $target -Force }
        elseif (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
    throw
}
"SAUVEGARDE_CODE=$backup"
"DOSSIER_VALIDATION=$stage"
'CAMPAGNE_JURY_QUESTIONNAIRE_FRONTEND_ANALYSE_ET_TESTS_OK'
'BUILD_MIGRATION_PRODUCTION_ET_DEPLOIEMENT_NON_EFFECTUES'
