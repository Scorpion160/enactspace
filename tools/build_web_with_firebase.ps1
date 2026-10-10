[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$DefinesPath,
    [string[]]$FlutterArgs = @()
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$pythonPath = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312\python.exe'
if (-not (Test-Path -LiteralPath $pythonPath)) { throw 'Python 3.12 introuvable.' }
if (-not (Test-Path -LiteralPath $DefinesPath -PathType Leaf)) { throw 'Configuration de release introuvable.' }
$defines = (Resolve-Path -LiteralPath $DefinesPath).Path
if ($FlutterArgs | Where-Object { $_ -like '--dart-define*' }) {
    throw 'Les options Firebase et API doivent provenir du seul fichier DefinesPath.'
}
& $pythonPath -X utf8 (Join-Path $PSScriptRoot 'generate_firebase_web_worker.py') --repo $repoRoot --defines $defines --validate-web-release
if ($LASTEXITCODE -ne 0) { throw 'Generation Firebase incomplete. Aucun build lance.' }
$originalLocation = Get-Location
try {
    Set-Location (Join-Path $repoRoot 'frontend')
    & flutter build web --release "--dart-define-from-file=$defines" @FlutterArgs
    if ($LASTEXITCODE -ne 0) { throw 'Build web incomplet.' }
} finally {
    Set-Location $originalLocation
}
