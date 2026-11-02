[CmdletBinding()]
param(
    [string]$Repository = (Join-Path $env:USERPROFILE 'Documents\EnactSpaceRecovery\enactspace-20260927'),
    [string]$ValidationDirectory = (Join-Path $env:LOCALAPPDATA 'EnactSpace\InterfaceCopyReview\b39a52771da8498a98aca4b94efa1aca'),
    [string]$DefinesPath = (Join-Path $env:LOCALAPPDATA 'EnactSpace\WebRelease\22bedeed75934001adf66de4c3f8c6f3\web-client-defines.json')
)
$ErrorActionPreference = 'Stop'
$sourceCommit = 'de640506fe8d07bd93f19528ebf0a6d8a488ebcb'
$manifestHash = 'b0237a194a437cc52ca282d82c135bfd0d82d6235fbf31dd850f33bd21640516'
$releaseVersion = '1.0.24'
$releaseBuild = 27
$builderFiles = [ordered]@{
    'tools/build_web_with_firebase.ps1' = '8fb0982bb33b282a6ea3ec1a2f4a4718dc66cfdddc2694085e641994032abb5c'
    'tools/generate_firebase_web_worker.py' = 'a4f642c1badecb2dff52db99982295b012110b65b95b44adfc854b7a7d43c611'
    'tools/templates/firebase-messaging-sw.template.js' = '31bdc13249e3d82eb1a67994c6fe719ba6df1df0c72a93cc61a9a97206d21b59'
}

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-NormalizedHash([string]$Path) {
    Get-TextHash ([IO.File]::ReadAllText($Path).Replace("`r`n", "`n"))
}

function Get-CanonicalDartHash([string]$Path) {
    $savedEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $output = @(& dart format --output=show --summary=none --show=none `
            --language-version=latest --page-width=80 --trailing-commas=automate $Path)
        if ($LASTEXITCODE -ne 0) { throw 'Lecture du code Dart impossible.' }
        Get-TextHash (($output -join "`n") + "`n")
    }
    finally { [Console]::OutputEncoding = $savedEncoding }
}

$Repository = [IO.Path]::GetFullPath($Repository)
$ValidationDirectory = [IO.Path]::GetFullPath($ValidationDirectory)
$id = [guid]::NewGuid().ToString('N')
$operation = Join-Path $env:LOCALAPPDATA "EnactSpace\WebInterfaceBuilds\$id"
$web = Join-Path $operation 'web'
$archive = Join-Path $operation 'web-release.tar.gz'
New-Item -ItemType Directory -Path $operation | Out-Null
$receipt = [ordered]@{
    status = 'WEB_BUILD_BLOCKED'; validated_sync_commit = $sourceCommit
    validation_directory = $ValidationDirectory; version = $releaseVersion
    build_number = $releaseBuild; deployment_performed = $false
}
Start-Transcript -Path (Join-Path $operation 'build.log') | Out-Null
try {
    $validation = Get-Content -LiteralPath (Join-Path $ValidationDirectory 'validation.json') -Raw | ConvertFrom-Json
    if ($validation.source_commit -ne $sourceCommit -or $validation.status -ne 'LOCAL_VALIDATION_PASSED' -or
        $validation.source_sync_performed -ne $true -or $validation.dart_analysis_passed -ne $true -or
        $validation.flutter_tests_passed -ne $true -or $validation.runtime_captures_generated -ne $true) {
        throw 'Le compte rendu attendu de la validation Windows est absent ou incomplet.'
    }
    $staging = Join-Path $ValidationDirectory 'staging'
    $manifestPath = Join-Path $staging 'manifest.json'
    if ((Get-Hash $manifestPath) -ne $manifestHash) { throw 'Manifeste de validation incorrect.' }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $sources = @(@($manifest.files) + @($manifest.requirements) | Where-Object {
        $_.path -like 'frontend/lib/*.dart' -or $_.path -in @('frontend/pubspec.yaml', 'frontend/pubspec.lock')
    })
    $before = @{}
    foreach ($entry in $sources) {
        $local = Join-Path $Repository $entry.path
        $before[$entry.path] = Get-Hash $local
        if ((Get-NormalizedHash $local) -eq $entry.sha256) { continue }
        $validated = Join-Path $staging ('target/' + $entry.path)
        if (!$entry.path.EndsWith('.dart') -or (Get-Hash $validated) -ne $entry.sha256 -or
            (Get-CanonicalDartHash $local) -ne (Get-CanonicalDartHash $validated)) {
            throw "Source modifiee depuis la validation : $($entry.path)"
        }
    }
    foreach ($path in $builderFiles.Keys) {
        if ((Get-NormalizedHash (Join-Path $Repository $path)) -ne $builderFiles[$path]) {
            throw "Outil de compilation different de la reference : $path"
        }
    }
    if (!(Test-Path -LiteralPath $DefinesPath -PathType Leaf)) { throw 'Configuration privee du build web introuvable.' }
    Get-Command tar.exe -ErrorAction Stop | Out-Null
    $public = Invoke-RestMethod "https://enactspace.kerunjombor.net/version.json?prepare=$id" -UseBasicParsing
    if ($public.version -ne '1.0.23' -or [string]$public.build_number -ne '26') {
        throw 'La version publique differe de la reference 1.0.23 (26). Transmettre le journal.'
    }

    'COMPILATION_WEB_1.0.24_27_EN_COURS'
    $builder = Join-Path $Repository 'tools/build_web_with_firebase.ps1'
    & $builder -DefinesPath $DefinesPath -FlutterArgs @('--no-pub', "--output=$web", "--build-name=$releaseVersion", "--build-number=$releaseBuild")
    if (!$?) { throw 'La compilation web a echoue.' }
    foreach ($entry in $sources) {
        if ((Get-Hash (Join-Path $Repository $entry.path)) -ne $before[$entry.path]) {
            throw "Source modifiee pendant la compilation : $($entry.path)"
        }
    }
    foreach ($name in @('index.html', 'main.dart.js', 'flutter_bootstrap.js', 'firebase-messaging-sw.js', 'version.json')) {
        if (!(Test-Path -LiteralPath (Join-Path $web $name) -PathType Leaf)) { throw "Build incomplet : $name" }
    }
    $version = Get-Content -LiteralPath (Join-Path $web 'version.json') -Raw | ConvertFrom-Json
    if ($version.version -ne $releaseVersion -or [string]$version.build_number -ne [string]$releaseBuild) {
        throw 'Version ou numero du build inattendu.'
    }
    $receipt['main_sha256'] = Get-Hash (Join-Path $web 'main.dart.js')
    & tar.exe -czf $archive -C $web .
    if ($LASTEXITCODE -ne 0) { throw 'Creation de l archive web echouee.' }
    if ((Get-Hash (Join-Path $web 'main.dart.js')) -ne $receipt.main_sha256) { throw 'Le JavaScript a change pendant la preparation.' }
    $receipt['archive_sha256'] = Get-Hash $archive
    $receipt['archive_path'] = $archive
    $receipt['web_directory'] = $web
    $receipt['status'] = 'WEB_BUILD_1.0.24_27_READY'
    $receipt | ConvertTo-Json -Depth 4
}
finally {
    [IO.File]::WriteAllText((Join-Path $operation 'build.json'), ($receipt | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
    "DOSSIER_BUILD_WEB=$operation"
    Stop-Transcript | Out-Null
}
