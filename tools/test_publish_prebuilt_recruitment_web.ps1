[CmdletBinding()]
param([string]$ScriptPath = (Join-Path $PSScriptRoot 'publish_prebuilt_recruitment_web_windows.ps1'))
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $ScriptPath).Path, [ref]$tokens, [ref]$errors)
if ($errors.Count) { $errors | ForEach-Object { Write-Output $_.Message }; exit 1 }
foreach ($name in @('Get-Hash', 'Assert-PrebuiltWeb', 'Get-BundleFingerprint')) {
    $node = $ast.Find({ param($x) $x -is [Management.Automation.Language.FunctionDefinitionAst] -and $x.Name -eq $name }, $true)
    if ($null -eq $node) { throw "Fonction manquante : $name" }
    . ([scriptblock]::Create($node.Extent.Text))
}
function Assert-Rejected([scriptblock]$Action) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    if (!$rejected) { throw 'Un build invalide a ete accepte.' }
}
$root = Join-Path ([IO.Path]::GetTempPath()) ('enactspace-web-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
try {
    foreach ($name in @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'firebase-messaging-sw.js')) {
        [IO.File]::WriteAllText((Join-Path $root $name), "fixture-$name", [Text.UTF8Encoding]::new($false))
    }
    $versionPath = Join-Path $root 'version.json'
    $validVersion = '{"version":"1.0.23","build_number":"26"}'
    [IO.File]::WriteAllText($versionPath, $validVersion)
    $mainHash = Get-Hash (Join-Path $root 'main.dart.js')
    Assert-PrebuiltWeb $root '1.0.23' 26 $mainHash
    $baseline = Get-BundleFingerprint $root
    if ((Get-BundleFingerprint $root) -cne $baseline) { throw 'Empreinte instable.' }
    [IO.File]::WriteAllText($versionPath, '{"version":"1.0.22","build_number":"26"}')
    Assert-Rejected { Assert-PrebuiltWeb $root '1.0.23' 26 $mainHash }
    [IO.File]::WriteAllText($versionPath, '{"version":"1.0.23","build_number":"25"}')
    Assert-Rejected { Assert-PrebuiltWeb $root '1.0.23' 26 $mainHash }
    [IO.File]::WriteAllText($versionPath, $validVersion)
    $worker = Join-Path $root 'firebase-messaging-sw.js'
    Remove-Item -LiteralPath $worker
    Assert-Rejected { Assert-PrebuiltWeb $root '1.0.23' 26 $mainHash }
    [IO.File]::WriteAllText($worker, 'fixture-firebase-messaging-sw.js', [Text.UTF8Encoding]::new($false))
    $main = Join-Path $root 'main.dart.js'
    [IO.File]::WriteAllText($main, 'changed-javascript', [Text.UTF8Encoding]::new($false))
    Assert-Rejected { Assert-PrebuiltWeb $root '1.0.23' 26 $mainHash }
    [IO.File]::WriteAllText($main, 'fixture-main.dart.js', [Text.UTF8Encoding]::new($false))
    if ((Get-BundleFingerprint $root) -cne $baseline) { throw 'Restauration du jeu de test incorrecte.' }
    $assets = Join-Path $root 'assets'
    New-Item -ItemType Directory -Path $assets | Out-Null
    $asset = Join-Path $assets 'test.txt'
    [IO.File]::WriteAllText($asset, 'first')
    $withAsset = Get-BundleFingerprint $root
    if ($withAsset -ceq $baseline) { throw 'Ajout de fichier non detecte.' }
    [IO.File]::WriteAllText($asset, 'second')
    if ((Get-BundleFingerprint $root) -ceq $withAsset) { throw 'Modification d une ressource non detectee.' }
    Remove-Item -LiteralPath $asset
    if ((Get-BundleFingerprint $root) -cne $baseline) { throw 'Retrait de fichier mal reconnu.' }
    'PREBUILT_WEB_PREFLIGHT_CHECKS_PASSED'
}
finally { Remove-Item -LiteralPath $root -Recurse -Force }
