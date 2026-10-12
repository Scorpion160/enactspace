[CmdletBinding()]
param(
    [string]$Version = '1.0.16',
    [int]$BuildNumber = 19,
    [switch]$Publish
)
$ErrorActionPreference = 'Stop'
if ($Version -notmatch '^\d+\.\d+\.\d+$' -or $BuildNumber -lt 1) { throw 'Version invalide.' }
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$defines = "$env:LOCALAPPDATA\EnactSpace\WebRelease\22bedeed75934001adf66de4c3f8c6f3\web-client-defines.json"
$builder = Join-Path $repo 'tools\build_web_with_firebase.ps1'
$web = Join-Path $repo 'frontend\build\web'
foreach ($path in @($defines, $builder)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Fichier requis introuvable : $path" }
}
$config = Get-Content -LiteralPath $defines -Raw | ConvertFrom-Json
foreach ($name in @('ENACTSPACE_API_URL','ENACTSPACE_FIREBASE_PROJECT_ID','ENACTSPACE_FIREBASE_MESSAGING_SENDER_ID','ENACTSPACE_FIREBASE_API_KEY_WEB','ENACTSPACE_FIREBASE_APP_ID_WEB','ENACTSPACE_FIREBASE_VAPID_PUBLIC_KEY','ENACTSPACE_GIPHY_API_KEY_WEB')) {
    if ([string]::IsNullOrWhiteSpace([string]$config.$name)) { throw "Configuration incomplete : $name" }
}
if (([string]$config.ENACTSPACE_API_URL).TrimEnd('/') -ne 'https://api-enactspace.kerunjombor.net') { throw 'Adresse API inattendue.' }
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\WebPackages\$id"
$remote = "/opt/enactspace/staging/web-publication-$id"
New-Item -ItemType Directory -Path $local | Out-Null
# Fetch the previously verified publisher before starting the build.
$toolCommit = '614fdb493b03693b816eba62e9997906cddb1b92'
$checks = @{
    'publish_web_release.py' = 'd09e33fcddfda04adc6009ae89b5c25886b65d467c28ced9b8147ee6dbafc9fe'
    'test_publish_web_release.py' = '1a6ed7aaa0f065b11ad6bd1569b52bfd84a0069acda8481a9961cbb762b4cec4'
}
foreach ($name in $checks.Keys) {
    $path = Join-Path $local $name
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$toolCommit/tools/$name" -OutFile $path -UseBasicParsing
    if ((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $checks[$name]) { throw "Integrite incorrecte : $name" }
}
$started = Get-Date
& $builder -DefinesPath $defines -FlutterArgs @("--build-name=$Version", "--build-number=$BuildNumber")
if (!$?) { throw 'Compilation web echouee.' }
foreach ($name in @('index.html','main.dart.js','flutter_bootstrap.js','firebase-messaging-sw.js','version.json')) {
    if (!(Test-Path -LiteralPath (Join-Path $web $name) -PathType Leaf)) { throw "Build incomplet : $name" }
}
$versionData = Get-Content -LiteralPath (Join-Path $web 'version.json') -Raw | ConvertFrom-Json
if ($versionData.version -ne $Version -or [string]$versionData.build_number -ne [string]$BuildNumber) { throw 'Version du build incorrecte.' }
$main = Get-Item -LiteralPath (Join-Path $web 'main.dart.js')
if ($main.LastWriteTime -lt $started) { throw 'Fichier principal non renouvele.' }
$mainHash = (Get-FileHash $main.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$receipt = [ordered]@{ version=$Version; build_number=$BuildNumber; main_sha256=$mainHash; deployment_performed=$false }
[IO.File]::WriteAllText((Join-Path $local 'build.json'), ($receipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
"BUILD_WEB_${Version}_${BuildNumber}_OK"
"MAIN_SHA256=$mainHash"
if (!$Publish) { 'DEPLOIEMENT_NON_EFFECTUE'; return }
$publisher = Join-Path $local 'publish_web_release.py'
$content = [IO.File]::ReadAllText($publisher)
$changes = @{
    'caa61e7b9de71b5fbe1e7282ca391a58082744f14370615dc3d265e102e79235' = $mainHash
    "version.get('version')!='1.0.11'" = "version.get('version')!='$Version'"
    "str(version.get('build_number'))!='14'" = "str(version.get('build_number'))!='$BuildNumber'"
}
foreach ($needle in $changes.Keys) {
    if ([regex]::Matches($content, [regex]::Escape($needle)).Count -ne 1) { throw 'Structure du programme de publication inattendue.' }
    $content = $content.Replace($needle, $changes[$needle])
}
[IO.File]::WriteAllText($publisher, $content, [Text.UTF8Encoding]::new($false))
$publisherHash = (Get-FileHash $publisher -Algorithm SHA256).Hash.ToLowerInvariant()
$archive = Join-Path $local 'web-release.tar.gz'
& tar.exe -czf $archive -C $web .
if ($LASTEXITCODE -ne 0) { throw 'Creation archive echouee.' }
$archiveHash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLowerInvariant()
& ssh vps "install -d -m 700 $remote"
if ($LASTEXITCODE -ne 0) { throw 'Preparation VPS echouee.' }
foreach ($name in @('web-release.tar.gz','publish_web_release.py','test_publish_web_release.py')) {
    & scp (Join-Path $local $name) "vps:$remote/"
    if ($LASTEXITCODE -ne 0) { throw "Transfert echoue : $name" }
}
$result = & ssh vps "sha256sum $remote/publish_web_release.py"
if ($LASTEXITCODE -ne 0 -or (([string]$result -split '\s+')[0]) -ne $publisherHash) { throw 'Integrite du programme VPS incorrecte.' }
& ssh vps "python3 -m unittest discover -s $remote -p test_publish_web_release.py -v"
if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : publication arretee.' }
& ssh vps "python3 $remote/publish_web_release.py --archive $remote/web-release.tar.gz --archive-sha256 $archiveHash --execute"
if ($LASTEXITCODE -ne 0) { throw 'Publication interrompue : transmettre le compte rendu.' }
$receipt['deployment_performed'] = $true
$receipt['public_https_verified'] = $false
[IO.File]::WriteAllText((Join-Path $local 'publication.json'), ($receipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
# Verify the served release through public HTTPS, including the JS bytes.
$site = 'https://enactspace.kerunjombor.net'
$public = Invoke-RestMethod "$site/version.json?release=$id"
if ($public.version -ne $Version -or [string]$public.build_number -ne [string]$BuildNumber) { throw 'Version publique incorrecte.' }
$publicMain = Join-Path $local 'main.public.dart.js'
Invoke-WebRequest "$site/main.dart.js?release=$id" -OutFile $publicMain -UseBasicParsing
if ((Get-FileHash $publicMain -Algorithm SHA256).Hash.ToLowerInvariant() -ne $mainHash) { throw 'Empreinte du fichier public incorrecte : transmettre le resultat.' }
$receipt.deployment_performed = $true
$receipt['public_https_verified'] = $true
[IO.File]::WriteAllText((Join-Path $local 'publication.json'), ($receipt | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
"WEB_PUBLIC_${Version}_${BuildNumber}_HTTPS_ET_EMPREINTE_OK"
$public | Format-List
'BACKEND_ET_ANDROID_NON_MODIFIES'
