[CmdletBinding()]
param(
    [string]$Frontend = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927\frontend',
    [switch]$Publish
)
$ErrorActionPreference = 'Stop'
$releaseVersion = '1.0.23'
$releaseBuild = 26
$expectedMain = '2ae134b2f47a5bb05b3856d80d841d96fbf471112d3a383609078137d030daad'
$publisherCommit = '2956b9c5d5b08d399fe761812a4e542cd5eef0fc'
$publisherHashes = [ordered]@{
    'publish_web_release.py' = '99cd25ba3e4bf2367e96ebb579b1de50b588e8742681e6899074f09dc0f8ac9f'
    'test_publish_web_release.py' = '1a6ed7aaa0f065b11ad6bd1569b52bfd84a0069acda8481a9961cbb762b4cec4'
}

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-PrebuiltWeb([string]$Directory, [string]$Version, [int]$BuildNumber, [string]$MainHash) {
    foreach ($name in @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'firebase-messaging-sw.js', 'version.json')) {
        if (!(Test-Path -LiteralPath (Join-Path $Directory $name) -PathType Leaf)) { throw "Build incomplet : $name" }
    }
    $versionData = Get-Content -LiteralPath (Join-Path $Directory 'version.json') -Raw | ConvertFrom-Json
    if ($versionData.version -ne $Version -or [string]$versionData.build_number -ne [string]$BuildNumber) {
        throw 'Le build present ne correspond pas a la version validee.'
    }
    if ((Get-Hash (Join-Path $Directory 'main.dart.js')) -ne $MainHash) {
        throw 'Le JavaScript a change depuis le build valide : publication interrompue.'
    }
}

