[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend'
)
$ErrorActionPreference = 'Stop'
$files = @(
    @{ path = 'lib/features/recruitment/screens/internal/campaign_management_screen.dart'; sha256 = '60677ae2b61d939d8b16c4274a0da0375e372240da1dc109185856b81a89e191'; previous = '3d22edd94c7dc23d5c5c2d42e205662d345f190c881ba72551aa6cb31e79a06f' },
    @{ path = 'lib/features/recruitment/widgets/internal/campaign_management_widgets.dart'; sha256 = '5eba2204aa590f30ab40f9b129a8e868b52a91a8c8666904c4cb838d1dd44c7d'; previous = '61effb3679c5341a77db1f4e0b1d9e65c9d6ead3d70123ffe5fa6becb4e2ee88' },
    @{ path = 'test/recruitment_campaigns_test.dart'; sha256 = 'b3f4bf21078e66c634cc2d51ba93eca7781c14c05295b37eecd9b13db9007cd9'; previous = '5c5f861662c1b72a27e28dbf08d2dc58a64feae7bb54885476d76e6a4eff99f1' }
)
$id = [guid]::NewGuid().ToString('N')
$staging = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentLifecycle\$id"
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\recruitment-lifecycle-$id"
New-Item -ItemType Directory -Path $staging | Out-Null
function Get-NormalizedHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '').ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}
foreach ($entry in $files) {
    $destination = Join-Path $Frontend $entry.path
    if (!(Test-Path -LiteralPath $destination)) { throw "Source locale absente : $($entry.path)" }
    $before = Get-NormalizedHash $destination
    if ($before -ne $entry.previous -and $before -ne $entry.sha256) {
        throw "Source locale differente : $($entry.path). Aucun remplacement effectue."
    }
    $target = Join-Path $staging $entry.path
    New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/frontend/$($entry.path)" `
        -OutFile $target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.sha256) {
        throw "Integrite incorrecte : $($entry.path)"
    }
}
foreach ($entry in $files) {
    $saved = Join-Path $backup $entry.path
    New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $Frontend $entry.path) -Destination $saved
}
"SAUVEGARDE_CODE=$backup"
foreach ($entry in $files) {
    Copy-Item -LiteralPath (Join-Path $staging $entry.path) -Destination (Join-Path $Frontend $entry.path) -Force
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

