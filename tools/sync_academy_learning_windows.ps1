param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [switch]$NoPreview
)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = 'd0208c8d594478b39357eb5b261c721850c92839'
$temp = Join-Path $env:TEMP ('EnactSpace-AcademyLearning-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\academy-learning-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/academy/models/academy_lesson_sections.dart'; Hash = 'bded3b97f57a2996a498a7e023c1aac1fcc768f9c71896cd603acd5c9ade9875'; New = $true; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/screens/academy_home_screen.dart'; Hash = 'a77b47505d59221eb01e0c29aec46f1c16bdfcf9cefd41f1525e2f6499ddb610'; New = $false; Binary = $false; BaselineHash = '9112dd6ad9b41c7372fbba34af24af522a123917076fcb8d33c0fa906d51293c' },
    @{ Path = 'frontend/lib/features/academy/screens/academy_course_screen.dart'; Hash = '7be1e6d0342c9144381a44a1c3c949e4f3e3e1d88a85c9fee81794422d05dfa0'; New = $false; Binary = $false; BaselineHash = '799233b76333e35854670870de9f3afe7a530d81e5d4948fcf4e5870b5e4ef96' },
    @{ Path = 'frontend/lib/features/academy/screens/academy_path_screen.dart'; Hash = '8da4c7f40d58ef5621829e88a790814557418e20e85662857fc7611f9871d338'; New = $false; Binary = $false; BaselineHash = '2c049ff8ee77137b3086d486904c8936cea98ae97446cc29089cc6bda4917364' },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_artwork.dart'; Hash = '4dd1e7137d28c3020f5c7a17e04ff7fbb65df1dc3542d282576ec39f75dbdfea'; New = $false; Binary = $false; BaselineHash = 'e45c8349d295db71d34e508cae30a0337cca857f7402226d4483526b69f9ca5b' },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_illustration.dart'; Hash = '0f42c1b3501ecf3dcb53279106366458ba2a7e97b9c2a1aebe31d51f27c19e88'; New = $false; Binary = $false; BaselineHash = 'bc00e5a7ca2022d48cac2ac2638cfb91dae08a6a049a52c71f92b7b089f4d523' },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_style.dart'; Hash = 'e3bad86c6303892dfdbb7e4b2ac84da9d9117cfa010a3062efd81bd437695849'; New = $true; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_course_hero.dart'; Hash = 'e30529b50b4fdcc69c83b4477640265c7da1d3211e0ab6cfac9340395cfa714f'; New = $true; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_lesson_reader.dart'; Hash = 'a52c5b35ed1fab7ff7d0d48b7651a18f597f51c939515ec9a54b700d705e5f40'; New = $true; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_quiz_dialog.dart'; Hash = '0a00964bbbeeaaaceab3da7540b8bed2d2d4962191bae7f3bf951e6a896650fd'; New = $false; Binary = $false; BaselineHash = 'a0e860f5299ade0ca214543e15fe69db0d10ad1288e5a399d21ff2e93f7f3bda' },
    @{ Path = 'frontend/assets/img/academy_mobile_progression.webp'; Hash = '93c4180853be51536fa98f60c59b3aa3906793f02edadda61d4b60d93c928d9f'; New = $true; Binary = $true },
    @{ Path = 'frontend/test/academy_learning_redesign_test.dart'; Hash = '955ed57394f75d251c5f6e89b1937c86960b16b48af9fbdeeb67b948fec47322'; New = $true; Binary = $false },
    @{ Path = 'docs/ACADEMY_LEARNING_REDESIGN_20261029.md'; Hash = 'fd34a00447b6a245e79f9501ff5b10f28278d26d01613bafb17cb530cdbd0cf2'; New = $true; Binary = $false }
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
        & flutter analyze --no-pub lib/features/academy test/academy_learning_redesign_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded "--dart-define=ACADEMY_CAPTURE_DIR=$previews" test/academy_learning_redesign_test.dart test/academy_home_redesign_test.dart test/academy_operational_test.dart test/alumni_gamification_academy_impact_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests Academy echoues : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/alumni_day_native_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests de la demo echoues : transmettre le journal.' }
    } finally { Pop-Location }
    $pictures = @(Get-ChildItem -LiteralPath $previews -Filter '*.png' -File | Sort-Object Name)
    if ($pictures.Count -ne 24) { throw 'Captures incompletes : transmettre le journal.' }
    $cards = ($pictures | ForEach-Object {
        $name = [Net.WebUtility]::HtmlEncode($_.Name)
        "<figure><figcaption>$name</figcaption><a href='$name' target='_blank'><img src='$name' alt='$name' loading='lazy'></a></figure>"
    }) -join "`n"
    $html = @"
<!doctype html>
<html lang='fr'><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>
<title>Academy - controle des nouveaux ecrans</title>
<style>body{margin:24px auto;max-width:1480px;padding:0 20px;background:#f6f4ee;color:#101920;font:16px system-ui}h1{font-size:30px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0;padding:14px;background:#fff;border:1px solid #dde4e2;border-radius:16px}figcaption{margin-bottom:10px;font-weight:700}img{display:block;width:100%;height:auto;border-radius:8px}a{color:inherit}p{line-height:1.6}</style>
<h1>EnactSpace Academy</h1><p>Accueil, formation, parcours et lecture. Clair et sombre, mobile et ordinateur. Clique sur une capture pour la voir en grand. Les donnees de test sont fictives. Cette integration ne publie pas encore le nouveau rendu.</p>
<main>$cards</main></html>
"@
    $gallery = Join-Path $previews 'academy-preview.html'
    [IO.File]::WriteAllText($gallery, $html, [Text.UTF8Encoding]::new($false))
    'ACADEMY_REFONTE_SOURCES_ET_TESTS_OK'
    "CAPTURES_ACADEMY=$gallery"
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    if (!$NoPreview) { Start-Process $gallery }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
