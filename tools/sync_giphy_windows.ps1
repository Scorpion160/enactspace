param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = 'c6c04fbdf67310985b6dd1b166b5f8761f2ed134'
$stage = Join-Path $env:TEMP ('EnactSpace-ChatPolish-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\chat-polish-' + [guid]::NewGuid().ToString('N'))
$observedHashes = @{}
$files = @(
    @{ Path = 'frontend/lib/features/chat/widgets/chat_gif_picker.dart'; Hash = '9f2953e85d260af4eff8dd56debee6e6cd7bac9c125297db5ccc2e53b352e5fe'; New = $false }
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = 'a6fdd42985a6ea4c473a4d332520109a6ee7262f32962a5a40bf96843c91069b'; New = $false }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_shared_content.dart'; Hash = 'db48a5f5a8b37f34617a99d6cc8968f6b179cec625f31341d7becb56999e43ec'; New = $false }
    @{ Path = 'backend/app/api/routes/chat.py'; Hash = '90b2ba0e16acded9cb2d8e48ee605e16e7713ae577a18712cde988af297ee6e1'; New = $false }
    @{ Path = 'backend/tests/test_chat_shared_content.py'; Hash = '289ff855a4f57c0f65537af3606d471154e6292e3c41725a561be5fc4f456ba6'; New = $false }
    @{ Path = 'frontend/lib/features/chat/services/chat_giphy_service.dart'; Hash = '65b29f76367c4fbeb899553c4d98e808cf6a8d7d14bc3d6d6a4cd4c9b957295d'; New = $true }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_giphy_panel.dart'; Hash = 'c9ef7c38f12c3923d7967c94c648cbc6ba7df15b62d196f217a6ee14f72a8608'; New = $true }
    @{ Path = 'frontend/test/chat_giphy_service_test.dart'; Hash = '174243fa8edd6f9d2edab54577d5bd3134b224f49c6d98b0f07e1ac252b7d86b'; New = $true }
)
function Canonical($path) {
    return [IO.File]::ReadAllText($path).Replace("`r`n", "`n").TrimEnd()
}
try {
    New-Item -ItemType Directory -Path $stage | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $stage ('candidate/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $candidate) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $candidate -UseBasicParsing
        if ((Get-FileHash $candidate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) {
            throw "Integrite incorrecte : $($item.Path)"
        }
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $observedHashes[$item.Path] = (Get-FileHash $local -Algorithm SHA256).Hash
            $comparison = Join-Path $stage ('local/' + $item.Path)
            New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $comparison
            $variants = @($candidate)
            if (!$item.New) {
                $original = Join-Path $stage ('baseline/' + $item.Path)
                New-Item -ItemType Directory -Path (Split-Path $original) -Force | Out-Null
                Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$baseline/$($item.Path)" -OutFile $original -UseBasicParsing
                $variants += $original
                if ($item.Path.EndsWith('chat_gif_picker.dart')) {
                    $text = [IO.File]::ReadAllText($original).Replace("import 'dart:typed_data';", '')
                    [IO.File]::WriteAllText($original, $text, [Text.UTF8Encoding]::new($false))
                }
            }
            if ($item.Path.EndsWith('.dart')) {
                & dart format $comparison @variants | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Comparaison du formatage echouee.' }
            }
            $known = $false
            foreach ($variant in $variants) {
                if ((Canonical $comparison) -ceq (Canonical $variant)) { $known = $true }
            }
            if (!$known) { throw "Source locale differente : $($item.Path). Aucun remplacement." }
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ($observedHashes.ContainsKey($item.Path) -and
            (Get-FileHash $local -Algorithm SHA256).Hash -ne $observedHashes[$item.Path]) {
            throw "Source modifiee pendant la preparation : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $stage ('candidate/' + $item.Path)) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze lib/features/chat lib/core/brand/enact_brand_lockup.dart lib/shared/layout/app_shell.dart lib/features/splash/screens/splash_screen.dart test/chat_attachment_card_test.dart test/chat_giphy_service_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --reporter expanded test/chat_attachment_card_test.dart test/chat_gif_picker_test.dart test/chat_giphy_service_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'GIPHY_ET_ELEMENTS_PARTAGES_SOURCES_INTEGRES'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
