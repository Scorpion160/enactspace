[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [string]$Repository = (Join-Path $env:USERPROFILE 'Documents\EnactSpaceRecovery\enactspace-20260927'),
    [string]$PreviousValidation = (Join-Path $env:LOCALAPPDATA 'EnactSpace\InterfaceCopyReview\b39a52771da8498a98aca4b94efa1aca'),
    [string]$DefinesPath = (Join-Path $env:LOCALAPPDATA 'EnactSpace\WebRelease\22bedeed75934001adf66de4c3f8c6f3\web-client-defines.json'),
    [ValidatePattern('^[a-f0-9]{32}$')] [string]$Resume,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$sourceCommit = '0b3671e282cedb5efdf9497129119ab2d139e29c'
$previousSource = 'de640506fe8d07bd93f19528ebf0a6d8a488ebcb'
$previousManifest = 'b0237a194a437cc52ca282d82c135bfd0d82d6235fbf31dd850f33bd21640516'
$previousMain = '18847f88b8026e344f47ab93e8f776b8caa95e8ed5fb1ae1277256a80485d875'
$backendManifest = 'e6c76cc1ab4f2ce41b81a58427215985d0e8e078c5ebd41a9b96603bc2a61452'
$webVersion = '1.0.25'
$webBuild = '28'
$site = 'https://enactspace.kerunjombor.net'
$api = 'https://api-enactspace.kerunjombor.net'
$webPatch = @(
    @{ path = 'frontend/lib/app/app_router.dart'; before = '84152e2f3555f4f60f9b7e4bd09f7e06d636fea42abc91cba0f1884d46ba4552'; after = '55db7028cfbaddbc75aab6d4353f68e4cb56e7ca990f4558d9988210d168f7db' },
    @{ path = 'frontend/lib/features/auth/screens/login_screen.dart'; before = '9640ae50902099d8ae6cc01054868821233bc22c7b19b4b9c01b5fa274bef96c'; after = 'eae97a10027f44b5b0e3897a6c1d1f49d5dbe2867e0b1e335163e81f89df2cba' },
    @{ path = 'frontend/test/ui_final_acceptance_test.dart'; before = 'b365ff3a5f82344bec15bf9e7373fdee1e478f0effd7b56117782104c774a024'; after = '8ca3d150d8ade844e0aa597ee8b0856fced4b0d8d50b68c5cf23a43be62a0054' }
)
$buildTools = [ordered]@{
    'tools/build_web_with_firebase.ps1' = '8fb0982bb33b282a6ea3ec1a2f4a4718dc66cfdddc2694085e641994032abb5c'
    'tools/generate_firebase_web_worker.py' = 'a4f642c1badecb2dff52db99982295b012110b65b95b44adfc854b7a7d43c611'
    'tools/templates/firebase-messaging-sw.template.js' = '31bdc13249e3d82eb1a67994c6fe719ba6df1df0c72a93cc61a9a97206d21b59'
}
$backendTools = [ordered]@{
    'rehearse_interface_copy_backend.py' = '8afc45a0394bf5c6dfb55e6db3715eff14f691022fd07f47109730ae48526ddf'
    'publish_interface_copy_backend.py' = 'e3a14581eab9b9141fb31c305d9c5b9301c39da0cd6097ef9e615f438460e185'
    'test_publish_interface_copy_backend.py' = 'b0ad50876f012a0f57a82d38e52b2ca9c77626f9cc8eefef88282511cc5d64cb'
    'publish_recruitment_campaign_backend.py' = '2ad80ede7b3c51eb4b349f0d35c6b595f28fc2fa58e2c3fed59a25495efb5a15'
}
$webTools = [ordered]@{
    'publish_web_release.py' = '5406bcf9a096f623308e180e6d52743fa8bb6bb9486577cb7edcbbfb5d6bd794'
    'test_publish_web_release.py' = 'c5475bf0cb719d588baf586897ef49c5e5bbcde0a2f70b217e94371ac9f59af8'
}
$transport = @('-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
$id = if ($Resume) { $Resume } else { [guid]::NewGuid().ToString('N') }
$attempt = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\MailRelease\$id"
$snapshot = Join-Path $local 'candidate'
$work = Join-Path $local 'tools'
$payload = Join-Path $local 'payload'
$ready = Join-Path $local 'ready.json'
$archive = Join-Path $local 'web-release.tar.gz'
$remoteRehearsal = "/opt/enactspace/staging/interface-copy-backend-$id"
$remoteBackend = "/opt/enactspace/operations/publish-interface-copy-$attempt"
$remoteWeb = "/opt/enactspace/staging/web-publication-$attempt"
$unit = "enactspace-mail-release-$attempt"

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-DartHash([string]$Path) {
    $encoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $lines = @(& dart format --output=show --summary=none --show=none --language-version=latest --page-width=80 --trailing-commas=automate $Path)
        if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) { throw "Lecture Dart impossible : $Path" }
        Get-TextHash (($lines -join "`n") + "`n")
    }
    finally { [Console]::OutputEncoding = $encoding }
}