function Get-BundleFingerprint([string]$Directory) {
    $root = [IO.Path]::GetFullPath($Directory).TrimEnd([char[]]@('\', '/'))
    $entries = @(Get-ChildItem -LiteralPath $root -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($root.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
            sha256 = Get-Hash $_.FullName
        }
    })
    ConvertTo-Json -InputObject $entries -Compress -Depth 4
}

function Get-VerifiedPublisher([string]$Name, [string]$Directory) {
    $path = Join-Path $Directory $Name
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$publisherCommit/tools/$Name" -OutFile $path -UseBasicParsing
    if ((Get-Hash $path) -ne $publisherHashes[$Name]) { throw "Integrite incorrecte : $Name" }
}

$id = [guid]::NewGuid().ToString('N')
$operation = Join-Path $env:LOCALAPPDATA "EnactSpace\WebPublications\$id"
New-Item -ItemType Directory -Path $operation -Force | Out-Null
$receipt = [ordered]@{
    version = $releaseVersion; build_number = $releaseBuild; main_sha256 = $expectedMain
    build_reused = $true; flutter_invoked = $false
    deployment_attempted = $false; deployment_performed = $false; public_https_verified = $false
}
Start-Transcript -Path (Join-Path $operation 'publication.log') | Out-Null
try {
    $web = (Resolve-Path -LiteralPath (Join-Path $Frontend 'build\web')).Path
    Assert-PrebuiltWeb $web $releaseVersion $releaseBuild $expectedMain
    'BUILD_EXISTANT_1.0.23_26_VERIFIE'
    $before = Get-BundleFingerprint $web
    foreach ($name in $publisherHashes.Keys) { Get-VerifiedPublisher $name $operation }
    $archive = Join-Path $operation 'web-release.tar.gz'
    & tar.exe -czf $archive -C $web .
    if ($LASTEXITCODE -ne 0) { throw 'Creation de l archive echouee.' }
    if ((Get-BundleFingerprint $web) -cne $before) { throw 'Des fichiers du build ont change pendant la preparation.' }
    Assert-PrebuiltWeb $web $releaseVersion $releaseBuild $expectedMain
    $archiveHash = Get-Hash $archive
    $receipt['archive_sha256'] = $archiveHash
    if (!$Publish) {
        $receipt['status'] = 'PREBUILT_WEB_PACKAGE_READY'
        "ARCHIVE_WEB=$archive"
        'PUBLICATION_NON_DEMANDEE'
        return
    }
    $site = 'https://enactspace.kerunjombor.net'
    $public = Invoke-RestMethod "$site/version.json?release=$id"
    $publicMain = Join-Path $operation 'main.public.dart.js'
    if ($public.version -eq $releaseVersion -and [string]$public.build_number -eq [string]$releaseBuild) {
        Invoke-WebRequest "$site/main.dart.js?release=$id" -OutFile $publicMain -UseBasicParsing
        if ((Get-Hash $publicMain) -ne $expectedMain) { throw 'La meme version est publique avec un JavaScript different.' }
        $receipt['status'] = 'ALREADY_PUBLISHED_HTTPS_VERIFIED'
        $receipt['public_https_verified'] = $true
        'WEB_PUBLIC_1.0.23_26_DEJA_VERIFIE'
        return
    }
    if ($public.version -ne '1.0.22' -or [string]$public.build_number -ne '25') {
        throw 'La version publique a change : transmettre le journal avant toute publication.'
    }
    Invoke-WebRequest "https://api-enactspace.kerunjombor.net/health?release=$id" -UseBasicParsing | Out-Null
    $remote = "/opt/enactspace/staging/web-publication-$id"
    $transport = @('-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
    & ssh -T @transport vps "install -d -m 700 $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Preparation du dossier VPS echouee.' }
    $uploads = @('web-release.tar.gz', 'publish_web_release.py', 'test_publish_web_release.py')
    foreach ($name in $uploads) {
        & scp @transport (Join-Path $operation $name) "vps:$remote/"
        if ($LASTEXITCODE -ne 0) { throw "Transfert echoue : $name" }
    }
    $remoteHashes = @(& ssh -T @transport vps "sha256sum $remote/web-release.tar.gz $remote/publish_web_release.py $remote/test_publish_web_release.py")
    if ($LASTEXITCODE -ne 0) { throw 'Verification des fichiers transferes echouee.' }
    foreach ($name in $uploads) {
        $pattern = '^([a-f0-9]{64})\s+' + [regex]::Escape("$remote/$name") + '$'
        $matching = @($remoteHashes | Where-Object { ([string]$_).Trim() -match $pattern })
        if ($matching.Count -ne 1 -or (([string]$matching[0] -split '\s+')[0]) -ne (Get-Hash (Join-Path $operation $name))) {
            throw "Integrite VPS incorrecte : $name"
        }
    }
    & ssh -T @transport vps "python3 -m unittest discover -s $remote -p test_publish_web_release.py -v"
    if ($LASTEXITCODE -ne 0) { throw 'Tests du programme de publication echoues.' }
    $current = Invoke-RestMethod "$site/version.json?release=$id-before-switch"
    if ($current.version -ne '1.0.22' -or [string]$current.build_number -ne '25') {
        throw 'La version publique a change pendant la preparation : transmettre le journal.'
    }
    $receipt['deployment_attempted'] = $true
    $lines = @(& ssh -T @transport vps "python3 $remote/publish_web_release.py --archive $remote/web-release.tar.gz --archive-sha256 $archiveHash --execute")
    $exitCode = $LASTEXITCODE
    $lines | Write-Output
    if ($exitCode -ne 0) { throw 'Publication interrompue : transmettre ce journal avant toute relance.' }
    $deployed = ($lines -join "`n") | ConvertFrom-Json
    if ($deployed.status -ne 'WEB_DEPLOYED_LOCAL_CHECKS_PASSED' -or $deployed.web_deployed -ne $true -or $deployed.main_sha256 -ne $expectedMain) {
        throw 'Resultat VPS inattendu : transmettre ce journal.'
    }
    $receipt['deployment_performed'] = $true
    $receipt['rollback_directory'] = $deployed.rollback_directory
    $published = Invoke-RestMethod "$site/version.json?release=$id-after-switch"
    if ($published.version -ne $releaseVersion -or [string]$published.build_number -ne [string]$releaseBuild) { throw 'Version publique incorrecte.' }
    Invoke-WebRequest "$site/main.dart.js?release=$id-after-switch" -OutFile $publicMain -UseBasicParsing
    if ((Get-Hash $publicMain) -ne $expectedMain) { throw 'Empreinte publique incorrecte : transmettre le journal.' }
    $receipt['status'] = 'WEB_PUBLISHED_HTTPS_VERIFIED'
    $receipt['public_https_verified'] = $true
    'WEB_PUBLIC_1.0.23_26_HTTPS_ET_EMPREINTE_OK'
    "RETOUR_ARRIERE_WEB=$($deployed.rollback_directory)"
}
catch {
    $receipt['status'] = 'PUBLICATION_BLOCKED'
    throw
}
finally {
    [IO.File]::WriteAllText((Join-Path $operation 'publication.json'), ($receipt | ConvertTo-Json -Depth 6), [Text.UTF8Encoding]::new($false))
    "DOSSIER_PUBLICATION=$operation"
    Stop-Transcript | Out-Null
}
