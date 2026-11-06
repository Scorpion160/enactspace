# EnactSpace - build Web de production controle.
# Empêche toute release sans adresse API embarquée dans main.dart.js.
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string]$ApiUrl = 'https://api-enactspace.kerunjombor.net',
    [switch]$SkipBuild
)
$ErrorActionPreference = 'Stop'
$expectedApi = 'https://api-enactspace.kerunjombor.net'
if ($ApiUrl.TrimEnd('/') -ne $expectedApi) {
    throw "URL API de production inattendue : $ApiUrl"
}
$frontend = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutter = 'C:\dev\flutter\bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) { throw 'Flutter introuvable.' }
$jsFile = Join-Path $frontend 'build\web\main.dart.js'
$webDir = Join-Path $frontend 'build\web'

if (-not $SkipBuild) {
    Push-Location $frontend
    try {
        & $flutter build web --release --no-tree-shake-icons "--dart-define=ENACTSPACE_API_URL=$expectedApi"
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
$hash = (Get-FileHash -LiteralPath $jsFile -Algorithm SHA256).Hash
$evidence = @{
    build = 'EnactSpace Web release'
    api_url = $expectedApi
    javascript_sha256 = $hash
    checked_utc = [DateTime]::UtcNow.ToString('o')
    validated = $true
}
$evidence | ConvertTo-Json | Set-Content (Join-Path $webDir 'enactspace-build-validation.json') -Encoding UTF8
Write-Output 'BUILD_WEB_PRODUCTION_VALIDATED'
Write-Output "API_URL=$expectedApi"
Write-Output "MAIN_DART_SHA256=$hash"
Write-Output 'DEPLOYMENT_PERFORMED=NO'
