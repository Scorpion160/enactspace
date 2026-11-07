# EnactSpace - build Web de production controle.
# Empêche toute release sans adresse API embarquée dans main.dart.js.
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ApiUrl = 'https://api-enactspace.kerunjombor.net',
    [string]$ClientDefinesFile,
    [string]$ExpectedSourceCommit,
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$expectedApi = 'https://api-enactspace.kerunjombor.net'
if ($ApiUrl.TrimEnd('/') -ne $expectedApi) {
    throw "URL API de production inattendue : $ApiUrl"
}
$frontend = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo = (Resolve-Path (Join-Path $frontend '..')).Path
$sourceCommit = (& git -C $repo rev-parse HEAD).Trim()
if ($ExpectedSourceCommit -and $sourceCommit -ne $ExpectedSourceCommit) {
    throw 'BLOCAGE : la copie de travail ne correspond pas au commit attendu.'
}
$pubspec = [IO.File]::ReadAllText((Join-Path $frontend 'pubspec.yaml'))
if ($pubspec -notmatch '(?m)^version:\s*([^+\s]+)\+(\d+)\s*$') {
    throw 'Version et numero de build absents du pubspec.'
}
$expectedVersion = $Matches[1]
$expectedBuild = $Matches[2]
$flutter = 'C:\dev\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Flutter introuvable.' }
$jsFile = Join-Path $frontend 'build\web\main.dart.js'
$webDir = Join-Path $frontend 'build\web'

if (-not $SkipBuild) {
    if (-not $ClientDefinesFile -or -not (Test-Path -LiteralPath $ClientDefinesFile -PathType Leaf)) {
        throw 'Le fichier de configuration client est requis pour conserver Firebase et les notifications.'
    }
    & python (Join-Path $repo 'tools\generate_firebase_web_worker.py') --repo $repo --defines $ClientDefinesFile --validate-web-release
    if ($LASTEXITCODE -ne 0) { throw 'Configuration client ou worker Firebase invalide.' }
    Push-Location $frontend
    try {
        & $flutter build web --release --no-tree-shake-icons "--dart-define=ENACTSPACE_API_URL=$expectedApi" "--dart-define-from-file=$ClientDefinesFile"
        if ($LASTEXITCODE -ne 0) { throw 'Echec compilation Flutter Web.' }
    } finally {
        Pop-Location
    }
}
if (-not (Test-Path $jsFile)) { throw 'main.dart.js absent : publication interdite.' }
$js = [System.IO.File]::ReadAllText($jsFile)
if (-not $js.Contains($expectedApi)) {
    throw 'BLOCAGE : ENACTSPACE_API_URL manquant dans le JavaScript. Ne pas publier.'
}
if (-not $js.Contains('/recruitment/campaigns/timeline')) {
    throw 'BLOCAGE : route des campagnes absente du JavaScript.'
}
if (-not (Test-Path (Join-Path $webDir 'index.html'))) {
    throw 'BLOCAGE : page index absente.'
}
$version = Get-Content -LiteralPath (Join-Path $webDir 'version.json') -Raw | ConvertFrom-Json
if ($version.version -ne $expectedVersion -or [string]$version.build_number -ne $expectedBuild) {
    throw 'BLOCAGE : la version compilee ne correspond pas aux sources.'
}
if (-not $js.Contains('other_clubs_count')) {
    throw 'BLOCAGE : le contrat de candidature est incomplet.'
}
$bridge = Join-Path $webDir 'enactmeet_bridge.js'
if (-not (Test-Path -LiteralPath $bridge) -or -not ([IO.File]::ReadAllText($bridge)).Contains('waitForHost')) {
    throw 'BLOCAGE : le correctif du conteneur EnactMeet est absent.'
}
if (-not (Test-Path -LiteralPath (Join-Path $webDir 'firebase-messaging-sw.js'))) {
    throw 'BLOCAGE : worker Firebase absent.'
}
$hash = (Get-FileHash -LiteralPath $jsFile -Algorithm SHA256).Hash
$evidence = @{
    build = 'EnactSpace Web release'
    api_url = $expectedApi
    javascript_sha256 = $hash
    source_commit = $sourceCommit
    source_tree = (& git -C $repo rev-parse 'HEAD^{tree}').Trim()
    version = $version.version
    build_number = $version.build_number
    bridge_sha256 = (Get-FileHash -LiteralPath $bridge -Algorithm SHA256).Hash
    firebase_worker_sha256 = (Get-FileHash -LiteralPath (Join-Path $webDir 'firebase-messaging-sw.js') -Algorithm SHA256).Hash
    checked_utc = [DateTime]::UtcNow.ToString('o')
    validated = $true
}
$evidence | ConvertTo-Json | Set-Content (Join-Path $webDir 'enactspace-build-validation.json') -Encoding UTF8
Write-Output 'BUILD_WEB_PRODUCTION_VALIDATED'
Write-Output "API_URL=$expectedApi"
Write-Output "MAIN_DART_SHA256=$hash"
Write-Output 'DEPLOYMENT_PERFORMED=NO'
