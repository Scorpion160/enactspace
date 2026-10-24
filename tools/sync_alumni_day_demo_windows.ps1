param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$frontend = Join-Path $Repo 'frontend'
$baseline = 'c598339cc444bdc8bf7a1ce845f88dbb654644f9'
$temp = Join-Path $env:TEMP ('EnactSpace-AlumniDay-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\alumni-day-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/app/app_router.dart'; Hash = '50c66ccb4acfa322f26c934c1198029b7fd465c92360c69a2146128b4365fca5'; New = $false; BaselineHash = '3517793a94c7d1a33308174d8fde0f460643c972722d404b6c232bfeca3a2a55' },
    @{ Path = 'frontend/lib/features/auth/screens/login_screen.dart'; Hash = '9640ae50902099d8ae6cc01054868821233bc22c7b19b4b9c01b5fa274bef96c'; New = $false; BaselineHash = 'ba5d03edbd9019044579272b95d7de8ba9cfb6e89f2db0931c1c65213881deab' },
    @{ Path = 'frontend/lib/features/alumni/screens/alumni_screen.dart'; Hash = '984b6b686354fa792997457567b3c19594bd3b1388bdb33a635781f56064ee8b'; New = $false; BaselineHash = 'ca0223076834fc071db5050d0c981c6fca1e0fcc68523642ac59548915473dc7' },
    @{ Path = 'frontend/test/ui_final_acceptance_test.dart'; Hash = '9ef720a89761ebc18ecae16caa33502bcc44cf852f732bed085f5c99ed28b820'; New = $false; BaselineHash = 'd6b222cb653248067217191757b8582530806639e7a5043167f3e5f516fef867' },
    @{ Path = 'frontend/lib/features/alumni/widgets/alumni_community_hero.dart'; Hash = '15ee5ea9c1ae468f637c16a67654970b14fb8ff7030c82928db59abced3e7347'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_session.dart'; Hash = 'a189157156e69ae0d2e5b1d6104b10555d3d4d5afd8addf248084c2088d07978'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_widgets.dart'; Hash = 'e8462afd2f71300c90a165e48aa85ff0a1d46a75c7f2abb124a26382d8699c89'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_screen.dart'; Hash = '2c1ebee2f562875ed2c208b88308038b5e3040e0a31f77776caf3ecde38e3d1f'; New = $true },
    @{ Path = 'frontend/test/alumni_day_demo_test.dart'; Hash = '2438dd44ca8a983060f1d5dcd4395f0652e9950ea06fa8e40c55bb4cb937156c'; New = $true },
    @{ Path = 'frontend/assets/img/alumni_day_heritage.json'; Hash = '9007d2ac6ab42550f1227db3c9ac924c5ad506bf942f261a2f0f1b364704f1a9'; New = $true }
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
if (!(Test-Path -LiteralPath (Join-Path $frontend 'pubspec.yaml'))) {
    throw 'Depot Flutter introuvable.'
}
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        DownloadChecked $Commit $item.Path $candidate $item.Hash
        $local = Join-Path $Repo $item.Path
        if (!(Test-Path -LiteralPath $local)) {
            if (!$item.New) { throw "Source locale absente : $($item.Path)" }
            continue
        }
        $observed[$item.Path] = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
        $comparison = Join-Path $temp ('local/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $comparison
        $variants = @($candidate)
        if (!$item.New) {
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
    $candidateDart = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object {
        Join-Path $temp ('candidate/' + $_.Path)
    })
    & dart format @candidateDart
    if ($LASTEXITCODE -ne 0) { throw 'Syntaxe candidate incorrecte : aucun remplacement.' }
    foreach ($item in $files) {
        $local = Join-Path $Repo $item.Path
        if ($observed.ContainsKey($item.Path)) {
            if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash -ne $observed[$item.Path]) {
                throw "Source modifiee pendant la preparation : $($item.Path)"
            }
        } elseif (Test-Path -LiteralPath $local) {
            throw "Nouveau fichier apparu pendant la preparation : $($item.Path)"
        }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $rollback = @()
    foreach ($item in $files) {
        $local = Join-Path $Repo $item.Path
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
        $local = Join-Path $Repo $item.Path
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
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : sources sauvegardees, transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/alumni_day_demo_test.dart test/alumni_gamification_academy_impact_test.dart test/biometric_unlock_test.dart test/auth_session_test.dart test/widget_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/ui_final_acceptance_test.dart --name 'matrice routes|login responsive'
        if ($LASTEXITCODE -ne 0) { throw 'Verification des routes ou de la connexion echouee : transmettre le journal.' }
        'DEMO_ENACTEUR_ALUMNI_ET_SOUVENIRS_TESTS_OK'
        'PAYDUNYA_ET_BACKEND_NON_MODIFIES'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
