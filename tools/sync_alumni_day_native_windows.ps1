param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [switch]$PublishWeb
)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '1d5e57cb43afa0080dcf904ecd9ba3d4dbc77aaa'
$legacy = 'c598339cc444bdc8bf7a1ce845f88dbb654644f9'
$temp = Join-Path $env:TEMP ('EnactSpace-AlumniDayNative-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\alumni-day-native-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/app/app_router.dart'; Hash = '84152e2f3555f4f60f9b7e4bd09f7e06d636fea42abc91cba0f1884d46ba4552'; New = $false; BaselineHash = '50c66ccb4acfa322f26c934c1198029b7fd465c92360c69a2146128b4365fca5' },
    @{ Path = 'frontend/lib/core/widgets/preview_mode_scope.dart'; Hash = '6a7a0ac7491c57a17a01b8a2f671ac7c40184128d8978279de7bb2a0327854df'; New = $true },
    @{ Path = 'frontend/lib/features/archives/screens/archives_center_screen.dart'; Hash = '58dabdc6f194ea528c625cb8ed2f0db0aab40b00d159423b72cd45e4871b395e'; New = $false; BaselineHash = 'd027f9ca0c363318f860f575bc10d6531fa3d3e0fe743f82764d4aa0172cbe90' },
    @{ Path = 'frontend/lib/features/attendance/screens/attendance_screen.dart'; Hash = '9569afe69c5db303f70283d5940e845323be55d654454a7175365bf9cdb648ab'; New = $false; BaselineHash = 'c3c893ffac5eb70d2801a623caa13b153a00115e3e87c9c52de02d2f90c66100' },
    @{ Path = 'frontend/lib/features/attendance/screens/attendance_session_detail_screen.dart'; Hash = 'dc510bf11bd4200a92a487b276caadff9f58aa30c2b08dff264482f1ac472952'; New = $false; BaselineHash = '127a3ba3e14644532339d73036721bdba92ec1a7ae1752b5f4abf43d399590c8' },
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = '868c3c42c3e7ccdb19d656f1cc5d66192da9e8d1bea79ecb1b8dc8347f96a0f8'; New = $false; BaselineHash = '82beefac4030adf4ba5ac3d7dbdd88f67cc5cc94a1bff8dd650d3afd16de24cb' },
    @{ Path = 'frontend/lib/features/chat/widgets/chat_gif_picker.dart'; Hash = 'fd4f261e926a38b704f8e750fa99c8ffaaeb7a39aed006bdfff50f29ffd098ed'; New = $false; BaselineHash = '9f2fa497200afd3b3f6fc32bc48afda287a27f4ae668b0bcf721946426f1a56a' },
    @{ Path = 'frontend/lib/features/demo/demo_native_data.dart'; Hash = '30e79d89f51545b99818f91213a7d8cf2bd872fb19d68aee5593f57935af4652'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_native_experience.dart'; Hash = '9309f147db9f0ebcf092b53806b5cbcaf1b7842ee9c2383442eefbcd7627de1f'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_native_recruitment.dart'; Hash = '2c3cf52e37c4b03654ae1fa4beba33905ccc291f69bdd83aabba9d41a5440f44'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_native_runtime.dart'; Hash = 'c2413230c2d90eedf54c72d4601fb02c888469613ad03e3dae0bff26c1b8fa89'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_native_transport.dart'; Hash = 'c8ce0cc979476b849b5cc1bdc540b48b99d486ef284ed943c844b93a8f7cf59e'; New = $true },
    @{ Path = 'frontend/lib/features/demo/demo_screen.dart'; Hash = '20842ca18da474eccaa8d7755639cc0d217a87ebd06443fd3f270f8d9e3a6c83'; New = $false; BaselineHash = '6494d563622ab2ddb4ec807285a242f6e330eb9be4258528cc0c942c78273c05' },
    @{ Path = 'frontend/lib/features/documents/screens/document_detail_screen.dart'; Hash = '86c3877a6e9d3fb7a0122af50b6b0b5777646439588e0589dc338e8b5f8278fb'; New = $false; BaselineHash = 'ea9c893127ccc97dddad894c5451a34e12f235af56bfddb84535dedb4beaf345' },
    @{ Path = 'frontend/lib/features/events/widgets/event_form_dialog.dart'; Hash = '7716751069c58d3bd50e030f24349662c358283686935d0e43aa5bd5bc959168'; New = $false; BaselineHash = '559a24570b698a65f2fd1b292d40e8d69384bef2529a0f655c53b0d851682c67' },
    @{ Path = 'frontend/lib/features/finance/screens/finance_screen.dart'; Hash = 'fbf4974c3e08e1046b83244e177094466881a254453153f12877c523d10fd86d'; New = $false; BaselineHash = '972585f5185169c5e24a6f7948bd782fc357e26be133dd755cd23876b0d8e44d' },
    @{ Path = 'frontend/lib/features/impact/screens/impact_records_screen.dart'; Hash = '8057210bde10a32b1a945e091a48000ecedc8a880918e04d702ac073a9cf0baa'; New = $false; BaselineHash = 'f522b8f58f4f3c821b270f449efa0cb5cc5ab64b95848027c89f1f9e7e5f6d81' },
    @{ Path = 'frontend/lib/features/meetings/screens/meeting_detail_screen.dart'; Hash = 'c6d8430ace26440b6eec39ea20456bbd1089ee7b3b5867743ea5aeab66fe7c4b'; New = $false; BaselineHash = '06944615ad3719b1ca786bc1b81fc2199fb6c33f09bbcfac1f915df16e2b4476' },
    @{ Path = 'frontend/lib/features/meetings/screens/meetings_screen.dart'; Hash = '3f320b96ba6a60e71903246d897653a89091750da9e2042080f8725fb45c94a1'; New = $false; BaselineHash = 'bcaa31d883c31c5c88d61495ec3756d395e9e26719a600081db2531bd7b54872' },
    @{ Path = 'frontend/lib/features/members/screens/member_profile_screen.dart'; Hash = '22b622fc7f8c11a619c1dd080df7a0bbcdd45538f42ad89f4ae48528aec13f89'; New = $false; BaselineHash = '8500d124157ebe4b164640cbedcdd5651e6d5c7c79e6707bb019c88efcedd359' },
    @{ Path = 'frontend/lib/features/members/screens/members_screen.dart'; Hash = 'dcffe18476fb171dd3aad90a2b47d608e6f4bdbf35015739cc3170d066205f59'; New = $false; BaselineHash = 'a68007c4c38149bd84d6478a24e66eadc9ef9be392c1f46fd2778ece63591ac6' },
    @{ Path = 'frontend/lib/features/profile/screens/my_profile_screen.dart'; Hash = '4c1ed714d505b093dae994904f7476d5b11e67097c49e9edcf1c9263bd2c913f'; New = $false; BaselineHash = '62c4564a4f061479d7d967c35fc1605ad3e5cd4c236f06512be565bbf052527c' },
    @{ Path = 'frontend/lib/features/settings/controllers/settings_controller.dart'; Hash = '13103e7cff58c52c363dac0d503a14a9937ecd503ffd675f1e169f83441deeab'; New = $false; BaselineHash = 'e6ba949b621454d4b186dd4aa216f4706e07de91116ba9844431e7246c8aadfb' },
    @{ Path = 'frontend/lib/features/settings/screens/settings_screen.dart'; Hash = '08830578d0fa373327c742e998cf88b65e9381ae27b900f064db39c93f9cafbe'; New = $false; BaselineHash = 'cdf7a855215aae24938ffade735d13b41f998808de2187e27ee5212481a0de8e' },
    @{ Path = 'frontend/lib/shared/attachments/attachment_picker.dart'; Hash = '5b277d10829eff41c00749aaa3874bdd604d2644634987d84d41d793fb9205fd'; New = $false; BaselineHash = '1eaebc6c2fed95319ad1fbfe13fe9b27a1bf7a9d1f27a688ae88b9f715a1639b' },
    @{ Path = 'frontend/lib/shared/layout/app_shell.dart'; Hash = 'a1851b51c3e6bd523a4f3717bc6d027300be4e9a285c67c173b63848e40ca181'; New = $false; BaselineHash = '8572b9f822835f4b707dd9e1fda33b77d7a5138817fbffa1d0d319d15fd26f2a' },
    @{ Path = 'frontend/test/alumni_day_demo_test.dart'; Hash = '7fe8386a91e8fcea593fc989b46a4e6e42c585ca6bed1c17fdefd65db8cb712e'; New = $false; BaselineHash = '70e19f427f275973d54ed7b513f31f5784a10a2e88fe47af5804989817999c38' },
    @{ Path = 'frontend/test/alumni_day_native_test.dart'; Hash = 'f719e6a09d468aa7a0fd8dea7fdd23b58a50d837e598df7c41a5649d2c3573ae'; New = $true }
)
function Canonical([string]$Path) {
    [IO.File]::ReadAllText($Path).Replace("`r`n", "`n").TrimEnd()
}
function DownloadChecked([string]$Ref, [string]$Path, [string]$Target, [string]$Hash) {
    New-Item -ItemType Directory -Path (Split-Path $Target) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Ref/$Path" -OutFile $Target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash) {
        throw "Integrite incorrecte : $Path. Aucun remplacement."
    }
}
if (!(Test-Path -LiteralPath (Join-Path $frontend 'pubspec.yaml'))) { throw 'Depot Flutter introuvable.' }
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        DownloadChecked $Commit $item.Path $candidate $item.Hash
        $local = Join-Path $repo $item.Path
        if (!(Test-Path -LiteralPath $local)) {
            if (!$item.New) { throw "Source locale absente : $($item.Path)" }
            continue
        }
        $observed[$item.Path] = (Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash
        $comparison = Join-Path $temp ('local/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $comparison
        $variants = @($candidate)
        if ($item.BaselineHash -and $item.BaselineHash -ne $item.Hash) {
            $original = Join-Path $temp ('baseline/' + $item.Path)
            DownloadChecked $baseline $item.Path $original $item.BaselineHash
            $variants += $original
        }
        if ($item.LegacyHash -and $item.LegacyHash -ne $item.BaselineHash -and $item.LegacyHash -ne $item.Hash) {
            $original = Join-Path $temp ('legacy/' + $item.Path)
            DownloadChecked $legacy $item.Path $original $item.LegacyHash
            $variants += $original
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
    $candidateDart = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { Join-Path $temp ('candidate/' + $_.Path) })
    & dart format @candidateDart
    if ($LASTEXITCODE -ne 0) { throw 'Syntaxe candidate incorrecte : aucun remplacement.' }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ($observed.ContainsKey($item.Path)) {
            if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash -ne $observed[$item.Path]) { throw "Source modifiee pendant la preparation : $($item.Path)" }
        } elseif (Test-Path -LiteralPath $local) { throw "Nouveau fichier apparu : $($item.Path)" }
    }
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $rollback = @()
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        $existed = Test-Path -LiteralPath $local
        $rollback += @{ Path = $item.Path; PreviouslyExisted = $existed }
        if ($existed) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    [IO.File]::WriteAllText((Join-Path $backup 'rollback.json'), ($rollback | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp ('candidate/' + $item.Path)) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze --no-pub @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/alumni_day_demo_test.dart test/alumni_day_native_test.dart test/recruitment_public_test.dart test/alumni_gamification_academy_impact_test.dart test/biometric_unlock_test.dart test/auth_session_test.dart test/widget_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : publication non lancee, transmettre le journal.' }
        & flutter test --no-pub --reporter expanded test/ui_final_acceptance_test.dart --name 'matrice routes|login responsive'
        if ($LASTEXITCODE -ne 0) { throw 'Verification routes ou connexion echouee : publication non lancee.' }
        & flutter test --no-pub --reporter expanded test/settings_help_legal_about_test.dart test/communication_test.dart test/dashboard_tasks_test.dart test/archives_responsive_test.dart test/profile_preview_navigation_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Regression detectee : publication non lancee, transmettre le journal.' }
        'DEMO_ECRANS_REELS_ET_ISOLATION_TESTS_OK'
    } finally { Pop-Location }
    if (!$PublishWeb) { 'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'; return }
    $builder = Join-Path $temp 'build_publish_web_windows.ps1'
    DownloadChecked '5dc33c30398db9a040debb68a32778cc255f5e66' 'tools/build_publish_web_windows.ps1' $builder '2535e443cc5de435cd4d9953c6ac563a1583d05aa53879d4a96aae33eb9c7656'
    & $builder -Version '1.0.19' -BuildNumber 22 -Publish
    if (!$?) { throw 'Publication interrompue : transmettre le resultat.' }
    $id = [guid]::NewGuid().ToString('N')
    $publicCatalog = Join-Path $temp 'heritage.public.json'
    Invoke-WebRequest "https://enactspace.kerunjombor.net/assets/assets/img/alumni_day_heritage.json?release=$id" -OutFile $publicCatalog -UseBasicParsing
    $catalogHash = '9007d2ac6ab42550f1227db3c9ac924c5ad506bf942f261a2f0f1b364704f1a9'
    if ((Get-FileHash $publicCatalog -Algorithm SHA256).Hash.ToLowerInvariant() -ne $catalogHash) { throw 'Catalogue public incorrect : transmettre le resultat.' }
    $demo = 'https://enactspace.kerunjombor.net/#/demo'
    'DEMO_ECRANS_REELS_1_0_19_22_PUBLIEE_ET_VERIFIEE'
    "URL_DE_L_AFFICHE=$demo"
    'BACKEND_ANDROID_ET_PAYDUNYA_NON_MODIFIES'
    Start-Process $demo
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
