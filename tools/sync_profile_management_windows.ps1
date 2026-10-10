param([Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$temp = Join-Path $env:TEMP ("EnactSpace-Profiles-" + [guid]::NewGuid())
$backup = Join-Path $env:LOCALAPPDATA ("EnactSpace\CodeRollback\" + [guid]::NewGuid())
$files = @(
    @{ Path = 'backend/app/schemas/user.py'; Old = 'b7c34641a8b4f08efd772d314070737d7085248e8ffb2bff2d024bbb76a6fa79'; New = 'cb930601708aba265cd235b42fa0c9788c89dbb2d00c95f11cc6c647b6ac6001' }
    @{ Path = 'backend/app/api/routes/users.py'; Old = '404611a5bd98f409f4b77c906ee3f6a30aeef735f8736d854f66867a108ecffc'; New = 'b79a8d00b3a172b092140d4da0959d09d817747617b992df4e8f428541557241' }
    @{ Path = 'backend/app/services/alumni_integrity.py'; Old = '19ff621616e7de243f7f6d1f8d028da7a3fa33e04dc6ae39cc684010b389132f'; New = '9caf80512a95843173c3f32b301fc02c1e07609a3c145f3813964771058bf4e7' }
    @{ Path = 'backend/test_prelaunch_account_identity.py'; Old = 'b2c24bc3741caa0ef00dd1498700e6c10d15c6f9d3817275cd67db58f2314c22'; New = '923a64076d4eca4ccd86c79911a63ae9e6d6e2425e37745915b19c02a7e7536e' }
    @{ Path = 'backend/test_prelaunch_alumni_boundaries.py'; Old = '93702815ec827a986d1e59458ef21e12290150e45821a029910a3d7d1dd59b52'; New = '05e1e88215c4a936c976e7021bda6d41d5bd87ae0355b0f8ae919fb63170be49' }
    @{ Path = 'frontend/lib/features/members/services/members_service.dart'; Old = '35828e68956bd2ba02116c543c46d179ed7fca4d55c7eb798472a3633f00e871'; New = '237ba076d22434d112e2fb723d2b36ef7f82e4f37ded9a1b3542a0a4bddbd0be' }
    @{ Path = 'frontend/lib/features/members/screens/members_screen.dart'; Old = '42b2e70a12902279f460ce2e75e9b1c0c2f6351ebdbaae4b0a21aca6f6c7f419'; New = 'bdb9fb89f08ea2157d6de4581bb6f4d20a5476479e819e350c27bea03a85ea72' }
    @{ Path = 'frontend/lib/features/alumni/screens/alumni_profile_detail_screen.dart'; Old = '16546f95f17ae8877d56dc7676b94c7fe577ff6fde18cc4c44fab584fc08fc95'; New = '30b59fbcdb86fafa44d688b6970e17d4aacfff273f2c416eea8d9027359cb7ab' }
)
function Get-CanonicalHash($path) {
    $content = [IO.File]::ReadAllText($path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}
try {
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ((Get-CanonicalHash $local) -notin @($item.Old, $item.New)) {
            throw "Fichier local different : $($item.Path). Aucun remplacement."
        }
        $download = Join-Path $temp $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.New) {
            throw "Integrite incorrecte : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $saved = Join-Path $backup $item.Path
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $item.Path) -Destination $saved
    }
    foreach ($item in $files) {
        Copy-Item -LiteralPath (Join-Path $temp $item.Path) -Destination (Join-Path $repo $item.Path) -Force
    }
    Push-Location (Join-Path $repo 'frontend')
    try {
        flutter analyze lib/features/members/screens/members_screen.dart lib/features/members/services/members_service.dart lib/features/alumni/screens/alumni_profile_detail_screen.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse Flutter en echec.' }
        flutter test --reporter expanded test/alumni_year_followup_test.dart test/first_access_test.dart test/ui_final_acceptance_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests Flutter en echec.' }
        'GESTION_PROFILS_INTEGREE_CONTROLES_OK'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
