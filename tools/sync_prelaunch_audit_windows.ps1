param(
    [string]$RepoPath = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$commit = '07633b573402d3618eaa416f061a8982ddfd0fe8'
$base = "https://raw.githubusercontent.com/Scorpion160/enactspace/$commit"
$entries = @(
    @{ Path='backend/app/core/config.py'; Old='2e86bd9b9bbc286ab8643499714d0ff634c4e894b3ad614c82a04fd40655876e'; New='bdd320fb34cbdb5aa47b7aac918e27df803b5d403367585feab8ff218b9602ec' },
    @{ Path='backend/test_security_mobile_foundation.py'; Old='58b179f4b6cda3dcf60025d811794e0bba996878ffe145d185cc52a5e7a56dee'; New='064a2f6ef75113b13ec46fab34a718f094b374ab0c49534e6b57f285218b63b7' },
    @{ Path='backend/test_academy_operational.py'; Old='d76482151154c7dbd2ab8c075c891ca246b17a7cebdb85b33da01d04b7236491'; New='018bc9c3d65c79822fc99b9db0d43664b3cb6673e341e5de7ad6832ce4538de6' }
)
function Get-CanonicalHash([string]$Path) {
    $text = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
$temp = Join-Path $env:TEMP ('EnactSpace-AuditSync-' + [guid]::NewGuid())
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\' + [guid]::NewGuid())
$changed = @()
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($entry in $entries) {
        $local = Join-Path $RepoPath $entry.Path
        if (!(Test-Path -LiteralPath $local -PathType Leaf)) { throw "Source absente : $($entry.Path)" }
        if ((Get-Item -LiteralPath $local).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Source liee : arret.' }
        if ((Get-CanonicalHash $local) -notin @($entry.Old, $entry.New)) { throw "Modification locale non reconnue : $($entry.Path). Aucun remplacement." }
        $candidate = Join-Path $temp $entry.Path
        New-Item -ItemType Directory -Path (Split-Path $candidate -Parent) -Force | Out-Null
        Invoke-WebRequest "$base/$($entry.Path)" -OutFile $candidate -UseBasicParsing
        if ((Get-FileHash $candidate -Algorithm SHA256).Hash -ne $entry.New) { throw "Integrite incorrecte : $($entry.Path)" }
    }
    # All guards and downloads succeed before any source file is replaced.
    foreach ($entry in $entries) {
        $saved = Join-Path $backup $entry.Path
        New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $RepoPath $entry.Path) -Destination $saved
    }
    try {
        foreach ($entry in $entries) {
            $changed += $entry.Path
            Copy-Item -LiteralPath (Join-Path $temp $entry.Path) -Destination (Join-Path $RepoPath $entry.Path) -Force
            if ((Get-CanonicalHash (Join-Path $RepoPath $entry.Path)) -ne $entry.New) { throw 'Verification apres copie echouee.' }
        }
    } catch {
        foreach ($path in $changed) {
            Copy-Item -LiteralPath (Join-Path $backup $path) -Destination (Join-Path $RepoPath $path) -Force
        }
        throw
    }
    [ordered]@{
        status='AUDIT_FIXES_INTEGRATED'; source_commit=$commit; files=@($entries | ForEach-Object { $_.Path });
        code_rollback_directory=$backup; git_commands_executed=$false;
        build_performed=$false; deployment_performed=$false; application_tests_performed=$false
    } | ConvertTo-Json -Depth 4
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
