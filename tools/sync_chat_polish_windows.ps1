param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '1acd1f24bcb00539a8cc49da9d1d096ffac2f150'
$stage = Join-Path $env:TEMP ('EnactSpace-ChatPolish-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\chat-polish-' + [guid]::NewGuid().ToString('N'))
$observedHashes = @{}
$files = @(
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = '8ca5b1624e8a6211a1a60adf032d31f39f03e54b777a4e3d00c80af9cc0ce1ec'; New = $false }
    @{ Path = 'frontend/lib/shared/layout/app_shell.dart'; Hash = '7f947dcf4b668498c568fc110f1eb5debf1b87d1c6cb9cc811b9afa39fdb9531'; New = $false }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_attachment_card.dart'; Hash = '900ca0acc85bb33808ddc2e2f6e19053a45a21bf5fbcb6f97c5d3b0645921572'; New = $false }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_gif_picker.dart'; Hash = '757635b0e073dd9f77dd02c07da7cfea4c88697d3506d449ee19f23830b12d06'; New = $false }
    @{ Path = 'frontend/lib/features/chat/services/chat_gateway.dart'; Hash = '9e3e21c161ce39c932b916c638d6b9d892e7026320cc29c2d641c6f79d4d40d2'; New = $false }
    @{ Path = 'frontend/lib/features/chat/services/chat_service.dart'; Hash = 'c2f952e82e558de731fc96058c7d794b710b4916dba6befe9cbfbecf2bc8a053'; New = $false }
    @{ Path = 'backend/app/api/routes/chat.py'; Hash = '9d428044fa44102c1fe5cd14a5b30fb3cbd019c2e7d04150c1a304fe64923942'; New = $false }
    @{ Path = 'frontend/test/chat_attachment_card_test.dart'; Hash = '2c0ad2df73d0c485c10a0337c57ed9583f008980de2a91b836bdc93407c2d4b8'; New = $false }
    @{ Path = 'frontend/lib/core/brand/enact_brand_lockup.dart'; Hash = 'dcf8aa7b56bd1e02c6592d0e32b44c552647b49c8b3a9b6203f383ae5cb04e62'; New = $false }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_shared_content.dart'; Hash = '4242ed55905ba074a22cf8514483040419ee6428a8675741d3bc75966013298e'; New = $true }
    @{ Path = 'frontend/web/index.html'; Hash = '520cd686d969004295e7b52f4d2a4e556f7b41f4d8f5ab8156fb0d1910e3055b'; New = $false }
    @{ Path = 'frontend/lib/features/splash/screens/splash_screen.dart'; Hash = '2592275dbc3415ce575a44614769dd5c52046ded8abfa025a68a6041f9c1b225'; New = $false }
    @{ Path = 'backend/tests/test_chat_shared_content.py'; Hash = 'e27c1eeac53fba64ad917eb190b53163549b9bc8df4775ce893683a0e8f60304'; New = $true }
    @{ Path = 'docs/CHAT_LAYOUT_AND_SHARED_CONTENT_20261012.md'; Hash = 'cc47581eac2f3729b4e96626c310167e1e7f4b3413fb7915041b1e6cec67a2a2'; New = $true }
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
        & flutter analyze lib/features/chat lib/core/brand/enact_brand_lockup.dart lib/shared/layout/app_shell.dart lib/features/splash/screens/splash_screen.dart test/chat_attachment_card_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --reporter expanded test/chat_attachment_card_test.dart test/chat_gif_picker_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'CHAT_LOGOS_MEDIAS_NAVIGATION_ET_INFOS_INTEGRES'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
