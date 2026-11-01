[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend'
)
$ErrorActionPreference = 'Stop'
$manifestHash = '4862607c0be62f6138543354423ab0b569efc429c0cb6432e5e2b2265edf92b2'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentClients\$id"
$stage = Join-Path $local 'frontend'
$payload = Join-Path $local 'candidate'
$baseline = Join-Path $local 'baseline'
$previous = Join-Path $local 'previous'
$canonical = Join-Path $local 'current'
$before = @{}
$differences = @()
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
function NormalizeSourceCopy([string]$Path) {
    # Call only on candidate/baseline/comparison copies, never on originals.
    $text = [IO.File]::ReadAllText($Path)
    $text = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($false))
}
function FormatChecked([string]$Path) {
    NormalizeSourceCopy $Path
    & dart format $Path | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Formatage de la copie de verification echoue.' }
    NormalizeSourceCopy $Path
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
        if ($entry.prior_package_sha256) {
            $priorPackageFile = Join-Path $local (Join-Path 'prior-package' $relative)
            DownloadChecked $data.frontend_prior_package_revision $entry.path $priorPackageFile $entry.prior_package_sha256
            FormatChecked $priorPackageFile
            if ((Hash $currentCopy) -eq (Hash $priorPackageFile)) { continue }
        }
        if ($entry.previous_sha256) {
            $previousFile = Join-Path $previous $relative
            DownloadChecked $data.frontend_previous_revision $entry.path $previousFile $entry.previous_sha256
            FormatChecked $previousFile
            if ((Hash $currentCopy) -eq (Hash $previousFile)) { continue }
        }
        if (!$entry.baseline_sha256) {
            $differences += [pscustomobject]@{
                path = $relative; reason = 'unexpected_existing_source'
                original_sha256 = $before[$relative]
            }
            continue
        }
        $baselineFile = Join-Path $baseline $relative
        DownloadChecked $data.frontend_base_revision $entry.path $baselineFile $entry.baseline_sha256
        FormatChecked $baselineFile
        if ((Hash $currentCopy) -ne (Hash $baselineFile)) {
            $differences += [pscustomobject]@{
                path = $relative; reason = 'local_source_differs'
                original_sha256 = $before[$relative]
            }
        }
    }
    elseif ($entry.baseline_sha256) {
        $differences += [pscustomobject]@{
            path = $relative; reason = 'local_source_missing'; original_sha256 = $null
        }
    }
}

if ($differences.Count -gt 0) {
    # Export only the scoped Dart copies and public manifest, never the complete
    # frontend, signing files, client defines or generated deployment files.
    $review = Join-Path $local 'source-differences.json'
    [IO.File]::WriteAllText(
        $review,
        (ConvertTo-Json -InputObject @($differences) -Depth 4),
        [Text.UTF8Encoding]::new($false)
    )
    $archive = Join-Path $local 'recruitment-source-review.zip'
    $reviewFiles = @($canonical, $payload, $baseline, $previous, (Join-Path $local 'prior-package'), $manifest, $review) |
        Where-Object { Test-Path -LiteralPath $_ }
    Compress-Archive -LiteralPath $reviewFiles -DestinationPath $archive
    foreach ($difference in $differences) { "SOURCE_A_EXAMINER=$($difference.path)" }
    "ARCHIVE_SOURCES_A_EXAMINER=$archive"
    throw 'Des differences de code restent a examiner. Sources originales conservees.'
}

# Cross-language tests read these exact public server definitions. Stage only
# these two checksum-pinned files beside the frontend, never a live backend.
$testResourceNames = @(
    'backend/app/services/recruitment_rubric.json',
    'backend/app/services/recruitment_questionnaire.py'
)
if (@($data.frontend_test_resources.PSObject.Properties).Count -ne $testResourceNames.Count) {
    throw 'Ressources de test inattendues. Sources originales conservees.'
}
foreach ($name in $testResourceNames) {
    $resource = $data.frontend_test_resources.PSObject.Properties[$name]
    if ($null -eq $resource -or [string]$resource.Value -notmatch '^[a-f0-9]{64}$') {
        throw 'Ressource de test absente ou incorrecte. Sources originales conservees.'
    }
    DownloadChecked $Commit $name (Join-Path $local $name) ([string]$resource.Value)
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
"DOSSIER_VALIDATION=$stage"
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
