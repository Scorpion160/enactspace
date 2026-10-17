param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '9ce00f206efe640b7f8a96b58d8499baaddb910c'
$temp = Join-Path $env:TEMP ('EnactSpace-RecruitmentLanding-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\recruitment-landing-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/recruitment/screens/public/public_recruitment_campaigns_screen.dart'; Hash = '068a83b15d71899ab9116dc5636fc4c47dd4c029dff9d96db9920a52e4e9ae80'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/recruitment_welcome.dart'; Hash = '7ae4d693d34f153d7dceb55a22cc41c14f864328228e366e0581efd5a3c84f90'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/public/public_recruitment_widgets.dart'; Hash = '303f7530629345bb6513d7fbf49b06d9c8384cdea2a65dd28d229a26af8fcecc'; New = $false },
    @{ Path = 'frontend/test/recruitment_public_test.dart'; Hash = '100bece30e671ad2812a35a0dd563d725ed6683ff38779d61dd6b86ec520825b'; New = $false },
    @{ Path = 'frontend/test/recruitment_landing_test.dart'; Hash = 'f3d45f99433811c0dd0dd3da5d706fc8cf486e0a16d2e89c04a1a2648a66c150'; New = $true }
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
        'ACCUEIL_RECRUTEMENT_INTEGRE_ET_TESTE'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
