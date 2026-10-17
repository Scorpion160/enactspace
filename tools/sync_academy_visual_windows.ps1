param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '1ccbb0ac2b8220ee8eb19d24a9114790e7bf2b95'
$temp = Join-Path $env:TEMP ('EnactSpace-AcademyVisual-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\academy-visual-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/academy/screens/academy_home_screen.dart'; Hash = '931a4d1cc4751a845e9b6c7dca4b0ab1cf89ce6b808649e5f0df2de0568a3020'; New = $false; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_artwork.dart'; Hash = '415057c919bb0658ad59f9e56f2ea334b6f4395a5c527f8de8e51637db71fac1'; New = $true; Binary = $false },
    @{ Path = 'frontend/test/academy_home_redesign_test.dart'; Hash = '91d9c13ee7384f92cd10ca7192fdb7996fddf6774209a2a5cf247c7cc5d271c1'; New = $true; Binary = $false },
    @{ Path = 'frontend/assets/img/academy_web_hero_learning.webp'; Hash = 'bce0e731bc3bd1a959e08490944b5cced9d7a7fe97330476b3a8b904951f1e6d'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_web_recommended_path.webp'; Hash = '893731749c8fbe22cd05edebf275c10e6708b92bf7ec58a135ae381a3cd52c3b'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_web_course_enactus.webp'; Hash = '2de56fed49ee9915a79fc367f0a8fc3306fc805e2b41a936325a86bdc54b446d'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_web_course_design_thinking.webp'; Hash = '7517f603623743c4c1962c5d312b65b5bc5baea2c6169b27555e3420de7e86fb'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_web_course_immersion.webp'; Hash = '9b7002a80ec1a4b80854461822de13ea878368e0334821e09c130fe212c2ba3b'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_mobile_hero_learning.webp'; Hash = '5da38afb7b8c249e589542c260ca0685ed2bb0e36797f98f5dfa72dc2eb3c1c3'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_mobile_recommended_path.webp'; Hash = 'c8e905ac58f6eb12b5316c8d6e32ffc95d3ab638649f40a8940d95d611576305'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_mobile_course_enactus.webp'; Hash = 'bf2b52859988c21d56a4d87aa5e42b9e0a08a29a5b8ae9404a529fb6a9735da7'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_mobile_course_design_thinking.webp'; Hash = '9c6ca733885950aa4dee5a883fbf4705db0897a01f94f288c03b156d2bf0a8d1'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_mobile_course_immersion.webp'; Hash = '849b067918246987b4e0348092751f3d8f10f8dc0b3143aeca30e9eaf950c3f9'; New = $true; Binary = $true }
)
function Canonical($path) {
    [IO.File]::ReadAllText($path).Replace("`r`n", "`n").TrimEnd()
}
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $candidate) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $candidate -UseBasicParsing
        if ((Get-FileHash $candidate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) {
            throw "Integrite incorrecte : $($item.Path)"
        }
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $observed[$item.Path] = (Get-FileHash $local -Algorithm SHA256).Hash
            $comparison = Join-Path $temp ('local/' + $item.Path)
            New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $comparison
            $variants = @($candidate)
            if (!$item.New) {
                $original = Join-Path $temp ('baseline/' + $item.Path)
                New-Item -ItemType Directory -Path (Split-Path $original) -Force | Out-Null
                Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$baseline/$($item.Path)" -OutFile $original -UseBasicParsing
                $variants += $original
            }
            if ($item.Binary) {
                if ((Get-FileHash $comparison -Algorithm SHA256).Hash -ne
                    (Get-FileHash $candidate -Algorithm SHA256).Hash) {
                    throw "Illustration locale differente : $($item.Path)"
                }
                continue
            }
            & dart format $comparison @variants | Out-Null
            if ($LASTEXITCODE -ne 0) { throw 'Comparaison du formatage echouee.' }
            $known = $false
            foreach ($variant in $variants) {
                if ((Canonical $comparison) -ceq (Canonical $variant)) { $known = $true }
            }
            if (!$known) { throw "Source locale differente : $($item.Path). Aucun remplacement." }
        } elseif (!$item.New) {
            throw "Source locale absente : $($item.Path)"
        }
    }
    $candidateDart = @($files | Where-Object { !$_.Binary } | ForEach-Object {
        Join-Path $temp ('candidate/' + $_.Path)
    })
    & dart format @candidateDart
    if ($LASTEXITCODE -ne 0) { throw 'Syntaxe candidate incorrecte : aucun remplacement.' }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ($observed.ContainsKey($item.Path) -and
            (Get-FileHash $local -Algorithm SHA256).Hash -ne $observed[$item.Path]) {
            throw "Source modifiee pendant la preparation : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp ('candidate/' + $item.Path)) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { !$_.Binary } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --reporter expanded test/academy_home_redesign_test.dart test/academy_operational_test.dart test/alumni_gamification_academy_impact_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'ACADEMY_ACCUEIL_ILLUSTRE_ANALYSE_ET_TESTS_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
