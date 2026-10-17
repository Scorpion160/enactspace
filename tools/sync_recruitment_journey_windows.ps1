param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '2693e6109c4b669e5cf0bb583120678c8a723f39'
$temp = Join-Path $env:TEMP ('EnactSpace-RecruitmentJourney-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\recruitment-journey-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/recruitment/screens/public/public_application_flow_screen.dart'; Hash = 'd20c5b70505904980273f3fd05611d84db7bcd0b577cdecbbf45326a2c0347f7'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/public_application_field.dart'; Hash = 'dafb8f9f78c7a616d45091a67a8e949f16c7fc63c532370603fc32933ac10147'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/public_application_journey.dart'; Hash = '4d70e0375493da9c385cec205474139472d00c787c31831f64b595541e4713be'; New = $true },
    @{ Path = 'frontend/test/recruitment_public_test.dart'; Hash = 'ad2ed87b1bcfc3ba7854ad516cd3c720d668d59e2c1872c4546fcbb806ea0f96'; New = $false },
    @{ Path = 'frontend/test/recruitment_journey_test.dart'; Hash = '082aab4deb3b80d1a897ac73363f00e551300d2b1b347d6fa6badaa075cefc42'; New = $true }
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
        & flutter test --reporter expanded test/recruitment_public_test.dart test/recruitment_mobile_text_test.dart test/recruitment_journey_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'RECRUTEMENT_NOUVEAU_PARCOURS_INTEGRE_ET_TESTE'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
