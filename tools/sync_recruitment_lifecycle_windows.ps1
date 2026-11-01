[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend'
)
$ErrorActionPreference = 'Stop'
$baselineCommit = '7419dd9e54ffc02971235e7d46aaad4c78442821'
$files = @(
    @{ path = 'lib/features/recruitment/screens/internal/campaign_management_screen.dart'; sha256 = '60677ae2b61d939d8b16c4274a0da0375e372240da1dc109185856b81a89e191'; previous = '3d22edd94c7dc23d5c5c2d42e205662d345f190c881ba72551aa6cb31e79a06f'; baseline = 'a90b69477e364dc3d33d8e0db606d792714c5cdbfe20a86e2234b7f0e5784af5' },
    @{ path = 'lib/features/recruitment/widgets/internal/campaign_management_widgets.dart'; sha256 = '5eba2204aa590f30ab40f9b129a8e868b52a91a8c8666904c4cb838d1dd44c7d'; previous = '61effb3679c5341a77db1f4e0b1d9e65c9d6ead3d70123ffe5fa6becb4e2ee88'; baseline = '9aafc7299c5a9a4eed027fc48910bc64a185e8bca8a48416caa65e8bb8fd54f2' },
    @{ path = 'test/recruitment_campaigns_test.dart'; sha256 = 'b3f4bf21078e66c634cc2d51ba93eca7781c14c05295b37eecd9b13db9007cd9'; previous = '5c5f861662c1b72a27e28dbf08d2dc58a64feae7bb54885476d76e6a4eff99f1'; baseline = '7edbcc594a7a23795e05464028ff14312a98eb558a5353c21a90e8a2be0030d6' }
)
$id = [guid]::NewGuid().ToString('N')
$staging = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentLifecycle\$id"
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\recruitment-lifecycle-$id"
New-Item -ItemType Directory -Path $staging | Out-Null

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}
function Get-NormalizedHash([string]$Path) {
    Get-TextHash ([IO.File]::ReadAllText($Path).Replace("`r`n", "`n"))
}
function Get-CanonicalDartHash([string]$Path) {
    # Print formatted code only, with identical settings for both sources.
    # --output=show never writes the candidate's local source.
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
function New-LocalReviewArchive($Checks) {
    $review = Join-Path $staging 'local-review'
    foreach ($entry in $files) {
        $saved = Join-Path $review ('frontend/' + $entry.path)
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $Frontend $entry.path) -Destination $saved
    }
    $metadata = [ordered]@{
        script_version = 2
        source_commit = $Commit
        baseline_commit = $baselineCommit
        files = @($Checks)
        application_sources_modified = $false
        production_accessed = $false
    } | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText((Join-Path $review 'comparison.json'), $metadata, [Text.UTF8Encoding]::new($false))
    $downloads = Join-Path $env:USERPROFILE 'Downloads'
    New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    $archive = Join-Path $downloads ("enactspace-recruitment-source-review-$id.zip")
    Compress-Archive -Path (Join-Path $review '*') -DestinationPath $archive
    return $archive
}

# Verify every downloaded file before comparing or replacing local code.
foreach ($entry in $files) {
    $destination = Join-Path $Frontend $entry.path
    if (!(Test-Path -LiteralPath $destination)) { throw "Source locale absente : $($entry.path)" }
    $target = Join-Path $staging ('target/' + $entry.path)
    $baseline = Join-Path $staging ('baseline/' + $entry.path)
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path $baseline) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/frontend/$($entry.path)" `
        -OutFile $target -UseBasicParsing
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$baselineCommit/frontend/$($entry.path)" `
        -OutFile $baseline -UseBasicParsing
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256 -or
        (Get-FileHash -LiteralPath $baseline -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.baseline) {
        throw "Integrite incorrecte : $($entry.path). Aucun remplacement effectue."
    }
}

$checks = @()
$unsupported = $false
foreach ($entry in $files) {
    $source = Join-Path $Frontend $entry.path
    $entry['originalBytes'] = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    $hash = Get-NormalizedHash $source
    $known = $hash -eq $entry.sha256 -or $hash -eq $entry.previous -or $hash -eq $entry.baseline
    $check = [ordered]@{ path = $entry.path; local_sha256 = $entry.originalBytes; normalized_sha256 = $hash; recognized = $known }
    if (!$known) {
        try {
            $current = Get-CanonicalDartHash $source
            $old = Get-CanonicalDartHash (Join-Path $staging ('baseline/' + $entry.path))
            $new = Get-CanonicalDartHash (Join-Path $staging ('target/' + $entry.path))
            $known = $current -eq $old -or $current -eq $new
            $check['canonical_local_sha256'] = $current
            $check['canonical_baseline_sha256'] = $old
            $check['canonical_target_sha256'] = $new
            $check['recognized'] = $known
        }
        catch { $check['format_check_failed'] = $true }
    }
    if (!$known) { $unsupported = $true }
    $checks += $check
}
if ($unsupported) {
    $archive = New-LocalReviewArchive $checks
    'SOURCES_LOCALES_CONSERVEES_AUCUN_REMPLACEMENT'
    "ARCHIVE_POUR_COMPARAISON=$archive"
    throw 'Difference de contenu a examiner : joindre l archive indiquee.'
}

foreach ($entry in $files) {
    $source = Join-Path $Frontend $entry.path
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.originalBytes) {
        throw 'Source modifiee pendant la verification : aucun remplacement effectue.'
    }
    $saved = Join-Path $backup $entry.path
    New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $saved
    if ((Get-FileHash -LiteralPath $saved -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.originalBytes) {
        throw 'Sauvegarde du code incoherente : aucun remplacement effectue.'
    }
}
"SAUVEGARDE_CODE=$backup"
$copied = @()
try {
    foreach ($entry in $files) {
        $destination = Join-Path $Frontend $entry.path
        if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.originalBytes) {
            throw 'Source modifiee pendant la preparation.'
        }
        $copied += $entry
        Copy-Item -LiteralPath (Join-Path $staging ('target/' + $entry.path)) -Destination $destination -Force
    }
}
catch {
    foreach ($entry in $copied) {
        Copy-Item -LiteralPath (Join-Path $backup $entry.path) -Destination (Join-Path $Frontend $entry.path) -Force
    }
    throw
}
Push-Location $Frontend
try {
    $paths = @($files | ForEach-Object { $_.path })
    & dart format @paths
    if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
    & flutter analyze --no-pub @paths
    if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le resultat.' }
    & flutter test --no-pub --reporter expanded test/recruitment_campaigns_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Tests du cycle de vie echoues : transmettre le journal.' }
    'CYCLE_CAMPAGNE_SOURCES_ANALYSE_ET_TESTS_OK'
    'CORRECTIF_INTERFACE_NON_ENCORE_DEPLOYE_SUR_LE_WEB'
}
finally { Pop-Location }
