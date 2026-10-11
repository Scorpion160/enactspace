param(
    [Parameter(Mandatory = $true)][string]$Commit,
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$python = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
if (!(Test-Path -LiteralPath $python)) { throw 'Python 3.12 introuvable.' }
$files = @(
    @{ Path = 'frontend/lib/features/chat/services/chat_video_source.dart'; Hash = '31ea5475ccadd28df695972158864d11fbb162ed2de0cb317da18b1dd2f83177'; OldHash = $null }
    @{ Path = 'frontend/lib/features/chat/services/chat_video_source_native.dart'; Hash = '3cb3da75de9fd15e17dc1c22b749ce9d2f03f32e273d57aaf705b5fe177d835e'; OldHash = $null }
    @{ Path = 'frontend/lib/features/chat/services/chat_video_source_web.dart'; Hash = '70db32360ec317e6b9fc88fe117da1b36a242dd66209339f7dc239115863e0d2'; OldHash = $null }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_attachment_card.dart'; Hash = 'b7fce7b463fd24948f8328c8976a33c32522fe9420f61b51bc6b62010df8fd93'; OldHash = $null }
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = 'ccb28978653002983f4e145a85edb04779338b919f916392009889b8139ee401'; OldHash = 'd27f097e366816cba37e55d7d5a18ad35b13f5b7fdd3f7c3d630afc3e73a8447' }
    @{ Path = 'backend/app/services/email_delivery_service.py'; Hash = '77332b5a582909b58d1c571124f0d03b67907055b4d52dd357423cff4931057a'; OldHash = 'd47027bffc0b7aeab7fd8c6c651848e1cc6204aaf97682ce7f90ed8d67c1fd8d' }
    @{ Path = 'frontend/pubspec.yaml'; Hash = '47a1f8c3097150f370023187ebc7e84e91c5fea9ddd84ca8ffe07a97c36905dd'; OldHash = '59a0a1c6317726a048528ad7e334f1a91985aa3bd54e4ccb6ddafd57e9a6d82e' }
    @{ Path = 'frontend/lib/features/auth/screens/login_screen.dart'; Hash = '33ca2a679259d7b941953d3d798db4a9df682dde7f61bdd722c5a4de6564f5c6'; OldHash = '6e0ad16c0d89f88ba114d0746965ba69fbfbcaf086871d33291379fa1e988a69' }
    @{ Path = 'frontend/lib/features/splash/screens/splash_screen.dart'; Hash = 'b09741fc30d7efaadf643f4045ba490c16f2ccf840b2cc11c360b28e671fe05c'; OldHash = 'c92a07c88dbb2d28bdcd08074431b9ccee5f31a579fd32d459814118b7dd8d49' }
    @{ Path = 'frontend/lib/core/brand/enact_brand_lockup.dart'; Hash = '877502695a7be93f513658215a3a131c4f10ec00987adc1e66d0c8fddbb25d9b'; OldHash = $null }
    @{ Path = 'backend/tests/test_chat_email_privacy.py'; Hash = '3c92afd8e39294c86699748de2e18c634b00d1e4aa901947324b0df80f96e045'; OldHash = $null }
    @{ Path = 'frontend/test/chat_attachment_card_test.dart'; Hash = '1d2b74ab6a1c347752fabc5d567dd60b82b2d9da87ff207cffe1f378f98c16c9'; OldHash = $null }
    @{ Path = 'frontend/web/index.html'; Hash = 'a754e6c8e66d9ba14110313cfd15e69cd94ea36ab873fbc5eecf60a3329e9144'; OldHash = '5391d7608a6bb04a79dbf938e009b38d7a1d79cceb49b8001ef677d1bbf63a3f' }
    @{ Path = 'docs/CHAT_MEDIA_AND_BRANDING_20261011.md'; Hash = '5f11237f3237550984b0423f24043932abaf37366330d1096506dd84e71cfda8'; OldHash = $null }
)
function Get-CanonicalHash([string]$Path) {
    $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString(
            $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content))
        )).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
$temp = Join-Path $env:TEMP ('EnactSpace-Chat-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\chat-branding-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $target) {
            $actual = Get-CanonicalHash $target
            if ($actual -ne $item.Hash -and
                ($null -eq $item.OldHash -or $actual -ne $item.OldHash)) {
                throw "Source locale differente : $($item.Path). Aucun remplacement."
            }
        } elseif ($null -ne $item.OldHash) {
            throw "Source locale absente : $($item.Path)"
        }
        $download = Join-Path $temp $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) {
            throw "Integrite incorrecte : $($item.Path)"
        }
    }
    & $python (Join-Path $temp 'backend/tests/test_chat_email_privacy.py')
    if ($LASTEXITCODE -ne 0) { throw 'Tests confidentialite echoues : aucun remplacement.' }
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $target) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $saved
        }
    }
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp $item.Path) -Destination $target -Force
    }
    "SAUVEGARDE_CODE=$backup"
    'CORRECTIONS_CHAT_EMAILS_ET_LOGOS_INTEGREES'
    Push-Location (Join-Path $Repo 'frontend')
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Resolution des dependances echouee.' }
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } |
            ForEach-Object { $_.Path.Substring('frontend/'.Length) })
        dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        flutter analyze @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : sources sauvegardees, transmettre le journal.' }
        flutter test --reporter expanded test/chat_attachment_card_test.dart test/chat_privacy_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests Flutter echoues : transmettre le journal.' }
        'CHAT_MEDIAS_CONFIDENTIALITE_ET_LOGOS_TESTS_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