function Get-PinnedFile([string]$Ref, [string]$Path, [string]$Target, [string]$Hash) {
    New-Item -ItemType Directory -Path (Split-Path $Target -Parent) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Ref/$Path" -OutFile $Target -UseBasicParsing
    if ((Get-Hash $Target) -cne $Hash) { throw "Integrite incorrecte : $Path" }
}

function Assert-Source([string]$Relative, [string]$Expected) {
    $path = Join-Path $snapshot $Relative
    $normalized = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    if ((Get-TextHash $normalized) -ceq $Expected) { return }
    if ($Relative.EndsWith('.dart')) {
        $reference = Join-Path $local ('baseline/' + $Relative)
        if (!(Test-Path -LiteralPath $reference -PathType Leaf) -or (Get-Hash $reference) -cne $Expected) {
            Get-PinnedFile $previousSource $Relative $reference $Expected
        }
        if ((Get-DartHash $Path) -ceq (Get-DartHash $reference)) { return }
    }
    throw "Source locale differente de la reference : $Relative"
}

function Read-Json([string]$Path) {
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Invoke-Vps([string]$Command) {
    $lines = @(& ssh.exe -T @transport vps $Command)
    if ($LASTEXITCODE -ne 0) {
        $lines | Out-Host
        throw 'Commande VPS interrompue. Consulter le journal de cette operation.'
    }
    $lines
}

function Send-Checked([string]$Path, [string]$Destination, [string]$Expected) {
    if ((Get-Hash $Path) -cne $Expected) { throw "Fichier local modifie : $Path" }
    & scp.exe @transport $Path "vps:$Destination" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Transfert VPS echoue.' }
    $result = @(Invoke-Vps "sha256sum $Destination")
    if ($result.Count -ne 1 -or ($result[0] -split '\s+')[0] -cne $Expected) {
        throw "Integrite VPS incorrecte : $Destination"
    }
}

function Get-WebVersion {
    Invoke-RestMethod "$site/version.json?check=$attempt-$([guid]::NewGuid().ToString('N'))" -UseBasicParsing
}

function Assert-PublicMain([string]$Expected) {
    $bundle = Join-Path $local 'main.public.dart.js'
    Invoke-WebRequest "$site/main.dart.js?check=$([guid]::NewGuid().ToString('N'))" -OutFile $bundle -UseBasicParsing
    if ((Get-Hash $bundle) -cne $Expected) { throw 'Empreinte du JavaScript public inattendue.' }
}

function Test-WebVersion($Public, [string]$Version, [string]$Build) {
    $Public.version -ceq $Version -and [string]$Public.build_number -ceq $Build
}

function Get-ApiHealth {
    $health = Invoke-RestMethod "$api/health?check=$([guid]::NewGuid().ToString('N'))" -UseBasicParsing
    if ($health.ok -ne $true -or $health.environment -cne 'production') { throw 'Etat HTTPS du backend inattendu.' }
    $health
}

function Build-ValidatedWeb {
    $previous = Read-Json (Join-Path $PreviousValidation 'validation.json')
    $oldManifestPath = Join-Path $PreviousValidation 'staging/manifest.json'
    if ($previous.source_commit -cne $previousSource -or $previous.status -cne 'LOCAL_VALIDATION_PASSED' -or
        $previous.dart_analysis_passed -ne $true -or $previous.flutter_tests_passed -ne $true -or
        (Get-Hash $oldManifestPath) -cne $previousManifest) {
        throw 'Validation precedente introuvable ou incoherente.'
    }
    if (!(Test-Path -LiteralPath $DefinesPath -PathType Leaf)) { throw 'Configuration du build web introuvable.' }
    $flutterVersion = (& flutter --version --machine | Out-String) | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $flutterVersion.frameworkVersion -cne '3.47.5') { throw 'Flutter 3.47.5 requis.' }

    $frontend = Join-Path $snapshot 'frontend'
    New-Item -ItemType Directory -Path $frontend -Force | Out-Null
    foreach ($directory in @('lib', 'assets', 'web', 'test', 'tool')) {
        & robocopy.exe (Join-Path $Repository "frontend/$directory") (Join-Path $frontend $directory) /E /XJ /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Host
        if ($LASTEXITCODE -ge 8) { throw "Copie du projet interrompue : $directory" }
    }
    foreach ($name in @('analysis_options.yaml', 'pubspec.yaml', 'pubspec.lock', '.metadata')) {
        Copy-Item -LiteralPath (Join-Path $Repository "frontend/$name") -Destination $frontend
    }
    $fixtures = 'backend/app/services'
    New-Item -ItemType Directory -Path (Join-Path $snapshot $fixtures) -Force | Out-Null
    foreach ($name in @('recruitment_rubric.json', 'recruitment_questionnaire.py', 'project_presentations.json')) {
        Copy-Item -LiteralPath (Join-Path $Repository "$fixtures/$name") -Destination (Join-Path $snapshot $fixtures)
    }

    $old = Read-Json $oldManifestPath
    foreach ($entry in @($old.files) + @($old.requirements)) {
        if ($entry.path -like 'frontend/*' -or
            $entry.path -in @("$fixtures/recruitment_rubric.json", "$fixtures/recruitment_questionnaire.py")) {
            Assert-Source $entry.path $entry.sha256
        }
    }
    foreach ($entry in $webPatch) {
        Assert-Source $entry.path $entry.before
        Get-PinnedFile $sourceCommit $entry.path (Join-Path $snapshot ('patch/' + $entry.path)) $entry.after
        $destination = Join-Path $snapshot $entry.path
        Copy-Item -LiteralPath (Join-Path $snapshot ('patch/' + $entry.path)) -Destination $destination -Force
    }
    foreach ($path in $buildTools.Keys) {
        Get-PinnedFile $Commit $path (Join-Path $snapshot $path) $buildTools[$path]
    }

    Push-Location $frontend
    try {
        $dartPaths = @($webPatch | ForEach-Object { $_.path.Substring('frontend/'.Length) })
        & dart format @dartPaths | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Formatage Dart echoue.' }
        & flutter pub get --offline --enforce-lockfile | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Dependances Flutter indisponibles ou differentes.' }
        if ((Get-TextHash ([IO.File]::ReadAllText((Join-Path $frontend 'pubspec.lock')).Replace("`r`n", "`n"))) -cne
            ($old.requirements | Where-Object { $_.path -eq 'frontend/pubspec.lock' }).sha256) {
            throw 'Le verrou Flutter a change.'
        }
        Write-Host 'VALIDATION_FLUTTER_EN_COURS'
        & flutter analyze --no-pub | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Analyse Flutter echouee.' }
        & flutter test --no-pub --reporter expanded | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Tests Flutter echoues.' }
    }
    finally { Pop-Location }

    $web = Join-Path $local 'web'
    Write-Host 'COMPILATION_WEB_1.0.25_28_EN_COURS'
    & (Join-Path $snapshot 'tools/build_web_with_firebase.ps1') -DefinesPath $DefinesPath -FlutterArgs @(
        '--no-pub', "--output=$web", "--build-name=$webVersion", "--build-number=$webBuild"
    ) | Out-Host
    if (!(Test-WebVersion (Read-Json (Join-Path $web 'version.json')) $webVersion $webBuild)) { throw 'Version du build incorrecte.' }
    foreach ($name in @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'firebase-messaging-sw.js')) {
        if (!(Test-Path -LiteralPath (Join-Path $web $name) -PathType Leaf)) { throw "Build web incomplet : $name" }
    }
    $mainHash = Get-Hash (Join-Path $web 'main.dart.js')
    & tar.exe -czf $archive -C $web . | Out-Host
    if ($LASTEXITCODE -ne 0 -or (Get-Hash (Join-Path $web 'main.dart.js')) -cne $mainHash) { throw 'Archive du build incoherente.' }
    @{ main_sha256 = $mainHash; archive_sha256 = (Get-Hash $archive) }
}

