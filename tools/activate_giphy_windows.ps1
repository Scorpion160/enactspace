$ErrorActionPreference = 'Stop'
$web = "$env:LOCALAPPDATA\EnactSpace\WebRelease\22bedeed75934001adf66de4c3f8c6f3\web-client-defines.json"
$androidRoot = "$env:LOCALAPPDATA\EnactSpace\AndroidRecipe"
$androidFiles = @(Get-ChildItem -LiteralPath $androidRoot -Filter 'android-client-defines.json' -File -Recurse | Sort-Object LastWriteTime -Descending)
if (!(Test-Path -LiteralPath $web) -or $androidFiles.Count -eq 0) { throw 'Configuration web ou Android introuvable.' }
$webKey = Read-Host 'Cle GIPHY pour le WEB (saisie locale)'
$androidKey = Read-Host 'Cle GIPHY pour ANDROID (saisie locale)'
if ([string]::IsNullOrWhiteSpace($webKey) -or [string]::IsNullOrWhiteSpace($androidKey)) { throw 'Les deux cles sont requises. Aucune modification.' }
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\giphy-config-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $backup | Out-Null
foreach ($entry in @(
    @{ Path=$web; Name='ENACTSPACE_GIPHY_API_KEY_WEB'; Value=$webKey; Backup='web.json' },
    @{ Path=$androidFiles[0].FullName; Name='ENACTSPACE_GIPHY_API_KEY_ANDROID'; Value=$androidKey; Backup='android.json' }
)) {
    $config = Get-Content -LiteralPath $entry.Path -Raw | ConvertFrom-Json
    Copy-Item -LiteralPath $entry.Path -Destination (Join-Path $backup $entry.Backup)
    $config | Add-Member -MemberType NoteProperty -Name $entry.Name -Value $entry.Value -Force
    [IO.File]::WriteAllText($entry.Path, ($config | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
}
'GIPHY_CONFIGURE_WEB_ET_ANDROID'
'AUCUNE_CLE_A_TRANSMETTRE_DANS_LE_CHAT'
