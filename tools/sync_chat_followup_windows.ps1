param(
    [Parameter(Mandatory = $true)][string]$Commit,
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$base = 'cbaf02260f304feb950926fb94ef437e838b8762'
$python = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
if (!(Test-Path -LiteralPath $python)) { throw 'Python 3.12 introuvable.' }
$files = @(
    @{ Path = 'backend/app/api/routes/chat.py'; Hash = '5528f9d088daaa52d3a52e9806646b020a7a582b379b331ff56da0ca83c4516a'; OldHash = 'fd6296b4562e99d57a92472c6f3b35621da05a0fcd13bb3f66570c4486720db8' }
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = '5ff365848b64bf5e48043bcbad00bf69458fae071f273c45ce137cf22a453390'; OldHash = 'ccb28978653002983f4e145a85edb04779338b919f916392009889b8139ee401' }
    @{ Path = 'frontend/test/chat_attachment_card_test.dart'; Hash = '4926017f8a4bd830af5995f2107b97489f56413699f3132a424b00e3f246d90d'; OldHash = '1d2b74ab6a1c347752fabc5d567dd60b82b2d9da87ff207cffe1f378f98c16c9' }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_attachment_card.dart'; Hash = '25a5be58fee7a13d63c1f9c3c7bb721853368826f05f0b1591b6b5bf808c0131'; OldHash = 'b7fce7b463fd24948f8328c8976a33c32522fe9420f61b51bc6b62010df8fd93' }
    @{ Path = 'frontend/pubspec.yaml'; Hash = 'a64383afd9fb8c94e7e5b1ce9a816f57b12abbf0bad96f7b32b815d966aec378'; OldHash = '47a1f8c3097150f370023187ebc7e84e91c5fea9ddd84ca8ffe07a97c36905dd' }
    @{ Path = 'backend/tests/test_chat_thread_notifications.py'; Hash = '422ae514033502605c306fa0a56b5adab2f2cfd6f6f5f87e962719810eb4d538'; OldHash = $null }
    @{ Path = 'frontend/lib/features/chat/widgets/chat_gif_picker.dart'; Hash = '9cfa64beeb02a215652f63f9074d50b81d18cbe6c142f25e6b27f25dba2116e8'; OldHash = $null }
    @{ Path = 'frontend/test/chat_gif_picker_test.dart'; Hash = '5cfdaf8700b9a285ce419b97417710e43f60a20a257f806fd36b09dea58276be'; OldHash = $null }
    @{ Path = 'frontend/assets/chat/gifs/catalog.json'; Hash = '59d10a2270982dc6123e4fb07275ef887fab460333b42b0aa048240188796c93'; OldHash = $null }
    @{ Path = 'docs/CHAT_FOLLOWUP_20261011.md'; Hash = '1cbf8fb6470b2d24871f55d2685241b07713eda8bbb18b40b94b46fd9fcb91c9'; OldHash = $null }
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
$temp = Join-Path $env:TEMP ('EnactSpace-ChatSuite-' + [guid]::NewGuid().ToString('N'))
$candidate = Join-Path $temp 'candidate'
$baseline = Join-Path $temp 'baseline'
$localComparison = Join-Path $temp 'local-comparison'
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\chat-suite-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($item in $files) {
        $download = Join-Path $candidate $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) {
            throw "Integrite incorrecte : $($item.Path)"
        }
        if ($null -ne $item.OldHash) {
            $oldFile = Join-Path $baseline $item.Path
            New-Item -ItemType Directory -Path (Split-Path $oldFile) -Force | Out-Null
            Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$base/$($item.Path)" -OutFile $oldFile -UseBasicParsing
            if ((Get-FileHash -LiteralPath $oldFile -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.OldHash) {
                throw "Reference incorrecte : $($item.Path)"
            }
        }
    }
    # Format all three copies in the same project context; never format the original here.
    foreach ($root in @($candidate, $baseline, $localComparison)) {
        $front = Join-Path $root 'frontend'
        New-Item -ItemType Directory -Path $front -Force | Out-Null
        foreach ($name in @('pubspec.yaml', 'analysis_options.yaml')) {
            $contextFile = Join-Path $Repo "frontend/$name"
            if ((Test-Path -LiteralPath $contextFile) -and
                ($name -ne 'pubspec.yaml' -or !(Test-Path -LiteralPath (Join-Path $front $name)))) {
                Copy-Item -LiteralPath $contextFile -Destination (Join-Path $front $name) -Force
            }
        }
    }
    # Restore the candidate pubspec after copying formatter context.
    $pubspec = $files | Where-Object { $_.Path -eq 'frontend/pubspec.yaml' }
    $candidatePubspec = Join-Path $candidate 'frontend/pubspec.yaml'
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/frontend/pubspec.yaml" -OutFile $candidatePubspec -UseBasicParsing
    if ((Get-FileHash $candidatePubspec -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pubspec.Hash) {
        throw 'Integrite du pubspec incorrecte.'
    }
    foreach ($item in $files | Where-Object { $_.Path.EndsWith('.dart') }) {
        $target = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $target) {
            $copy = Join-Path $localComparison $item.Path
            New-Item -ItemType Directory -Path (Split-Path $copy) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $copy
        }
    }
    $stagedDart = @($files | Where-Object { $_.Path.EndsWith('.dart') } |
        ForEach-Object {
            Join-Path $candidate $_.Path
            if ($null -ne $_.OldHash) { Join-Path $baseline $_.Path }
            $copy = Join-Path $localComparison $_.Path
            if (Test-Path -LiteralPath $copy) { $copy }
        })
    dart format @stagedDart
    if ($LASTEXITCODE -ne 0) { throw 'Formatage preparatoire echoue : aucun remplacement.' }
    $snapshots = @{}
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $target) {
            $actual = Get-CanonicalHash $target
            $accepted = @(Get-CanonicalHash (Join-Path $candidate $item.Path))
            if ($null -ne $item.OldHash) {
                $accepted += Get-CanonicalHash (Join-Path $baseline $item.Path)
                $accepted += $item.OldHash
            }
            $accepted += $item.Hash
            $comparison = $actual
            if ($item.Path.EndsWith('.dart')) {
                $comparison = Get-CanonicalHash (Join-Path $localComparison $item.Path)
            }
            if ($actual -notin $accepted -and $comparison -notin $accepted) {
                throw "Source locale differente : $($item.Path). Aucun remplacement."
            }
            $snapshots[$item.Path] = $actual
        } elseif ($null -ne $item.OldHash) {
            throw "Source locale absente : $($item.Path)"
        } else {
            $snapshots[$item.Path] = $null
        }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        if ($null -ne $snapshots[$item.Path]) {
            if ((Get-CanonicalHash $target) -ne $snapshots[$item.Path]) {
                throw "Source modifiee pendant la preparation : $($item.Path)"
            }
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $target -Destination $saved
        } elseif (Test-Path -LiteralPath $target) {
            throw "Un fichier est apparu pendant la preparation : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $target = Join-Path $Repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $candidate $item.Path) -Destination $target -Force
    }
    "SAUVEGARDE_CODE=$backup"
    'DISCUSSIONS_PRIVEES_GROUPES_GIFS_ET_IMPORTS_CORRIGES'
    & $python (Join-Path $Repo 'backend/tests/test_chat_thread_notifications.py')
    if ($LASTEXITCODE -ne 0) { throw 'Tests des notifications echoues.' }
    & $python (Join-Path $Repo 'backend/tests/test_chat_email_privacy.py')
    if ($LASTEXITCODE -ne 0) { throw 'Tests confidentialite echoues.' }
    Push-Location (Join-Path $Repo 'frontend')
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Resolution des dependances echouee.' }
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } |
            ForEach-Object { $_.Path.Substring('frontend/'.Length) })
        flutter analyze @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        flutter test --reporter expanded test/chat_attachment_card_test.dart test/chat_gif_picker_test.dart test/chat_privacy_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests Flutter echoues : transmettre le journal.' }
        'CHAT_GROUPES_GIFS_ET_MEDIAS_TESTS_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
