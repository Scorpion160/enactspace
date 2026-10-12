param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '9fe455080b0fc280ad5c761df0ae5f8e0dedd7b8'
$temp = Join-Path $env:TEMP ('EnactSpace-GiphyIOS-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\giphy-ios-' + [guid]::NewGuid().ToString('N'))
$files = @(
    @{ Path = 'frontend/lib/features/chat/services/chat_giphy_service.dart'; Hash = '7f4a51924342527ba95ee980b228dbfd7b19a141788086d1654d5cc45b0f8885' }
    @{ Path = 'frontend/test/chat_giphy_service_test.dart'; Hash = 'de77cee201c8cb826cdca535b4a477a49bd546577763a586e80f5ffc675e4631' }
)
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        $original = Join-Path $temp ('baseline/' + $item.Path)
        $comparison = Join-Path $temp ('local/' + $item.Path)
        foreach ($path in @($candidate, $original, $comparison)) {
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        }
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $candidate -UseBasicParsing
        if ((Get-FileHash $candidate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) { throw 'Integrite incorrecte.' }
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$baseline/$($item.Path)" -OutFile $original -UseBasicParsing
        Copy-Item -LiteralPath (Join-Path $repo $item.Path) -Destination $comparison
        & dart format $candidate $original $comparison | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Comparaison du formatage echouee.' }
        $actual = [IO.File]::ReadAllText($comparison).Replace("`r`n", "`n")
        $before = [IO.File]::ReadAllText($original).Replace("`r`n", "`n")
        $after = [IO.File]::ReadAllText($candidate).Replace("`r`n", "`n")
        if ($actual -cne $before -and $actual -cne $after) { throw "Source locale differente : $($item.Path). Aucun remplacement." }
    }
    foreach ($item in $files) {
        $saved = Join-Path $backup $item.Path
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $item.Path) -Destination $saved
        Copy-Item -LiteralPath (Join-Path $temp ('candidate/' + $item.Path)) -Destination (Join-Path $repo $item.Path) -Force
    }
    "SAUVEGARDE_CODE=$backup"
    Push-Location $frontend
    try {
        flutter analyze lib/features/chat/services/chat_giphy_service.dart test/chat_giphy_service_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        flutter test --reporter expanded test/chat_giphy_service_test.dart test/chat_gif_picker_test.dart test/chat_attachment_card_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
    } finally { Pop-Location }

    $key = Read-Host 'Cle API GIPHY pour IOS (pas le mot de passe)'
    if ([string]::IsNullOrWhiteSpace($key)) { throw 'Source iOS integree, cle non configuree.' }
    try {
        $encodedKey = [Uri]::EscapeDataString($key.Trim())
        $check = Invoke-RestMethod "https://api.giphy.com/v1/gifs/trending?api_key=$encodedKey&limit=1&rating=pg" -TimeoutSec 20
        if ($check.meta.status -ne 200) { throw 'InvalidKey' }
    } catch { throw 'Source iOS integree. Verification GIPHY impossible : aucune configuration iOS modifiee.' }

    $folder = Join-Path $env:LOCALAPPDATA 'EnactSpace\IOSRecipe'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $defines = Join-Path $folder 'ios-client-defines.json'
    if (Test-Path -LiteralPath $defines) {
        $config = Get-Content -LiteralPath $defines -Raw | ConvertFrom-Json
        Copy-Item -LiteralPath $defines -Destination (Join-Path $backup 'ios-client-defines.previous.json')
    } else {
        $config = [pscustomobject]@{ ENACTSPACE_API_URL = 'https://api-enactspace.kerunjombor.net' }
    }
    $config | Add-Member -MemberType NoteProperty -Name 'ENACTSPACE_GIPHY_API_KEY_IOS' -Value $key.Trim() -Force
    [IO.File]::WriteAllText($defines, ($config | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    'GIPHY_IOS_CONFIGURE_ET_CLE_VERIFIEE'
    'CONFIGURATIONS_WEB_ET_ANDROID_CONSERVEES'
    "CONFIGURATION_IOS=$defines"
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
