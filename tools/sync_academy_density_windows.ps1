param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '713762c63eb7736335883ac81c2e9b9fce028b1f'
$temp = Join-Path $env:TEMP ('EnactSpace-AcademyDensity-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\academy-density-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/academy/screens/academy_home_screen.dart'; Hash = '9112dd6ad9b41c7372fbba34af24af522a123917076fcb8d33c0fa906d51293c'; New = $false; Binary = $false },
    @{ Path = 'frontend/lib/features/academy/widgets/academy_artwork.dart'; Hash = 'e45c8349d295db71d34e508cae30a0337cca857f7402226d4483526b69f9ca5b'; New = $false; Binary = $false },
    @{ Path = 'frontend/test/academy_home_redesign_test.dart'; Hash = '0cb556ff137dea1942cace5b792decb59974ee5d015c76821ee00332c36d5444'; New = $false; Binary = $false },
    @{ Path = 'frontend/assets/img/academy_banner_light_recommended_path.webp'; Hash = '07b35d16eb6286cb33a7f692d62a57e544e5f13598ca0ebc45707f2c1e63d411'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_light_course_enactus.webp'; Hash = 'd6a114b9c6321329f90124934b2279eb3028dbc0a75e415ea0b9f6dbe4cf1a3c'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_light_course_design_thinking.webp'; Hash = '8eda50fd8de627defeb394d3fea3480eb7a137897c3deb276084faad31d2b8e4'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_light_course_immersion.webp'; Hash = '92d6b95241d16ae5f48342bdc9d95caed691e7b09b4901f79db4448d2bb26f74'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_dark_recommended_path.webp'; Hash = '585fb3ba5643193339fa3f57893fafa924ba00b2038af987290508eb6ab36758'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_dark_course_enactus.webp'; Hash = 'd9096ef1dce465e78c9be2c442852eff2500380dc63f870f1edf3e26e3afbfca'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_dark_course_design_thinking.webp'; Hash = '625b7290bcfc0a727213d5e3d72f73bd4de601f8419959fad634ffece03d35e6'; New = $true; Binary = $true },
    @{ Path = 'frontend/assets/img/academy_banner_dark_course_immersion.webp'; Hash = '06f70e27754019c590a8a21d243fcb5d54f4021bb9432238bafb5833ae65b17c'; New = $true; Binary = $true }
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
        'ACADEMY_PROPORTIONS_ET_BANNIERES_TESTS_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
