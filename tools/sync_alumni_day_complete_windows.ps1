param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [switch]$PublishWeb
)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = 'bc39495b4657448b41d7b67f871380657813765b'
$legacy = 'c598339cc444bdc8bf7a1ce845f88dbb654644f9'
$temp = Join-Path $env:TEMP ('EnactSpace-AlumniDayComplete-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\alumni-day-complete-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/app/app_router.dart'; Hash = '50c66ccb4acfa322f26c934c1198029b7fd465c92360c69a2146128b4365fca5'; New = $false; BaselineHash = '50c66ccb4acfa322f26c934c1198029b7fd465c92360c69a2146128b4365fca5'; LegacyHash = '3517793a94c7d1a33308174d8fde0f460643c972722d404b6c232bfeca3a2a55' },
    @{ Path = 'frontend/lib/features/auth/screens/login_screen.dart'; Hash = '9640ae50902099d8ae6cc01054868821233bc22c7b19b4b9c01b5fa274bef96c'; New = $false; BaselineHash = '9640ae50902099d8ae6cc01054868821233bc22c7b19b4b9c01b5fa274bef96c'; LegacyHash = 'ba5d03edbd9019044579272b95d7de8ba9cfb6e89f2db0931c1c65213881deab' },
    @{ Path = 'frontend/lib/features/alumni/screens/alumni_screen.dart'; Hash = '984b6b686354fa792997457567b3c19594bd3b1388bdb33a635781f56064ee8b'; New = $false; BaselineHash = '984b6b686354fa792997457567b3c19594bd3b1388bdb33a635781f56064ee8b'; LegacyHash = 'ca0223076834fc071db5050d0c981c6fca1e0fcc68523642ac59548915473dc7' },
    @{ Path = 'frontend/test/ui_final_acceptance_test.dart'; Hash = '9ef720a89761ebc18ecae16caa33502bcc44cf852f732bed085f5c99ed28b820'; New = $false; BaselineHash = '9ef720a89761ebc18ecae16caa33502bcc44cf852f732bed085f5c99ed28b820'; LegacyHash = 'd6b222cb653248067217191757b8582530806639e7a5043167f3e5f516fef867' },
    @{ Path = 'frontend/lib/features/alumni/widgets/alumni_community_hero.dart'; Hash = '15ee5ea9c1ae468f637c16a67654970b14fb8ff7030c82928db59abced3e7347'; New = $true; BaselineHash = '15ee5ea9c1ae468f637c16a67654970b14fb8ff7030c82928db59abced3e7347' },
    @{ Path = 'frontend/lib/features/demo/demo_session.dart'; Hash = '72d618edf1c1a030db15865d3f5f848f18060b7c924c51d24a1914290e8573ee'; New = $true; BaselineHash = 'e12ad53aae6b7d48b0feb19296150720c12ae7cbefaddaebd21679a49a8d52d7' },
    @{ Path = 'frontend/lib/features/demo/demo_widgets.dart'; Hash = '7de722e096083729be0b89e396652aa08340ddccd3031150d52e512d03378e1b'; New = $true; BaselineHash = '7de722e096083729be0b89e396652aa08340ddccd3031150d52e512d03378e1b' },
    @{ Path = 'frontend/lib/features/demo/demo_screen.dart'; Hash = 'decadd4df57167896448b4a4cb72c1ea18e8befc09314de59480f9616c49389e'; New = $true; BaselineHash = 'decadd4df57167896448b4a4cb72c1ea18e8befc09314de59480f9616c49389e' },
    @{ Path = 'frontend/test/alumni_day_demo_test.dart'; Hash = '905a27915159e986e4a3b723877e626afbcf6785f13eb8144a0bdf99ce39cfa3'; New = $true; BaselineHash = '8112d7edef6da9f713aafe584025ba45d1c6d8db2aea87e064d0c6248140f4e0' },
    @{ Path = 'frontend/assets/img/alumni_day_heritage.json'; Hash = '9007d2ac6ab42550f1227db3c9ac924c5ad506bf942f261a2f0f1b364704f1a9'; New = $true; BaselineHash = '9007d2ac6ab42550f1227db3c9ac924c5ad506bf942f261a2f0f1b364704f1a9' },
    @{ Path = 'frontend/lib/features/demo/demo_poles.dart'; Hash = 'c0543d11b43e5a1c9e4554921c1dedfcd6fd9e9aa9472db897cfc3197371fb07'; New = $true; BaselineHash = 'c0543d11b43e5a1c9e4554921c1dedfcd6fd9e9aa9472db897cfc3197371fb07' },
    @{ Path = 'frontend/lib/features/demo/demo_recruitment.dart'; Hash = '05586012b7634c6fc8bef6d0bdb8a73c9f7378d4c0bbf0d4b3f70343f4067afc'; New = $true; BaselineHash = '05586012b7634c6fc8bef6d0bdb8a73c9f7378d4c0bbf0d4b3f70343f4067afc' },
    @{ Path = 'frontend/lib/features/demo/demo_recruitment_gateway.dart'; Hash = 'f9867ba8ab2bdf5b3821e92e4e5134d8240f0dc9e4bc8028d4514c9a7b89dd3f'; New = $true; BaselineHash = '023cea44a259c4559c9591e9128ac95de65b932f75d1e40f7d3cc8bd38b77299' },
    @{ Path = 'frontend/lib/features/recruitment/screens/public/public_application_flow_screen.dart'; Hash = 'ae695024f210b19031428e6d019af7455c2098280d26174850403948301f302e'; New = $false; BaselineHash = 'ae695024f210b19031428e6d019af7455c2098280d26174850403948301f302e'; LegacyHash = '2b84db9653e4dd41303259cce31f4103eb02c997e2aa9e85b601225abd13ad5b' },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/public_recruitment_widgets.dart'; Hash = 'c8fd9bf2dc633281b0c8686ad13d94fb2252edaf5dcd78c37585c780b34012c4'; New = $false; BaselineHash = 'c8fd9bf2dc633281b0c8686ad13d94fb2252edaf5dcd78c37585c780b34012c4'; LegacyHash = 'c622c152a69195ff2b170710bb57f2d6454c5a06aa9cde3584b3362e7361ce26' }
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
        $comparison = Join-Path $temp ('local/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $comparison
        $variants = @($candidate)
        if ($item.BaselineHash -and $item.BaselineHash -ne $item.Hash) {
            $original = Join-Path $temp ('baseline/' + $item.Path)
            DownloadChecked $baseline $item.Path $original $item.BaselineHash
            $variants += $original
        }
        if ($item.LegacyHash -and $item.LegacyHash -ne $item.BaselineHash -and $item.LegacyHash -ne $item.Hash) {
            $original = Join-Path $temp ('legacy/' + $item.Path)
            DownloadChecked $legacy $item.Path $original $item.LegacyHash
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
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze --no-pub @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/alumni_day_demo_test.dart test/recruitment_public_test.dart test/alumni_gamification_academy_impact_test.dart test/biometric_unlock_test.dart test/auth_session_test.dart test/widget_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : publication non lancee, transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/ui_final_acceptance_test.dart --name 'matrice routes|login responsive'
        if ($LASTEXITCODE -ne 0) { throw 'Verification routes ou connexion echouee : publication non lancee.' }
        'DEMO_23_RUBRIQUES_RECRUTEMENT_POLES_CHAT_ARCHIVES_TESTS_OK'
    } finally { Pop-Location }
    if (!$PublishWeb) { 'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'; return }
    $builder = Join-Path $temp 'build_publish_web_windows.ps1'
    DownloadChecked '5dc33c30398db9a040debb68a32778cc255f5e66' 'tools/build_publish_web_windows.ps1' $builder '2535e443cc5de435cd4d9953c6ac563a1583d05aa53879d4a96aae33eb9c7656'
    & $builder -Version '1.0.18' -BuildNumber 21 -Publish
    if (!$?) { throw 'Publication interrompue : transmettre le resultat.' }
    $id = [guid]::NewGuid().ToString('N')
    $publicCatalog = Join-Path $temp 'heritage.public.json'
    Invoke-WebRequest "https://enactspace.kerunjombor.net/assets/assets/img/alumni_day_heritage.json?release=$id" -OutFile $publicCatalog -UseBasicParsing
    $catalog = $files | Where-Object { $_.Path -eq 'frontend/assets/img/alumni_day_heritage.json' }
    if ((Get-FileHash $publicCatalog -Algorithm SHA256).Hash.ToLowerInvariant() -ne $catalog.Hash) { throw 'Catalogue public incorrect : transmettre le resultat.' }
    $demo = 'https://enactspace.kerunjombor.net/#/demo'
    'DEMO_PUBLIQUE_1_0_18_21_ET_CATALOGUE_VERIFIES'
    "URL_DE_L_AFFICHE=$demo"
    'BACKEND_ANDROID_ET_PAYDUNYA_NON_MODIFIES'
    Start-Process $demo
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
