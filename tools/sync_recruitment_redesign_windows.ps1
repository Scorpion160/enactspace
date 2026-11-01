[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend',
    [switch]$SkipPreviews
)
$ErrorActionPreference = 'Stop'
$manifestHash = 'cc424a834c008ba1fcdbfc1413ae7e7bf80d048f049066c90338930f5c20c2ee'
$id = [guid]::NewGuid().ToString('N')
$operation = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentRedesign\$id"
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\recruitment-redesign-$id"
$staging = Join-Path $operation 'staging'
New-Item -ItemType Directory -Path $staging -Force | Out-Null
$receipt = [ordered]@{
    source_commit = $Commit; source_sync_performed = $false
    dart_analysis_passed = $false; flutter_tests_passed = $false
    runtime_captures_generated = $false; web_deployed = $false
    backend_changed = $false; campaign_data_changed = $false
}
function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Get-NormalizedHash([string]$Path) {
    Get-TextHash ([IO.File]::ReadAllText($Path).Replace("`r`n", "`n"))
}
function Get-CanonicalDartHash([string]$Path) {
    $savedEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $output = @(& dart format --output=show --summary=none --show=none `
            --language-version=latest --page-width=80 --trailing-commas=automate $Path)
        if ($LASTEXITCODE -ne 0) { throw 'Lecture du code Dart impossible.' }
        Get-TextHash (($output -join "`n") + "`n")
    }
    finally { [Console]::OutputEncoding = $savedEncoding }
}
function Get-VerifiedFile([string]$Ref, [string]$Relative, [string]$Target, [string]$Expected) {
    New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Ref/$Relative" -OutFile $Target -UseBasicParsing
    if ((Get-Hash $Target) -ne $Expected) { throw "Integrite incorrecte : $Relative" }
}
function Get-LocalFingerprint([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return Get-Hash $Path }
    if (Test-Path -LiteralPath $Path) { throw "Un dossier occupe un chemin de fichier : $Path" }
    return 'ABSENT'
}
function Assert-Scope([string]$Path) {
    if ($Path -match '(^|/)\.\.(/|$)' -or $Path -match '[:\\]' -or
        $Path -notmatch '^(lib/features/recruitment/|test/recruitment[^/]*_test\.dart$|test/support/recruitment_redesign_fixture\.dart$|tool/recruitment_redesign_preview_test\.dart$)') {
        throw 'Chemin hors du perimetre de la refonte.'
    }
}
function New-ReviewArchive($Entries, $Checks) {
    $review = Join-Path $operation 'local-review'
    foreach ($entry in $Entries) {
        $source = Join-Path $Frontend $entry.path
        if (Test-Path -LiteralPath $source -PathType Leaf) {
            $saved = Join-Path $review ('frontend/' + $entry.path)
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $source -Destination $saved
        }
    }
    New-Item -ItemType Directory -Path $review -Force | Out-Null
    $metadata = [ordered]@{ source_commit = $Commit; checks = @($Checks); application_sources_modified = $false; production_accessed = $false } | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText((Join-Path $review 'comparison.json'), $metadata, [Text.UTF8Encoding]::new($false))
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    $archive = Join-Path $downloads "enactspace-recruitment-review-$id.zip"
    Compress-Archive -Path (Join-Path $review '*') -DestinationPath $archive
    return $archive
}

Start-Transcript -Path (Join-Path $operation 'validation.log') | Out-Null
try {
    if (!(Test-Path -LiteralPath (Join-Path $Frontend 'pubspec.yaml'))) { throw 'Projet frontend introuvable.' }
    Get-Command dart -ErrorAction Stop | Out-Null
    Get-Command flutter -ErrorAction Stop | Out-Null
    $manifestPath = Join-Path $staging 'manifest.json'
    Get-VerifiedFile $Commit 'tools/recruitment_redesign_manifest.json' $manifestPath $manifestHash
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schema_version -ne 1 -or $manifest.baseline_commit -notmatch '^[a-f0-9]{40}$') { throw 'Manifeste inattendu.' }
    $files = @($manifest.files)
    $requirements = @($manifest.requirements)
    $entries = @($files) + @($requirements)
    $seen = @{}
    foreach ($entry in $entries) {
        Assert-Scope $entry.path
        if ($seen.ContainsKey($entry.path)) { throw 'Chemin duplique dans le manifeste.' }
        $seen[$entry.path] = $true
        if ($entry.sha256 -notmatch '^[a-f0-9]{64}$') { throw 'Empreinte attendue invalide.' }
    }
    # Every replacement is downloaded and verified before reading or changing local sources.
    foreach ($entry in $files) {
        Get-VerifiedFile $Commit ('frontend/' + $entry.path) (Join-Path $staging ('target/' + $entry.path)) $entry.sha256
    }
    $checks = @()
    $snapshots = @{}
    $unsupported = $false
    foreach ($entry in $entries) {
        $source = Join-Path $Frontend $entry.path
        $raw = Get-LocalFingerprint $source
        $snapshots[$entry.path] = $raw
        $replacement = $files | Where-Object { $_.path -eq $entry.path } | Select-Object -First 1
        $known = $false
        if ($raw -eq 'ABSENT') {
            $known = $null -ne $replacement -and [string]::IsNullOrWhiteSpace($entry.baseline_sha256)
        }
        else {
            $normalized = Get-NormalizedHash $source
            $known = $normalized -eq $entry.sha256 -or
                (![string]::IsNullOrWhiteSpace($entry.baseline_sha256) -and $normalized -eq $entry.baseline_sha256)
            if (!$known) {
                try {
                    $current = Get-CanonicalDartHash $source
                    if ($null -ne $replacement) {
                        $known = $current -eq (Get-CanonicalDartHash (Join-Path $staging ('target/' + $entry.path)))
                    }
                    if (!$known -and ![string]::IsNullOrWhiteSpace($entry.baseline_sha256)) {
                        $old = Join-Path $staging ('baseline/' + $entry.path)
                        Get-VerifiedFile $manifest.baseline_commit ('frontend/' + $entry.path) $old $entry.baseline_sha256
                        $known = $current -eq (Get-CanonicalDartHash $old)
                    }
                }
                catch { $known = $false }
            }
        }
        $checks += [ordered]@{ path = $entry.path; local_sha256 = $raw; recognized = [bool]$known }
        if (!$known) { $unsupported = $true }
    }
    if ($unsupported) {
        $archive = New-ReviewArchive $entries $checks
        "ARCHIVE_POUR_COMPARAISON=$archive"
        throw 'Contenu local different : sources conservees. Joindre seulement cette archive pour adaptation.'
    }
    # Revalidate the complete scope immediately before backups and writes.
    foreach ($entry in $entries) {
        if ((Get-LocalFingerprint (Join-Path $Frontend $entry.path)) -ne $snapshots[$entry.path]) { throw 'Sources modifiees pendant la verification : aucun remplacement.' }
    }
    foreach ($entry in $files) {
        if ($snapshots[$entry.path] -ne 'ABSENT') {
            $saved = Join-Path $backup $entry.path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath (Join-Path $Frontend $entry.path) -Destination $saved
            if ((Get-Hash $saved) -ne $snapshots[$entry.path]) { throw 'Sauvegarde du code incoherente.' }
        }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $backup 'sources.json'), ($checks | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    "SAUVEGARDE_CODE=$backup"
    $copied = @()
    try {
        foreach ($entry in $files) {
            $destination = Join-Path $Frontend $entry.path
            if ((Get-LocalFingerprint $destination) -ne $snapshots[$entry.path]) { throw 'Source modifiee pendant la preparation.' }
            New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
            $copied += $entry
            Copy-Item -LiteralPath (Join-Path $staging ('target/' + $entry.path)) -Destination $destination -Force
            if ((Get-Hash $destination) -ne $entry.sha256) { throw 'Copie de source incoherente.' }
        }
    }
    catch {
        foreach ($entry in $copied) {
            $destination = Join-Path $Frontend $entry.path
            $current = Get-LocalFingerprint $destination
            if ($current -eq $entry.sha256) {
                if ($snapshots[$entry.path] -eq 'ABSENT') { Remove-Item -LiteralPath $destination }
                else { Copy-Item -LiteralPath (Join-Path $backup $entry.path) -Destination $destination -Force }
            }
            elseif ($current -ne $snapshots[$entry.path]) { Write-Warning "Modification concurrente conservee : $($entry.path). Sauvegarde : $backup" }
        }
        throw
    }
    $receipt.source_sync_performed = $true
    Push-Location $Frontend
    try {
        $paths = @($files | ForEach-Object { $_.path })
        & dart format @paths
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze --no-pub lib/features/recruitment test/recruitment_redesign_test.dart test/support/recruitment_redesign_fixture.dart tool/recruitment_redesign_preview_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        $receipt.dart_analysis_passed = $true
        $tests = @(Get-ChildItem -LiteralPath 'test' -Filter 'recruitment*_test.dart' -File | Sort-Object Name | ForEach-Object { $_.FullName })
        if ($tests.Count -lt 16) { throw 'Suite recrutement incomplete : validation interrompue.' }
        & flutter test --no-pub --reporter expanded @tests
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal. Aucune publication effectuee.' }
        $receipt.flutter_tests_passed = $true
        if (!$SkipPreviews) {
            $previewDirectory = Join-Path $Frontend '.dart_tool/recruitment_redesign_previews'
            if (Test-Path -LiteralPath $previewDirectory) { Move-Item -LiteralPath $previewDirectory -Destination (Join-Path $operation 'previous-captures') }
            & flutter test --no-pub --concurrency=1 --reporter expanded tool/recruitment_redesign_preview_test.dart
            if ($LASTEXITCODE -ne 0) { throw 'Captures Flutter bloquees : transmettre le journal.' }
            $previewDirectory = Join-Path $Frontend '.dart_tool/recruitment_redesign_previews'
            $images = @(Get-ChildItem -LiteralPath $previewDirectory -Filter '*.png' -File)
            if ($images.Count -ne 52) { throw 'Captures incompletes : transmettre le journal.' }
            $archive = Join-Path (Join-Path $env:USERPROFILE 'Downloads') "enactspace-recruitment-rendu-$id.zip"
            New-Item -ItemType Directory -Path (Split-Path $archive) -Force | Out-Null
            Compress-Archive -Path (Join-Path $previewDirectory '*.png') -DestinationPath $archive
            $receipt.runtime_captures_generated = $true
            $receipt.preview_archive = $archive
            "CAPTURES_DU_VRAI_RENDU_FLUTTER=$archive"
        }
        'REFONTE_RECRUTEMENT_ANALYSE_ET_TESTS_OK'
        'BUILD_WEB_ET_DEPLOIEMENT_NON_EFFECTUES'
    }
    finally { Pop-Location }
}
catch {
    $receipt.status = 'VALIDATION_BLOCKED'
    throw
}
finally {
    if (!$receipt.Contains('status')) { $receipt.status = 'LOCAL_VALIDATION_PASSED' }
    [IO.File]::WriteAllText((Join-Path $operation 'validation.json'), ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    "DOSSIER_VALIDATION=$operation"
    Stop-Transcript | Out-Null
}
