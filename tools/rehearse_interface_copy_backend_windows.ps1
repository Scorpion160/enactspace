[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$Commit
)
$ErrorActionPreference = 'Stop'
$manifestHash = '75622d0a3e776c4c9adce6e194e25cbbea525b4e9746c79f62c1aaebf122ee54'
$runnerHash = 'd93f12e42f7f86e2e36e33427bc90390a7ee5a05fb50ec5ea6c58c16132f0b74'
$runnerName = 'rehearse_interface_copy_backend.py'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\InterfaceCopyBackend\$id"
$payload = Join-Path $local 'payload'
$remote = "/opt/enactspace/staging/interface-copy-backend-$id"
$sshOptions = @('-T', '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
New-Item -ItemType Directory -Path $payload -Force | Out-Null

function Get-CheckedFile([string]$Revision, [string]$Path, [string]$Target, [string]$Expected) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Target)) -Force | Out-Null
    $url = "https://raw.githubusercontent.com/Scorpion160/enactspace/$Revision/$Path"
    Invoke-WebRequest $url -OutFile $Target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $Target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected) {
        throw "Integrite incorrecte : $Path"
    }
}

Start-Transcript -Path (Join-Path $local 'rehearsal.log') | Out-Null
try {
    $manifest = Join-Path $local 'manifest.json'
    $runner = Join-Path $local $runnerName
    Get-CheckedFile $Commit 'tools/interface_copy_backend_manifest.json' $manifest $manifestHash
    Get-CheckedFile $Commit "tools/$runnerName" $runner $runnerHash
    $data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    foreach ($item in @($data.runtime.PSObject.Properties) + @($data.tests.PSObject.Properties)) {
        Get-CheckedFile $data.source_commit $item.Name (Join-Path $payload $item.Name) ([string]$item.Value)
    }

    & ssh @sshOptions vps "install -d -m 700 $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Preparation du dossier VPS echouee.' }
    & scp $manifest $runner "vps:$remote/"
    if ($LASTEXITCODE -ne 0) { throw 'Transfert du manifeste ou du lanceur echoue.' }
    & scp -r $payload "vps:$remote/"
    if ($LASTEXITCODE -ne 0) { throw 'Transfert des sources et des tests echoue.' }
    $hashes = @(& ssh @sshOptions vps "sha256sum $remote/manifest.json $remote/$runnerName")
    if ($LASTEXITCODE -ne 0 -or $hashes.Count -ne 2 -or
        ([string]$hashes[0] -split '\s+')[0] -ne $manifestHash -or
        ([string]$hashes[1] -split '\s+')[0] -ne $runnerHash) {
        throw 'Integrite des outils distants incorrecte.'
    }

    & ssh @sshOptions vps "python3 $remote/$runnerName --directory $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Recette interrompue : transmettre le compte rendu.' }
}
finally {
    "DOSSIER_RECETTE_WINDOWS=$local"
    "DOSSIER_RECETTE_VPS=$remote"
    Stop-Transcript | Out-Null
}