function Test-Rehearsal($Result, $Manifest) {
    if ($Result.status -cne 'INTERFACE_COPY_BACKEND_CANDIDATE_VERIFIED' -or
        $Result.operation_id -cne $id -or $Result.deployment_performed -ne $false -or
        $Result.base_image_id -cne $Manifest.base_image_id -or $Result.source_commit -cne $sourceCommit -or
        $Result.candidate_image_id -cnotmatch '^sha256:[a-f0-9]{64}$' -or
        $Result.candidate_schema_head -cne $Manifest.schema_head -or
        $Result.tests_run -ne $Manifest.tests_expected -or $Result.failures -ne 0 -or
        $Result.errors -ne 0 -or $Result.skipped -ne 0) {
        throw 'Le recu de recette serveur est incomplet.'
    }
}

function Invoke-BackendRehearsal($Manifest) {
    foreach ($entry in @($Manifest.runtime.PSObject.Properties) + @($Manifest.tests.PSObject.Properties)) {
        Get-PinnedFile $sourceCommit $entry.Name (Join-Path $payload $entry.Name) ([string]$entry.Value)
    }
    Invoke-Vps "install -d -m 700 $remoteRehearsal" | Out-Host
    Send-Checked (Join-Path $work 'manifest.json') "$remoteRehearsal/manifest.json" $backendManifest
    $runner = 'rehearse_interface_copy_backend.py'
    Send-Checked (Join-Path $work $runner) "$remoteRehearsal/$runner" $backendTools[$runner]
    & scp.exe @transport -r $payload "vps:$remoteRehearsal/" | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Transfert du perimetre serveur interrompu.' }
    Invoke-Vps "python3 $remoteRehearsal/$runner --directory $remoteRehearsal --manifest-sha256 $backendManifest" | Out-Host
    $result = (Invoke-Vps "cat $remoteRehearsal/rehearsal.json" | Out-String) | ConvertFrom-Json
    Test-Rehearsal $result $Manifest
    $result
}

