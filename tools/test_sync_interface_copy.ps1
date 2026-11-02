[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$syncScript = Join-Path $PSScriptRoot 'sync_interface_copy_windows.ps1'
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'interface_copy_manifest.json') -Raw | ConvertFrom-Json
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($syncScript, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw 'PowerShell syntax error.' }
$scopeFunction = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Assert-Scope' }, $true)
. ([scriptblock]::Create($scopeFunction.Extent.Text))
foreach ($entry in @($manifest.files) + @($manifest.requirements)) { Assert-Scope $entry.path }
foreach ($path in @('../.env', 'frontend/lib/../.env', 'frontend/lib/./x.dart', '/frontend/lib/x.dart', 'frontend/lib/x.dart:stream', 'frontend\lib\x.dart', 'backend/app/core/config.py')) {
    $rejected = $false
    try { Assert-Scope $path } catch { $rejected = $true }
    if (!$rejected) { throw "Out-of-scope path accepted: $path" }
}
$expected = (Get-FileHash (Join-Path $PSScriptRoot 'interface_copy_manifest.json')).Hash.ToLowerInvariant()
if (!(Get-Content $syncScript -Raw).Contains("`$manifestHash = '$expected'")) { throw 'Manifest hash differs.' }
foreach ($entry in $manifest.files) {
    if ((Get-FileHash (Join-Path $repository $entry.path)).Hash.ToLowerInvariant() -ne $entry.sha256) { throw "Target hash differs: $($entry.path)" }
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('enactspace-copy-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$oldLocal = $env:LOCALAPPDATA; $oldProfile = $env:USERPROFILE
$global:InterfaceCopyTestContext = @{}

# The application SDK and network are mocked; this tests source safety only.
function dart {
    $global:LASTEXITCODE = 0
    if ($args -contains '--output=show') { Get-Content -LiteralPath $args[-1] }
}
function flutter {
    $global:InterfaceCopyTestContext.flutterCalls++
    $global:LASTEXITCODE = 0
}
function Invoke-WebRequest {
    param([string]$Uri, [string]$OutFile, [switch]$UseBasicParsing)
    $prefix = 'https://raw.githubusercontent.com/Scorpion160/enactspace/'
    if (!$Uri.StartsWith($prefix)) { throw 'Unexpected test URL.' }
    $parts = $Uri.Substring($prefix.Length).Split('/', 2)
    $ctx = $global:InterfaceCopyTestContext
    $base = if ($parts[0] -eq $ctx.baselineCommit) { $ctx.baselineRoot } else { $ctx.sourceRepository }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath (Join-Path $base $parts[1]) -Destination $OutFile
    if ($ctx.scenario -eq 'corrupt-download' -and $parts[1] -eq $ctx.corruptPath) {
        [IO.File]::AppendAllText($OutFile, 'corrupt')
    }
}
function Copy-Item {
    param([string]$LiteralPath, [string]$Destination, [switch]$Force)
    $ctx = $global:InterfaceCopyTestContext
    if ($ctx.scenario -eq 'copy-failure' -and $LiteralPath.Replace('\', '/').Contains('/staging/target/') -and $Destination.StartsWith($ctx.project)) {
        $ctx.sourceWrites++
        if ($ctx.sourceWrites -eq 2) { throw 'Injected copy failure.' }
    }
    Microsoft.PowerShell.Management\Copy-Item @PSBoundParameters
}
function Fingerprints([string]$Project) {
    $result = @{}
    foreach ($entry in @($manifest.files) + @($manifest.requirements)) {
        $p = Join-Path $Project $entry.path
        $result[$entry.path] = if (Test-Path -LiteralPath $p -PathType Leaf) { (Get-FileHash $p).Hash } else { 'ABSENT' }
    }
    $result
}
try {
    $archive = Join-Path $root 'baseline.zip'
    $paths = @(@($manifest.files) + @($manifest.requirements) | Where-Object { $_.baseline_sha256 } | ForEach-Object { $_.path })
    & git -C $repository archive --format=zip "--output=$archive" $manifest.baseline_commit -- @paths
    if ($LASTEXITCODE -ne 0) { throw 'Cannot prepare public baseline fixture.' }
    Expand-Archive -LiteralPath $archive -DestinationPath (Join-Path $root 'baseline')
    foreach ($scenario in @('known-crlf', 'local-change', 'corrupt-download', 'copy-failure')) {
        $case = Join-Path $root $scenario
        $project = Join-Path $case 'project'
        New-Item -ItemType Directory -Path $project -Force | Out-Null
        Microsoft.PowerShell.Management\Copy-Item -Path (Join-Path $root 'baseline/*') -Destination $project -Recurse
        $env:LOCALAPPDATA = Join-Path $case 'appdata'
        $env:USERPROFILE = Join-Path $case 'profile'
        $global:InterfaceCopyTestContext = @{
            scenario = $scenario; project = $project; sourceWrites = 0; flutterCalls = 0
            baselineCommit = $manifest.baseline_commit; baselineRoot = (Join-Path $root 'baseline')
            sourceRepository = $repository; corruptPath = $manifest.files[0].path
        }
        $dartEntry = $manifest.files | Where-Object { $_.path.EndsWith('.dart') -and $_.baseline_sha256 } | Select-Object -First 1
        $probe = Join-Path $project $dartEntry.path
        if ($scenario -eq 'known-crlf') {
            [IO.File]::WriteAllText($probe, [IO.File]::ReadAllText($probe).Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        }
        if ($scenario -eq 'local-change') { [IO.File]::AppendAllText($probe, "`n// Local work to preserve.`n") }
        [IO.File]::WriteAllText((Join-Path $project '.env'), 'SENTINEL_NOT_TO_EXPORT')
        $before = Fingerprints $project
        $failed = $false
        $failureMessage = ''
        try { & $syncScript -Commit ('a' * 40) -Frontend (Join-Path $project 'frontend') -SkipPreviews *>&1 | Out-Null }
        catch { $failed = $true; $failureMessage = $_.Exception.Message }
        $ctx = $global:InterfaceCopyTestContext
        if ($scenario -eq 'known-crlf') {
            if ($failed -or $ctx.flutterCalls -ne 2) { throw "Known baseline did not reach mocked validation: $failureMessage" }
            foreach ($entry in $manifest.files) {
                if ((Get-FileHash (Join-Path $project $entry.path)).Hash.ToLowerInvariant() -ne $entry.sha256) { throw 'Known source replacement differs.' }
            }
        }
        else {
            if (!$failed -or $ctx.flutterCalls -ne 0) { throw "Unsafe case reached validation: $scenario" }
            $after = Fingerprints $project
            foreach ($path in $before.Keys) { if ($before[$path] -ne $after[$path]) { throw "Source was not preserved: $scenario $path" } }
            if ($scenario -eq 'local-change') {
                $zip = Get-ChildItem -Path (Join-Path $env:USERPROFILE 'Downloads/*.zip') | Select-Object -First 1
                if (!$zip) { throw 'Missing source comparison archive.' }
                $opened = [IO.Compression.ZipFile]::OpenRead($zip.FullName)
                try { if (@($opened.Entries | Where-Object { $_.FullName -match '(^|/)\.env$' }).Count) { throw 'Unscoped file exported.' } }
                finally { $opened.Dispose() }
            }
        }
        "SYNC_GUARD_PASSED=$scenario"
    }
}
finally {
    $env:LOCALAPPDATA = $oldLocal; $env:USERPROFILE = $oldProfile
    Remove-Variable -Name InterfaceCopyTestContext -Scope Global -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $root -Recurse -Force
}
'POWERSHELL_SCOPE_HASH_AND_ROLLBACK_CHECKS_PASSED_WITH_MOCKED_FLUTTER'
