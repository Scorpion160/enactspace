param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$items = @'
[{"Path":"README.md","Old":"6e41a5fd0774a491b463d65608a0b2caa6a19a1c6071ec96aaf42bbc87741631","New":"4fbc4b1459ec77a55090d8ee693ffb256dfad116fb8850e697114db467892a59"},{"Path":"CHANGELOG.md","Old":"99b907b6f4c16af912a5d28b07e8b825f0ede0d38ff0e40d332e0b1815489dc2","New":"4e6edc62514ad37a77be54da6e2cda6abd3cccdb5dbbd4bb96ed12f8115ab350"},{"Path":"docs/README.md","Old":"cb693e30ffb0234759c3fbeb6eb55d1885fc35ce6a210d98ca3b5a750697b9fe","New":"9b1ead16e4b2bc631ea9641c5a5b0c2f6de03e8cba15707d4f666bc7376c1b6e"},{"Path":"docs/ARCHITECTURE.md","Old":"d1571e874269e966be03af7d64de9a90acc0cadb62121d0776aa570684ff2bf0","New":"a464f4df729d654a36ef80665f20e0443fd8a3c96fbc4aedafa1580e3cf9f6c1"},{"Path":"docs/DEVELOPMENT.md","Old":"46326b65bf66e7e0b9787ddd239878767b47e13bb2f6f3b56f04be57f2a9f2e2","New":"1dc08f6425fbee9db6789ffdd8fb3dff181c8f57ad01fb98fb7c1de58a37ce63"},{"Path":"docs/TEST_MATRIX.md","Old":"56595e67dae8308284df103bed20958cf1100b7baaf509afdded575606d69581","New":"e6a76ed9b3d682a168c9e9dcc319615f4f76f9ee3993c7d4661bf04007e0d372"},{"Path":"docs/OPERATIONS_RUNBOOK.md","Old":"5404e5b43ef4d8f508b20eb5d06e0890f4c5af7edc736ec479012fc9cc674ac6","New":"488eaea1355cc7cff12e6a26b78f32e206af3017a7c328216a8fb2dc3f2b357b"},{"Path":"docs/SECRETS_AND_ENVIRONMENTS.md","Old":"0d7d9cd8b1633ed948a67ed6dc57fd311f567a77b7627e94310f23654f12a27a","New":"fafb720cc2d5e51c50475e60c375810a8555e35fa10e083fe2f210ebd1bbe054"},{"Path":"docs/MOBILE_RELEASE_AND_PUSH.md","Old":"a34a0d348ac35324c674e59db10e2e7e051ce111861100e08796a42dd0255c09","New":"e635b3e8ffc34b5075c1fe2bd9321cb70e01a1d92c40af63a423c5e90dafaa6f"},{"Path":"docs/RELEASE_CHECKLIST.md","Old":"f779ecfd9dbbf030e027025e5ee68046731ee7a5700aa1114fdc0f199a062d3c","New":"c8704db106f58265893fb2258e5370dfa83a9f7958e648220b927ede5e8ab1ae"},{"Path":"docs/POLE_IT_HANDOFF.md","Old":"6e42c9b03db58e78f74c5fa674fffbf21d60c5fdc28cd888084e0810925dad78","New":"77f3a4a7dd4b6eff9bbff130ddbcb3a98efbf7e97e5b1c77c3825bab80507fc2"},{"Path":"docs/ARTIFACT_PROVENANCE.md","Old":"8702fc3f7f96d7bb860b15d61b5cc2214d63c47610d431de65943beafc514010","New":"a87f4d679a4109ab0e7695761fb932c1d02429452b73bb7d813312515e67d156"},{"Path":"docs/RELEASE_EVIDENCE_INDEX.md","Old":"ebdbf7bbbfa065dc87e0dafe8ce2267bd98096859695a8154f2abaeed8f70c10","New":"130c575a80834d78d0091787c4f8bb604b75eeac74c6aa5dc1ca05a8a835b888"},{"Path":"docs/FIRST_ACCESS_ONBOARDING.md","Old":"a2bb777b175a165ea10ec0021a4f746160706afb1df46acf07d662bb289c4f11","New":"b66d1c4ee1119e3ce903c0e98ba54c7e79825fa5ecf5458e4163bc213d8524de"},{"Path":"docs/FIREBASE_WEB_DEPLOYMENT.md","Old":"bef014710eda12b4e6cc6507ae0a1005047b4c2160e502bc41d619c4480e2ae0","New":"84c27bc23c0d50a083afe8165a71e2d3ce2238cd31e8ed9ccf528c7d894d3a02"},{"Path":"docs/BACKUP_RECOVERY_WINDOWS.md","Old":"2b97a5f1287cced1fe3a54bf14e0c99787f412fc6fe34231cb7c409e5e0787d2","New":"a3727a623f3de8c178a0a1970ca329979bd31bbd8b41f045b43a4f0e45f390dd"},{"Path":"docs/releases/20261010-release-1.0.13.md","Old":null,"New":"927dcb595dce139a55841d14d627bf5d6e66693626445b6eaafb054948a05535"},{"Path":"docs/MESSAGING_TROUBLESHOOTING.md","Old":null,"New":"36b31c9b76c26838edd7cbcd26e6a187da967e6ed48a6b65e08682dfb44770d6"}]
'@ | ConvertFrom-Json
function Get-CanonicalHash([string]$Path) {
    $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
$temp = Join-Path $env:TEMP ('EnactSpace-Docs-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\docs-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $items) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            if ((Get-CanonicalHash $local) -notin @($item.Old, $item.New)) {
                throw "Documentation locale differente : $($item.Path). Aucun remplacement."
            }
        } elseif ($null -ne $item.Old) {
            throw "Documentation requise absente : $($item.Path)"
        }
        $download = Join-Path $temp $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.New) {
            throw "Integrite incorrecte : $($item.Path)"
        }
    }
    foreach ($item in $items) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $items) {
        $local = Join-Path $Repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp $item.Path) -Destination $local -Force
    }
    'DOCUMENTATION_1_0_13_INTEGREE'
    "SAUVEGARDE_CODE=$backup"
    'AUCUN_BUILD_NI_DEPLOIEMENT'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