New-Item -ItemType Directory -Path $work -Force | Out-Null
Start-Transcript -Path (Join-Path $local "release-$attempt.log") | Out-Null
try {
    "OPERATION_MAIL=$id"
    Get-PinnedFile $Commit 'tools/email_release_backend_manifest.json' (Join-Path $work 'manifest.json') $backendManifest
    $manifest = Read-Json (Join-Path $work 'manifest.json')
    foreach ($name in @($backendTools.Keys) + @($webTools.Keys)) {
        $hash = if ($backendTools.Contains($name)) { $backendTools[$name] } else { $webTools[$name] }
        Get-PinnedFile $Commit "tools/$name" (Join-Path $work $name) $hash
    }
    $currentWeb = Get-WebVersion
    $currentApi = Get-ApiHealth
    if (!$Resume) {
        if (!(Test-WebVersion $currentWeb '1.0.24' '27') -or $currentApi.version -cne $manifest.base_version) {
            throw 'Les versions en production ont change. Comparer les recus avant de continuer.'
        }
        Assert-PublicMain $previousMain
        $build = Build-ValidatedWeb
        $candidate = Invoke-BackendRehearsal $manifest
        $report = [ordered]@{
            source_commit = $sourceCommit; operation_id = $id; web_version = $webVersion; web_build = $webBuild
            main_sha256 = $build.main_sha256; archive_sha256 = $build.archive_sha256; backend = $candidate
        }
        [IO.File]::WriteAllText($ready, ($report | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    }
    $report = Read-Json $ready
    if ($report.source_commit -cne $sourceCommit -or $report.operation_id -cne $id -or
        $report.web_version -cne $webVersion -or [string]$report.web_build -cne $webBuild -or
        $report.main_sha256 -cnotmatch '^[a-f0-9]{64}$' -or $report.archive_sha256 -cnotmatch '^[a-f0-9]{64}$' -or
        (Get-Hash $archive) -cne $report.archive_sha256) { throw 'Recu et archive de preparation incoherents.' }
    Test-Rehearsal $report.backend $manifest
    if (!$Publish) {
        'BUILD_WEB_ET_RECETTE_SERVEUR_VALIDES'
        $report | ConvertTo-Json -Depth 6
        return
    }

    $image = $report.backend.candidate_image_id
    $publishBackend = "python3 $remoteBackend/publish_interface_copy_backend.py --directory $remoteBackend " +
        "--manifest-sha256 $backendManifest --candidate $id $image"
    Invoke-Vps "install -d -m 700 $remoteBackend" | Out-Host
    Send-Checked (Join-Path $work 'manifest.json') "$remoteBackend/manifest.json" $backendManifest
    foreach ($name in $backendTools.Keys | Where-Object { $_ -ne 'rehearse_interface_copy_backend.py' }) {
        Send-Checked (Join-Path $work $name) "$remoteBackend/$name" $backendTools[$name]
    }
    Invoke-Vps "python3 -m unittest discover -s $remoteBackend -p test_publish_interface_copy_backend.py -v" | Out-Host
    Invoke-Vps $publishBackend | Out-Host

    $currentWeb = Get-WebVersion
    if (!(Test-WebVersion $currentWeb $webVersion $webBuild)) {
        if (!(Test-WebVersion $currentWeb '1.0.24' '27')) { throw 'Version web publique inattendue avant bascule.' }
        Assert-PublicMain $previousMain
        Invoke-Vps "install -d -m 700 $remoteWeb" | Out-Host
        Send-Checked $archive "$remoteWeb/web-release.tar.gz" $report.archive_sha256
        foreach ($name in $webTools.Keys) {
            Send-Checked (Join-Path $work $name) "$remoteWeb/$name" $webTools[$name]
        }
        Invoke-Vps "python3 -m unittest discover -s $remoteWeb -p test_publish_web_release.py -v" | Out-Host
        $webCommand = "python3 $remoteWeb/publish_web_release.py --archive $remoteWeb/web-release.tar.gz " +
            "--archive-sha256 $($report.archive_sha256) --release $webVersion $webBuild $($report.main_sha256) " +
            "--expected-live 1.0.24 27 $previousMain --execute"
        $webOutput = Invoke-Vps $webCommand | Out-String
        $webOutput | Out-Host
        $webResult = $webOutput | ConvertFrom-Json
        if ($webResult.status -cne 'WEB_DEPLOYED_LOCAL_CHECKS_PASSED' -or $webResult.web_deployed -ne $true -or
            $webResult.main_sha256 -cne $report.main_sha256) { throw 'Publication web non confirmee par le VPS.' }
    }
    if (!(Test-WebVersion (Get-WebVersion) $webVersion $webBuild)) { throw 'Version web HTTPS inattendue.' }
    Assert-PublicMain $report.main_sha256
    'WEB_1.0.25_28_HTTPS_ET_EMPREINTE_OK'

    "UNITE_BACKEND=$unit"
    Invoke-Vps ("systemd-run --unit=$unit --collect --service-type=exec --property=RuntimeMaxSec=25min " +
        "--property=TimeoutStopSec=3min /usr/bin/$publishBackend --execute") | Out-Host
    $deadline = [DateTime]::UtcNow.AddMinutes(29)
    $result = $null
    while ([DateTime]::UtcNow -lt $deadline) {
        $lines = @(& ssh.exe -T @transport vps "if test -f $remoteBackend/deployment.json; then cat $remoteBackend/deployment.json; fi")
        if ($LASTEXITCODE -eq 0 -and $lines.Count -gt 0) {
            $result = ($lines -join "`n") | ConvertFrom-Json
            break
        }
        if (([int]($deadline - [DateTime]::UtcNow).TotalSeconds) % 30 -lt 6) { Write-Host "DEPLOIEMENT_BACKEND_EN_COURS=$unit" }
        Start-Sleep -Seconds 5
    }
    $result | ConvertTo-Json -Depth 8
    if ($null -eq $result -or $result.status -cnotin @('INTERFACE_COPY_BACKEND_DEPLOYED', 'INTERFACE_COPY_BACKEND_ALREADY_DEPLOYED') -or
        $result.image_id -cne $image -or $result.version -cne $manifest.target_version -or
        $result.schema -cne $manifest.schema_head -or $result.migration_performed -ne $false) {
        throw "Bascule backend non confirmee. Recu attendu : $remoteBackend/deployment.json"
    }
    $timeline = Invoke-RestMethod "$api/api/recruitment/campaigns/timeline?check=$attempt" -UseBasicParsing
    if ((Get-ApiHealth).version -cne $manifest.target_version -or $timeline.timezone -cne 'Africa/Dakar' -or
        !(Test-WebVersion (Get-WebVersion) $webVersion $webBuild)) { throw 'Reponses HTTPS finales inattendues.' }
    'BACKEND_1.0.23_SCHEMA_0033_HTTPS_OK'
    $campaigns = @($timeline.campaigns | Where-Object { $_.title -match 'Recrutement Enactus ESP.*2026' })
    if ($campaigns.Count -eq 0) { 'CAMPAGNE_2026_ABSENTE_DU_CALENDRIER_PUBLIC' }
    foreach ($campaign in $campaigns) {
        "DATES_INSCRIPTIONS_PUBLIQUES=$($campaign.start_date),$($campaign.end_date)"
        "ANNONCE_DU_23_NOVEMBRE_VISIBLE=$([bool]($campaign.description -match '\b23\s+novembre\b'))"
    }
    'PUBLICATION_MAIL_WEB_ET_BACKEND_VERIFIEE'
}
finally {
    "DOSSIER_OPERATION=$local"
    Stop-Transcript | Out-Null
}
