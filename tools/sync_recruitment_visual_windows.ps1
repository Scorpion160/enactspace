param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '306f4ddd6fc0893b16f01fe143dd57c25e22abda'
$temp = Join-Path $env:TEMP ('EnactSpace-RecruitmentVisual-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\recruitment-visual-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/recruitment/screens/public/public_recruitment_campaigns_screen.dart'; Hash = '106ad2633b48833c1505e4f3e34b6ffbf8935987320cab60b34acef642e0a219'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/recruitment_welcome.dart'; Hash = 'ca6b3447307d3071a76bb3c7373f4d63f6e52d0e68caf9fd11f3f0ece93399ab'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/public_recruitment_widgets.dart'; Hash = 'd919decc127ee525aff673a12fd28d00f65a280932f2d832a9ccdc5f4a10648c'; New = $false },
    @{ Path = 'frontend/test/recruitment_landing_test.dart'; Hash = 'bd4105be784eb67b5bbc68007f85d0e55cee8cd91be07092dd9a67693c6695c6'; New = $false }
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
        $dartFiles = @($files | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --reporter expanded test/recruitment_public_test.dart test/recruitment_landing_test.dart test/recruitment_campaigns_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'ACCUEIL_RECRUTEMENT_VISUEL_INTEGRE_ET_TESTE'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
