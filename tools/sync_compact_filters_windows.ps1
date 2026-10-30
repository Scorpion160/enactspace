param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [switch]$NoPreview
)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '59fad709cc42d9db5c670932bca0180e6ef7c2bc'
$temp = Join-Path $env:TEMP ('EnactSpace-CompactFilters-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\compact-filters-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'docs/COMPACT_FILTERS_20261030.md'; Hash = '27cec1ed4d4d6a5359056a0d47e92e7472a4081203941c6c5e8bd294d810f105'; New = $false; Binary = $false; BaselineHash = 'fa239d76817a478b830d3a3d94ca739f78418ca715bd1197b82ec480f09937e8' },
    @{ Path = 'frontend/lib/features/poles/widgets/poles_portfolio_widgets.dart'; Hash = 'dfd027f8d2db78ba64bb6a471d23db4f7bca8ee8bf66901f159f00eb923f96e2'; New = $false; Binary = $false; BaselineHash = '14f0751de0df9c58c5878db0b7be480807be4d4634eb9bcc86bc6d0f574a12da' },
    @{ Path = 'frontend/lib/features/projects/widgets/projects_portfolio_widgets.dart'; Hash = '30f44277fcf9b7fbbab57327b9fe29e30eaa9183465a94110b17d3b229cf9f3a'; New = $false; Binary = $false; BaselineHash = 'f597b6c77aa3ffca18252251027879786ba517f9d3f8cd479d7ea9a8b322ceb9' },
    @{ Path = 'frontend/lib/shared/ui/app_filter_toolbar.dart'; Hash = 'dd545bcef054febaf04889f47d71c318287f6dfea75bcf4c4a2df25930e8afd5'; New = $false; Binary = $false; BaselineHash = '6af7427bca956902cf4b2e9356887be20c49a9dd7d22f77b60ef9a6741bc4b28' },
    @{ Path = 'frontend/test/app_filter_toolbar_test.dart'; Hash = '7aceec6d90b5aa833c589e144ab250a4780a3635a8d5f24fe253a83db6890c66'; New = $false; Binary = $false; BaselineHash = '9f365046aab6e34b99f2a4b9e538f6dce059cd3d5a1e64ea0c6fb78ea38180a2' },
    @{ Path = 'frontend/test/archive_minutes_test.dart'; Hash = '2aa650468d356ff1fd0ecad462aaedffb81327c97d354965e88694da7ee25376'; New = $false; Binary = $false; BaselineHash = '68c4297051df4125a9bfcc737269591f47daf254da378eb09d27372a8ce0d756' },
    @{ Path = 'frontend/test/archives_hall_of_fame_test.dart'; Hash = '9d535687a237a164193b1f6a979bbfe70e8a5125f3ef6b69576a6bd16d449259'; New = $false; Binary = $false; BaselineHash = '5c272a27f04a4296173e215d6f4d62eb7458a97299fef6232b08e5d8ca23ab60' },
    @{ Path = 'frontend/test/poles_portfolio_test.dart'; Hash = 'f24000ea00f86d69e5e479cc2fce1b025ee9d495cde3a7fdfcaf848d39a3cf3c'; New = $false; Binary = $false; BaselineHash = '82bab92e83e5e32e919c4e4449e8841a70934f2c6a42af653fbf1e698d08c7ac' },
    @{ Path = 'frontend/test/projects_portfolio_test.dart'; Hash = '7ad930efc4f25619e8375626b456c560af43b943654edb5e499518d2123e8f6f'; New = $false; Binary = $false; BaselineHash = 'e63f3122a6f4cb861b3a97929abdafe484eb792cd271d738bef95f0198c50bea' },
    @{ Path = 'frontend/test/ui_final_acceptance_test.dart'; Hash = 'b365ff3a5f82344bec15bf9e7373fdee1e478f0effd7b56117782104c774a024'; New = $false; Binary = $false; BaselineHash = '9ef720a89761ebc18ecae16caa33502bcc44cf852f732bed085f5c99ed28b820' }
)
function Canonical([string]$Path) {
    [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd()
}
function DownloadChecked([string]$Ref, [string]$Path, [string]$Target, [string]$Hash) {
    New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Ref/$Path" -OutFile $Target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash) {
        throw "Integrite incorrecte : $Path. Aucun remplacement."
    }
}
if (!(Test-Path -LiteralPath (Join-Path $frontend 'pubspec.yaml'))) { throw 'Depot Flutter introuvable.' }
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        DownloadChecked $Commit $item.Path $candidate $item.Hash
        $local = Join-Path $repo $item.Path
        if (!(Test-Path -LiteralPath $local)) {
            if (!$item.New) { throw "Source locale absente : $($item.Path)" }
            continue
        }
        $observed[$item.Path] = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
        if ($item.Binary) {
            if ($observed[$item.Path].ToLowerInvariant() -ne $item.Hash) {
                throw "Illustration locale differente : $($item.Path). Aucun remplacement."
            }
            continue
        }
        $comparison = Join-Path $temp ('local/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $comparison
        $variants = @($candidate)
        if ($item.BaselineHash -and $item.BaselineHash -ne $item.Hash) {
            $original = Join-Path $temp ('baseline/' + $item.Path)
            DownloadChecked $baseline $item.Path $original $item.BaselineHash
            $variants += $original
        }
        if ($item.Path.EndsWith('.dart')) {
            & dart format $comparison @variants | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Comparaison du formatage echouee.' }
        }
        $known = $false
        foreach ($variant in $variants) {
            if ((Canonical $comparison) -ceq (Canonical $variant)) { $known = $true }
        }
        if (!$known) { throw "Source locale differente : $($item.Path). Aucun remplacement." }
    }
    $candidateDart = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { Join-Path $temp ('candidate/' + $_.Path) })
    & dart format @candidateDart
    if ($LASTEXITCODE -ne 0) { throw 'Syntaxe candidate incorrecte : aucun remplacement.' }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ($observed.ContainsKey($item.Path)) {
            if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash -ne $observed[$item.Path]) { throw "Source modifiee pendant la preparation : $($item.Path)" }
        } elseif (Test-Path -LiteralPath $local) { throw "Nouveau fichier apparu : $($item.Path)" }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $rollback = @()
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        $existed = Test-Path -LiteralPath $local
        $rollback += @{ Path = $item.Path; PreviouslyExisted = $existed }
        if ($existed) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    [IO.File]::WriteAllText((Join-Path $backup 'rollback.json'), ($rollback | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp ('candidate/' + $item.Path)) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    $previews = Join-Path $backup 'previews'
    New-Item -ItemType Directory -Path $previews | Out-Null
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze --no-pub @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded "--dart-define=FILTER_CAPTURE_DIR=$previews" test/app_filter_toolbar_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests des filtres echoues : transmettre le journal.' }
        $regressions = @(
            'test/academy_learning_redesign_test.dart',
            'test/academy_home_redesign_test.dart',
            'test/academy_operational_test.dart',
            'test/alumni_gamification_academy_impact_test.dart',
            'test/alumni_day_native_test.dart',
            'test/alumni_day_demo_test.dart',
            'test/archive_minutes_test.dart',
            'test/archives_responsive_test.dart',
            'test/archives_hall_of_fame_test.dart',
            'test/communication_test.dart',
            'test/dashboard_tasks_test.dart',
            'test/events_documents_test.dart',
            'test/documents_offline_test.dart',
            'test/first_access_test.dart',
            'test/help_operational_test.dart',
            'test/poles_portfolio_test.dart',
            'test/projects_portfolio_test.dart',
            'test/recruitment_internal_test.dart',
            'test/veille_operational_test.dart',
            'test/ui_final_acceptance_test.dart',
            'test/member_join_requests_test.dart',
            'test/member_alphabetical_order_test.dart',
            'test/profile_preview_navigation_test.dart'
        )
        & flutter test --no-pub --reporter expanded @regressions
        if ($LASTEXITCODE -ne 0) { throw 'Tests des modules echoues : transmettre le journal.' }
    } finally { Pop-Location }
    $pictures = @(Get-ChildItem -LiteralPath $previews -Filter '*.png' -File | Sort-Object Name)
    if ($pictures.Count -ne 18) { throw 'Captures incompletes : transmettre le journal.' }
    $cards = ($pictures | ForEach-Object {
        $name = [Net.WebUtility]::HtmlEncode($_.Name)
        "<figure><figcaption>$name</figcaption><a href='$name' target='_blank'><img src='$name' alt='$name' loading='lazy'></a></figure>"
    }) -join "`n"
    $html = @"
