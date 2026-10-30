param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-f0-9]{40}$')][string]$Commit,
    [switch]$NoPreview
)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = 'ad3229a1e20d2020b12fd7622dd77c2913872780'
$temp = Join-Path $env:TEMP ('EnactSpace-CompactFilters-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\compact-filters-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'docs/COMPACT_FILTERS_20261030.md'; Hash = 'fa239d76817a478b830d3a3d94ca739f78418ca715bd1197b82ec480f09937e8'; New = $true; Binary = $false; BaselineHash = '' },
    @{ Path = 'frontend/lib/features/academy/screens/academy_home_screen.dart'; Hash = '9bfeb015eb256fd397e3f6a87a3876550c5b33792720002bbe6a50d213f0cb5d'; New = $false; Binary = $false; BaselineHash = 'd5fa047199b210bd7206b27a5ffea9d9f947a9936897f4d5f761479a20c3ad14' },
    @{ Path = 'frontend/lib/features/alumni/screens/alumni_screen.dart'; Hash = 'f2f6cff8b6fb3ae2d173c91fe59bbd65330879b0162ea42d92f3eb076b1ab924'; New = $false; Binary = $false; BaselineHash = '984b6b686354fa792997457567b3c19594bd3b1388bdb33a635781f56064ee8b' },
    @{ Path = 'frontend/lib/features/archives/screens/archive_minutes_screen.dart'; Hash = '01ace108f5129580fa36353b16b7288fda2dfcd0b2e8d1a478cc4fce144afb62'; New = $false; Binary = $false; BaselineHash = '8fb214d470ce005662b6f8ba7e4c658e0c341630f1cbfe75ac856d00530abd5d' },
    @{ Path = 'frontend/lib/features/archives/screens/archives_center_screen.dart'; Hash = 'a3ab4eb436306fc6b64e61e6ad276d1786ddfae50a2097891e49ddc646dddf76'; New = $false; Binary = $false; BaselineHash = '58dabdc6f194ea528c625cb8ed2f0db0aab40b00d159423b72cd45e4871b395e' },
    @{ Path = 'frontend/lib/features/archives/screens/archives_center_sections.dart'; Hash = 'ba31d92cb7dd64fc56f69cf43e73e98d49d5340a92727eef76d619cbd504b5cc'; New = $false; Binary = $false; BaselineHash = '4316fc4cec67f324799176767a95d3ae688819e5e2db5f8922680b9379cd167e' },
    @{ Path = 'frontend/lib/features/attendance/screens/attendance_nfc_enrollment_screen.dart'; Hash = '441590e8fc889c8e24adae1a6503c4ea9fd4e0e9a385b6c36ebf667a6182645f'; New = $false; Binary = $false; BaselineHash = 'f2875282336ccc1c7056857f29a0f38d6a85337ac4fcfad53458071377ff76de' },
    @{ Path = 'frontend/lib/features/attendance/screens/attendance_screen.dart'; Hash = '9a6f1467052ae6422235e00facc583aacc7b673c70edb86d39b4349e47144cb7'; New = $false; Binary = $false; BaselineHash = '9569afe69c5db303f70283d5940e845323be55d654454a7175365bf9cdb648ab' },
    @{ Path = 'frontend/lib/features/attendance/screens/attendance_session_detail_screen.dart'; Hash = 'c0bc24a62ea4acbf37c51fb9d2ea2dff4015b461cabdfe19bdb934ef954beb36'; New = $false; Binary = $false; BaselineHash = 'dc510bf11bd4200a92a487b276caadff9f58aa30c2b08dff264482f1ac472952' },
    @{ Path = 'frontend/lib/features/chat/screens/chat_screen.dart'; Hash = 'def7099c22a28f18a981e38f4d1eaba3bfb171fbe1b344ee5afa1289b7346769'; New = $false; Binary = $false; BaselineHash = '868c3c42c3e7ccdb19d656f1cc5d66192da9e8d1bea79ecb1b8dc8347f96a0f8' },
    @{ Path = 'frontend/lib/features/demo/demo_screen.dart'; Hash = 'c81a1420f38e24dafda7f57abc18abf00585e0ea3a21e6016090426a5625adda'; New = $false; Binary = $false; BaselineHash = '20842ca18da474eccaa8d7755639cc0d217a87ebd06443fd3f270f8d9e3a6c83' },
    @{ Path = 'frontend/lib/features/documents/screens/documents_screen.dart'; Hash = '214e8111627e2f7297a59176aae759f2762a4659e43fe0c36b771f3ec90d21a7'; New = $false; Binary = $false; BaselineHash = '2429e17bda996514d2dc81ea5b40fbfaa4a4b614d8001061b0571d35ef6e7c73' },
    @{ Path = 'frontend/lib/features/events/screens/events_screen.dart'; Hash = '1406b32dc4412fc7c365dea3f28e5d6bd1059cf30bbd89bb5282ff7e305613d2'; New = $false; Binary = $false; BaselineHash = 'f9d15059d18cd80da44cb3afc72f3ccc240d2664476713203437e3da65ff5dda' },
    @{ Path = 'frontend/lib/features/finance/screens/finance_screen.dart'; Hash = '637dc365b42bb1776de7ad077e0f33e3e836bfb447ba0b925e5f249253fdb954'; New = $false; Binary = $false; BaselineHash = 'fbf4974c3e08e1046b83244e177094466881a254453153f12877c523d10fd86d' },
    @{ Path = 'frontend/lib/features/first_access/screens/first_access_management_screen.dart'; Hash = '76aacaaf91ddd275c84c38c5f6a0dfae66edaff885edaea70fdc408defb67503'; New = $false; Binary = $false; BaselineHash = '7157c2f84557e44c7f5325214c4f11fe7a2e36c0713906219333a7778086b801' },
    @{ Path = 'frontend/lib/features/help/screens/help_management_screen.dart'; Hash = '235bd3829ee6c6d0517e1af4bcb92a3d48498643387b3a0740e82a65808af941'; New = $false; Binary = $false; BaselineHash = 'd2b4fffb92de609b79bd84e0416ccc766c11dc2050870425cf9835b9c888a7f8' },
    @{ Path = 'frontend/lib/features/help/widgets/help_guide_panel.dart'; Hash = '9937ed4de8a9597c98c71165743b2996cdee1d20f2e646c6846dbdcdffa90ba7'; New = $false; Binary = $false; BaselineHash = '079aaf981819ca3d1dd8fdca5fdb06b1420843762f334b532ba1feb0001ec39b' },
    @{ Path = 'frontend/lib/features/meetings/screens/meetings_screen.dart'; Hash = 'b5c05b6a92ab60575b892c134c601cc145a7ef7210a3bcd0ca08d0b3490b902f'; New = $false; Binary = $false; BaselineHash = '3f320b96ba6a60e71903246d897653a89091750da9e2042080f8725fb45c94a1' },
    @{ Path = 'frontend/lib/features/members/screens/members_screen.dart'; Hash = '2c32fb15d75c7455463dc3e08e0d2253fb7de8c907b68f9d7ed08200f599a5ef'; New = $false; Binary = $false; BaselineHash = 'dcffe18476fb171dd3aad90a2b47d608e6f4bdbf35015739cc3170d066205f59' },
    @{ Path = 'frontend/lib/features/notifications/screens/notifications_screen.dart'; Hash = 'ad1b2ad2e3cdfc49203c44401bf4fa1566ab097a9a114616b142ce6172b1aee6'; New = $false; Binary = $false; BaselineHash = '09c3dac981e53b92edaee247ab3e942adea05dba40c915f45ff7856a81311a8d' },
    @{ Path = 'frontend/lib/features/poles/widgets/poles_portfolio_widgets.dart'; Hash = '14f0751de0df9c58c5878db0b7be480807be4d4634eb9bcc86bc6d0f574a12da'; New = $false; Binary = $false; BaselineHash = '20101a4c47b53edd4036c31a8b021cd06088fa1c9c1833bd2c10989313680689' },
    @{ Path = 'frontend/lib/features/posts/screens/posts_screen.dart'; Hash = 'ec85ddd067c19eb1e40e668c1c2ce985d853155e1556da8b2a955156c533f4df'; New = $false; Binary = $false; BaselineHash = '81fdf2bf7b2f27e5d1a9085b58472edcbd535b37ba5dcb25d90cb77205c2d566' },
    @{ Path = 'frontend/lib/features/projects/screens/projects_screen.dart'; Hash = '0cf3dabeca88adec318b2cdfc9f530c3b7c7ac264e47338244c12510b16cca31'; New = $false; Binary = $false; BaselineHash = 'f7e131aab6cd2ff8b333e27d3fab224b9b470b82c1cc9c99022f4112a0b73167' },
    @{ Path = 'frontend/lib/features/projects/widgets/projects_portfolio_widgets.dart'; Hash = 'f597b6c77aa3ffca18252251027879786ba517f9d3f8cd479d7ea9a8b322ceb9'; New = $false; Binary = $false; BaselineHash = '324fee70d288e42c04f5547409bcf6805f445452b036d430b5e84d94668269c5' },
    @{ Path = 'frontend/lib/features/recruitment/screens/internal/internal_recruitment_screen.dart'; Hash = '9942a2a7a171b2cf1df221506ec6bab14dddb9a4c5a0453df057f11fb9ab1be2'; New = $false; Binary = $false; BaselineHash = 'a7c2f62634845e741363ca8590584cf19311b711d1cdc104e2db964dbe8e2265' },
    @{ Path = 'frontend/lib/features/recruitment/screens/recruitment_screen.dart'; Hash = 'd4ad9675b9dcb14702bc4872e8efa1151048cd491090ba5b0c884a22ab667d2a'; New = $false; Binary = $false; BaselineHash = '13c35e6f751cc3e71af796cfb019bf86d719e5c8dae4f6acaa30ceb72f6e1e33' },
    @{ Path = 'frontend/lib/features/recruitment/widgets/internal/recruitment_internal_widgets.dart'; Hash = '1f96849ffce51b54d1fde95ee81448aacaf42e6b5e38bdad6023a1a6c299edfc'; New = $false; Binary = $false; BaselineHash = '135ddb7a424a9a9954bbdfc029b29a3c88223b34fd9d6ce6eb133c623633bb33' },
    @{ Path = 'frontend/lib/features/tasks/widgets/task_filters.dart'; Hash = '745004d76f03edd4309748e63e80b525479518844d9ae2e7c0e3bbb550fcc094'; New = $false; Binary = $false; BaselineHash = 'd56e8b9a79400b03441bc767438ec34520757dbd3e8ceb0bec9274ab372a79b6' },
    @{ Path = 'frontend/lib/features/veille/screens/veille_screen.dart'; Hash = '9368c23f8a09d69bd0a014a6298b1cca4affb76f264a6fc5a434eea3c3081f47'; New = $false; Binary = $false; BaselineHash = 'c56896bf6b9cdf653fa465142e89c7b6c9e249b1b4cbe0851b4057cd1dbf4a08' },
    @{ Path = 'frontend/lib/shared/ui/app_filter_toolbar.dart'; Hash = '6af7427bca956902cf4b2e9356887be20c49a9dd7d22f77b60ef9a6741bc4b28'; New = $true; Binary = $false; BaselineHash = '' },
    @{ Path = 'frontend/test/app_filter_toolbar_test.dart'; Hash = '9f365046aab6e34b99f2a4b9e538f6dce059cd3d5a1e64ea0c6fb78ea38180a2'; New = $true; Binary = $false; BaselineHash = '' },
    @{ Path = 'frontend/test/dashboard_tasks_test.dart'; Hash = '697960b02f577674419945ee7b2fc0b4dfc843668f49c083b82044fee784d7a7'; New = $false; Binary = $false; BaselineHash = 'f06c20fbd1c55f0b512bec1ee8233dbad0908c7e04076ea95cb177051301df72' },
    @{ Path = 'frontend/test/events_documents_test.dart'; Hash = '3341e91346a98aa560c996cf1da95503f2f57665148d364d0a95a25d89586431'; New = $false; Binary = $false; BaselineHash = '5308796f37d59a16f07e203741de8856270852b9c94a644f6bf74c00e377a7dd' },
    @{ Path = 'frontend/test/poles_portfolio_test.dart'; Hash = '82bab92e83e5e32e919c4e4449e8841a70934f2c6a42af653fbf1e698d08c7ac'; New = $false; Binary = $false; BaselineHash = '2f4ec152ecfc043ebcd7de4d735d05a60ef3c31382f07ba494deec6c51559645' },
    @{ Path = 'frontend/test/projects_portfolio_test.dart'; Hash = 'e63f3122a6f4cb861b3a97929abdafe484eb792cd271d738bef95f0198c50bea'; New = $false; Binary = $false; BaselineHash = 'c17236182615fedfcdb1d88a09b83878257e5ee04e93b5c56c04c54c3b4f5849' },
    @{ Path = 'frontend/test/recruitment_internal_test.dart'; Hash = 'f0bdff6003bc9bcb79f8000c25b22a50d8e2c975d90b3f5fbb2b52861534fa1b'; New = $false; Binary = $false; BaselineHash = '72beea0fb93ac340387bcbd3d9e30e7303d8171084b2c74655046152588c9677' }
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
        if ($item.Binary) {
            if ($observed[$item.Path].ToLowerInvariant() -ne $item.Hash) {
                throw "Illustration locale differente : $($item.Path). Aucun remplacement."
            }
            continue
        }
        $comparison = Join-Path $temp ('local/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
        Copy-Item -LiteralPath $local -Destination $comparison
        $variants = @($candidate)
        if ($item.BaselineHash -and $item.BaselineHash -ne $item.Hash) {
            $original = Join-Path $temp ('baseline/' + $item.Path)
            DownloadChecked $baseline $item.Path $original $item.BaselineHash
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
    $previews = Join-Path $backup 'previews'
    New-Item -ItemType Directory -Path $previews | Out-Null
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze --no-pub @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --no-pub --reporter expanded "--dart-define=FILTER_CAPTURE_DIR=$previews" test/app_filter_toolbar_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests des filtres echoues : transmettre le journal.' }
        $regressions = @(
            'test/academy_learning_redesign_test.dart',
            'test/academy_home_redesign_test.dart',
            'test/academy_operational_test.dart',
            'test/alumni_gamification_academy_impact_test.dart',
            'test/alumni_day_native_test.dart',
            'test/alumni_day_demo_test.dart',
            'test/archive_minutes_test.dart',
            'test/archives_responsive_test.dart',
            'test/archives_hall_of_fame_test.dart',
            'test/communication_test.dart',
            'test/dashboard_tasks_test.dart',
            'test/events_documents_test.dart',
            'test/documents_offline_test.dart',
            'test/first_access_test.dart',
            'test/help_operational_test.dart',
            'test/poles_portfolio_test.dart',
            'test/projects_portfolio_test.dart',
            'test/recruitment_internal_test.dart',
            'test/veille_operational_test.dart',
            'test/ui_final_acceptance_test.dart',
            'test/member_join_requests_test.dart',
            'test/member_alphabetical_order_test.dart',
            'test/profile_preview_navigation_test.dart'
        )
        & flutter test --no-pub --reporter expanded @regressions
        if ($LASTEXITCODE -ne 0) { throw 'Tests des modules echoues : transmettre le journal.' }
    } finally { Pop-Location }
    $pictures = @(Get-ChildItem -LiteralPath $previews -Filter '*.png' -File | Sort-Object Name)
    if ($pictures.Count -ne 18) { throw 'Captures incompletes : transmettre le journal.' }
    $cards = ($pictures | ForEach-Object {
        $name = [Net.WebUtility]::HtmlEncode($_.Name)
        "<figure><figcaption>$name</figcaption><a href='$name' target='_blank'><img src='$name' alt='$name' loading='lazy'></a></figure>"
    }) -join "`n"
    $html = @"
<!doctype html>
<html lang='fr'><meta charset='utf-8'><meta name='viewport' content='width=device-width, initial-scale=1'>
<title>EnactSpace - recherche et filtres</title>
<style>body{margin:24px auto;max-width:1480px;padding:0 20px;background:#f6f4ee;color:#101920;font:16px system-ui}h1{font-size:28px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0;padding:14px;background:#fff;border:1px solid #dde4e2;border-radius:16px}figcaption{margin-bottom:10px;font-weight:700}img{display:block;width:100%;height:auto;border-radius:8px}a{color:inherit}p{line-height:1.6}</style>
<h1>Recherche et filtres compacts</h1><p>Disposition fermee et ouverte, mobile et ordinateur, clair et sombre. Les deux captures Academy utilisent le catalogue reel avec des donnees fictives de test. Clique sur une capture pour la voir en grand.</p>
<main>$cards</main></html>
"@
    $gallery = Join-Path $previews 'filters-preview.html'
    [IO.File]::WriteAllText($gallery, $html, [Text.UTF8Encoding]::new($false))
    $archive = Join-Path $backup 'filtres-captures.zip'
    Compress-Archive -LiteralPath $pictures.FullName -DestinationPath $archive
    'FILTRES_COMPACTS_ANALYSE_ET_TESTS_OK'
    "CAPTURES_FILTRES=$gallery"
    "ARCHIVE_CAPTURES_A_PARTAGER=$archive"
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    if (!$NoPreview) { Start-Process $gallery }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
