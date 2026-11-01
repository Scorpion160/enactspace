[CmdletBinding()]
param([string]$ScriptPath = (Join-Path $PSScriptRoot 'sync_recruitment_redesign_windows.ps1'))
$ErrorActionPreference = 'Stop'
$path = (Resolve-Path -LiteralPath $ScriptPath).Path
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { Write-Output $_.Message }; exit 1 }
foreach ($name in @('Assert-Scope', 'Get-TextHash', 'Get-Hash', 'Get-NormalizedHash', 'Get-LocalFingerprint', 'Get-CanonicalDartHash')) {
    $node = $ast.Find({ param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $name }, $true)
    . ([scriptblock]::Create($node.Extent.Text))
}
foreach ($safe in @('lib/features/recruitment/screens/internal/campaign_management_screen.dart', 'test/recruitment_redesign_test.dart', 'test/support/recruitment_redesign_fixture.dart', 'tool/recruitment_redesign_preview_test.dart')) { Assert-Scope $safe }
foreach ($unsafe in @('../secrets.dart', '/tmp/x.dart', 'lib/features/auth/x.dart', 'lib/features/recruitment/../auth.dart', 'C:\secrets.dart', 'test/support/config.json')) {
    $rejected = $false
    try { Assert-Scope $unsafe } catch { $rejected = $true }
    if (!$rejected) { throw "Unsafe scope accepted: $unsafe" }
}
$directory = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory | Out-Null
try {
    $lf = Join-Path $directory 'lf.dart'
    $crlf = Join-Path $directory 'crlf.dart'
    [IO.File]::WriteAllText($lf, "void main() {}\n".Replace('\n', "`n"), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($crlf, "void main() {}`r`n", [Text.UTF8Encoding]::new($false))
    $before = Get-Hash $lf
    if ((Get-CanonicalDartHash $lf) -ne (Get-CanonicalDartHash $crlf)) { throw 'Canonical formatting differs' }
    if ((Get-Hash $lf) -ne $before) { throw 'Canonical comparison modified a source' }
    if ((Get-NormalizedHash $lf) -ne (Get-NormalizedHash $crlf)) { throw 'Newline normalization failed' }
    if ((Get-LocalFingerprint (Join-Path $directory 'absent.dart')) -ne 'ABSENT') { throw 'Missing-file recognition failed' }
    if ((Get-LocalFingerprint $lf) -ne (Get-Hash $lf)) { throw 'Fingerprint differs' }
    $rejected = $false
    try { Get-LocalFingerprint $directory } catch { $rejected = $true }
    if (!$rejected) { throw 'Directory accepted as a file' }
}
finally { Remove-Item -LiteralPath $directory -Recurse -Force }
'POWERSHELL_SYNTAX_AND_SCOPE_CHECKS_PASSED'