<!doctype html>
<html lang='fr'><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>
<title>EnactSpace - recherche et filtres</title>
<style>body{margin:24px auto;max-width:1480px;padding:0 20px;background:#f6f4ee;color:#101920;font:16px system-ui}h1{font-size:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0;padding:14px;background:#fff;border:1px solid #dde4e2;border-radius:16px}figcaption{margin-bottom:10px;font-weight:700}img{display:block;width:100%;height:auto;border-radius:8px}a{color:inherit}p{line-height:1.6}</style>
<h1>Recherche et filtres compacts</h1><p>Disposition fermee et ouverte, mobile et ordinateur, clair et sombre. Les deux captures Academy utilisent le catalogue reel avec des donnees fictives de test. Clique sur une capture pour la voir en grand.</p>
<main>$cards</main></html>
"@
    $gallery = Join-Path $previews 'filters-preview.html'
    [IO.File]::WriteAllText($gallery, $html, [Text.UTF8Encoding]::new($false))
    $archive = Join-Path $backup 'filtres-captures.zip'
    Compress-Archive -LiteralPath $pictures.FullName -DestinationPath $archive
    'FILTRES_COMPACTS_ANALYSE_ET_TESTS_OK'
    "CAPTURES_FILTRES=$gallery"
    "ARCHIVE_CAPTURES_A_PARTAGER=$archive"
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    if (!$NoPreview) { Start-Process $gallery }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
