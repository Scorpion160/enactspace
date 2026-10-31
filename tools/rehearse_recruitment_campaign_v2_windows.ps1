[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [ValidatePattern('^enactspace-backend:recruitment-hardening-[a-f0-9]{12}$')] [string]$PreviousCandidate,
    [ValidatePattern('^sha256:[a-f0-9]{64}$')] [string]$PreviousImageId
)
$ErrorActionPreference = 'Stop'
if ([bool]$PreviousCandidate -ne [bool]$PreviousImageId) { throw 'Les deux identifiants precedents sont requis.' }
$manifestHash = 'eac5efec0310e935ad3b02bb9fbdad446db0fc06aaa768510b8c3c3d49904e7c'
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
DownloadChecked 'tools/recruitment_campaign_v2_manifest.json' $manifest $manifestHash
$data = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
foreach ($item in $data.files.PSObject.Properties) {
    DownloadChecked $item.Name (Join-Path $payload $item.Name) ([string]$item.Value)
}
$runnerName = 'rehearse_recruitment_campaign_v2.py'
$helperName = 'rehearse_recruitment_candidate.py'
$runner = Join-Path $local $runnerName
$helper = Join-Path $local $helperName
Copy-Item -LiteralPath (Join-Path $payload "tools\$runnerName") -Destination $runner
Copy-Item -LiteralPath (Join-Path $payload "tools\$helperName") -Destination $helper

& ssh vps "install -d -m 700 $remote"
if ($LASTEXITCODE -ne 0) { throw 'Preparation VPS echouee.' }
& scp $manifest $runner $helper "vps:$remote/"
if ($LASTEXITCODE -ne 0) { throw 'Transfert des outils echoue.' }
& scp -r $payload "vps:$remote/"
if ($LASTEXITCODE -ne 0) { throw 'Transfert des sources echoue.' }
$integrity = @(& ssh vps "sha256sum $remote/manifest.json $remote/$runnerName $remote/$helperName")
if ($LASTEXITCODE -ne 0 -or $integrity.Count -ne 3) { throw 'Verification VPS interrompue.' }
if (([string]$integrity[0] -split '\s+')[0] -ne $manifestHash -or
    ([string]$integrity[1] -split '\s+')[0] -ne [string]$data.files.'tools/rehearse_recruitment_campaign_v2.py' -or
    ([string]$integrity[2] -split '\s+')[0] -ne [string]$data.files.'tools/rehearse_recruitment_candidate.py') {
    throw 'Integrite distante incorrecte : aucun essai lance.'
}

"DOSSIER_REPETITION=$local"
'CAMPAGNE_JURY_QUESTIONNAIRE_RECETTE_ISOLEE'
if ($PreviousCandidate) {
    & ssh vps "python3 $remote/$runnerName --cleanup-candidate $PreviousCandidate --expected-image-id $PreviousImageId"
    if ($LASTEXITCODE -ne 0) { throw 'Nettoyage precedent bloque : transmettre le compte rendu.' }
}
& ssh vps "python3 $remote/$runnerName --directory $remote"
if ($LASTEXITCODE -ne 0) { throw 'Recette campagne bloquee : transmettre le compte rendu.' }
'RECETTE_TERMINEE_TRANSMETTRE_LE_COMPTE_RENDU'
'MIGRATION_PRODUCTION_ET_DEPLOIEMENT_NON_EFFECTUES'
