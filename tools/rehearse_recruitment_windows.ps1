[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$Commit
)
$ErrorActionPreference = 'Stop'
$manifestHash = '81cf5f8e77c24238e5c6dbe33aaa9f8c00a476fb6851dcd966602c3c60016286'
$runnerHash = 'f0a07a1551defab25f30e0c82da6398d2095cee9bf5991ce51fcd7ac8c992024'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentRehearsals\$id"
$payload = Join-Path $local 'payload'
$remote = "/opt/enactspace/staging/recruitment-rehearsal-$id"
New-Item -ItemType Directory -Path $payload -Force | Out-Null

function DownloadChecked([string]$Relative, [string]$Destination, [string]$Expected) {
    New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Destination)) -Force | Out-Null
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$Relative" `
        -OutFile $Destination -UseBasicParsing
    if ((Get-FileHash $Destination -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Expected) {
        throw "Integrite incorrecte : $Relative"
    }
}

$manifest = Join-Path $local 'manifest.json'
$runner = Join-Path $local 'rehearse_recruitment_candidate.py'
DownloadChecked 'tools/recruitment_rehearsal_manifest.json' $manifest $manifestHash
DownloadChecked 'tools/rehearse_recruitment_candidate.py' $runner $runnerHash
$data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
foreach ($item in $data.files.PSObject.Properties) {
    DownloadChecked $item.Name (Join-Path $payload $item.Name) ([string]$item.Value)
}

& ssh vps "install -d -m 700 $remote"
if ($LASTEXITCODE -ne 0) { throw 'Preparation VPS echouee.' }
& scp $manifest $runner "vps:$remote/"
if ($LASTEXITCODE -ne 0) { throw 'Transfert des outils echoue.' }
& scp -r $payload "vps:$remote/"
if ($LASTEXITCODE -ne 0) { throw 'Transfert des sources echoue.' }
$integrity = @(& ssh vps "sha256sum $remote/manifest.json $remote/rehearse_recruitment_candidate.py")
if ($LASTEXITCODE -ne 0 -or $integrity.Count -ne 2) { throw 'Verification VPS interrompue.' }
if (([string]$integrity[0] -split '\s+')[0] -ne $manifestHash -or
    ([string]$integrity[1] -split '\s+')[0] -ne $runnerHash) {
    throw 'Integrite distante incorrecte : aucun essai lance.'
}

"DOSSIER_REPETITION=$local"
'REPETITION_ISOLEE_SANS_DEPLOIEMENT'
& ssh vps "python3 $remote/rehearse_recruitment_candidate.py --directory $remote"
if ($LASTEXITCODE -ne 0) { throw 'Repetition bloquee : transmettre le compte rendu.' }
'REPETITION_TERMINEE_TRANSMETTRE_LE_COMPTE_RENDU'
