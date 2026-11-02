[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$Commit,
    [string]$BuildDirectory = (Join-Path $env:LOCALAPPDATA 'EnactSpace\WebInterfaceBuilds\aa0f9b4affa14551bd69b5ce0d7fd873'),
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$sourceCommit = 'de640506fe8d07bd93f19528ebf0a6d8a488ebcb'
$releaseVersion = '1.0.24'
$releaseBuild = '27'
$expectedMain = '18847f88b8026e344f47ab93e8f776b8caa95e8ed5fb1ae1277256a80485d875'
$expectedArchive = '87ca43801e44dccb336ae3e873862ab92f76af1cd273ea93817561b8cdadbd73'
$baselineVersion = '1.0.23'
$baselineBuild = '26'
$baselineMain = '2ae134b2f47a5bb05b3856d80d841d96fbf471112d3a383609078137d030daad'
$publisherHashes = [ordered]@{
    'publish_web_release.py' = '5406bcf9a096f623308e180e6d52743fa8bb6bb9486577cb7edcbbfb5d6bd794'
    'test_publish_web_release.py' = 'c5475bf0cb719d588baf586897ef49c5e5bbcde0a2f70b217e94371ac9f59af8'
}

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-WebVersion($Data, [string]$Version, [string]$Build) {
    $Data.version -eq $Version -and [string]$Data.build_number -eq $Build
}

$id = [guid]::NewGuid().ToString('N')
$operation = Join-Path $env:LOCALAPPDATA "EnactSpace\WebPublications\$id"
New-Item -ItemType Directory -Path $operation | Out-Null
$receipt = [ordered]@{
    status = 'PUBLICATION_BLOCKED'; validated_sync_commit = $sourceCommit
    version = $releaseVersion; build_number = [int]$releaseBuild
    main_sha256 = $expectedMain; archive_sha256 = $expectedArchive
    deployment_attempted = $false; deployment_performed = $false; public_https_verified = $false
}
Start-Transcript -Path (Join-Path $operation 'publication.log') | Out-Null
try {
    $build = Get-Content -LiteralPath (Join-Path $BuildDirectory 'build.json') -Raw | ConvertFrom-Json
    if ($build.status -ne 'WEB_BUILD_1.0.24_27_READY' -or $build.validated_sync_commit -ne $sourceCommit -or
        !(Test-WebVersion $build $releaseVersion $releaseBuild) -or
        $build.main_sha256 -ne $expectedMain -or $build.archive_sha256 -ne $expectedArchive) {
        throw 'Le recu ne correspond pas a la compilation validee.'
    }
    $archive = Join-Path $BuildDirectory 'web-release.tar.gz'
    if ((Get-Hash $archive) -ne $expectedArchive) { throw 'Empreinte de l archive web incorrecte.' }

    if (!$Publish) {
        $receipt['status'] = 'WEB_ARCHIVE_1.0.24_27_VERIFIED'
        'WEB_ARCHIVE_1.0.24_27_VERIFIED'
        return
    }

    $site = 'https://enactspace.kerunjombor.net'
    $apiHealth = 'https://api-enactspace.kerunjombor.net/health'
    $public = Invoke-RestMethod "$site/version.json?release=$id" -UseBasicParsing
    $publicMain = Join-Path $operation 'main.public.dart.js'
    if (Test-WebVersion $public $releaseVersion $releaseBuild) {
        Invoke-WebRequest "$site/main.dart.js?release=$id" -OutFile $publicMain -UseBasicParsing
        if ((Get-Hash $publicMain) -ne $expectedMain) { throw 'La version cible est publique avec un JavaScript different.' }
        Invoke-WebRequest "${apiHealth}?release=$id" -UseBasicParsing | Out-Null
        $receipt['status'] = 'ALREADY_PUBLISHED_HTTPS_VERIFIED'
        $receipt['public_https_verified'] = $true
        'WEB_PUBLIC_1.0.24_27_DEJA_VERIFIE'
        return
    }
    if (!(Test-WebVersion $public $baselineVersion $baselineBuild)) { throw 'La version publique a change.' }
    Invoke-WebRequest "${apiHealth}?release=$id" -UseBasicParsing | Out-Null

    $uploads = [ordered]@{ 'web-release.tar.gz' = @{ path = $archive; hash = $expectedArchive } }
    foreach ($name in $publisherHashes.Keys) {
        $path = Join-Path $operation $name
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/tools/$name" -OutFile $path -UseBasicParsing
        if ((Get-Hash $path) -ne $publisherHashes[$name]) { throw "Integrite incorrecte : $name" }
        $uploads[$name] = @{ path = $path; hash = $publisherHashes[$name] }
    }

    $remote = "/opt/enactspace/staging/web-publication-$id"
    $transport = @('-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
    & ssh -T @transport vps "install -d -m 700 $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Preparation du dossier VPS echouee.' }
    foreach ($name in $uploads.Keys) {
        & scp @transport $uploads[$name].path "vps:$remote/"
        if ($LASTEXITCODE -ne 0) { throw "Transfert echoue : $name" }
    }
    $remotePaths = ($uploads.Keys | ForEach-Object { "$remote/$_" }) -join ' '
    $remoteHashes = @(& ssh -T @transport vps "sha256sum $remotePaths")
    if ($LASTEXITCODE -ne 0) { throw 'Verification des fichiers transferes echouee.' }
    foreach ($name in $uploads.Keys) {
        $pattern = '^' + $uploads[$name].hash + '\s+' + [regex]::Escape("$remote/$name") + '$'
        if (@($remoteHashes | Where-Object { ([string]$_).Trim() -cmatch $pattern }).Count -ne 1) {
            throw "Integrite VPS incorrecte : $name"
        }
    }
    & ssh -T @transport vps "python3 -m unittest discover -s $remote -p test_publish_web_release.py -v"
    if ($LASTEXITCODE -ne 0) { throw 'Tests du programme de publication echoues.' }

    $current = Invoke-RestMethod "$site/version.json?release=$id-before-switch" -UseBasicParsing
    if (!(Test-WebVersion $current $baselineVersion $baselineBuild)) { throw 'La version publique a change pendant la preparation.' }
    $command = "python3 $remote/publish_web_release.py --archive $remote/web-release.tar.gz --archive-sha256 $expectedArchive " +
        "--release $releaseVersion $releaseBuild $expectedMain --expected-live $baselineVersion $baselineBuild $baselineMain --execute"
    $receipt['deployment_attempted'] = $true
    $lines = @(& ssh -T @transport vps $command)
    $exitCode = $LASTEXITCODE
    $lines | Write-Output
    if ($exitCode -ne 0) { throw 'Publication interrompue : transmettre ce journal.' }
    $deployed = ($lines -join "`n") | ConvertFrom-Json
    if ($deployed.status -ne 'WEB_DEPLOYED_LOCAL_CHECKS_PASSED' -or $deployed.web_deployed -ne $true -or
        !(Test-WebVersion $deployed.version $releaseVersion $releaseBuild) -or $deployed.main_sha256 -ne $expectedMain) {
        throw 'Resultat VPS inattendu : transmettre ce journal.'
    }
    $receipt['deployment_performed'] = $true
    $receipt['rollback_directory'] = $deployed.rollback_directory
    $published = Invoke-RestMethod "$site/version.json?release=$id-after-switch" -UseBasicParsing
    if (!(Test-WebVersion $published $releaseVersion $releaseBuild)) { throw 'Version publique incorrecte.' }
    Invoke-WebRequest "$site/main.dart.js?release=$id-after-switch" -OutFile $publicMain -UseBasicParsing
    if ((Get-Hash $publicMain) -ne $expectedMain) { throw 'Empreinte publique incorrecte : transmettre le journal.' }
    Invoke-WebRequest "${apiHealth}?release=$id-after-switch" -UseBasicParsing | Out-Null
    $receipt['status'] = 'WEB_PUBLISHED_HTTPS_VERIFIED'
    $receipt['public_https_verified'] = $true
    'WEB_PUBLIC_1.0.24_27_HTTPS_ET_EMPREINTE_OK'
    "RETOUR_ARRIERE_WEB=$($deployed.rollback_directory)"
}
finally {
    [IO.File]::WriteAllText((Join-Path $operation 'publication.json'), ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    "DOSSIER_PUBLICATION=$operation"
    Stop-Transcript | Out-Null
}
