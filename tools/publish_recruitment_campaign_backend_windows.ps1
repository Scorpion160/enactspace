[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [switch]$Execute
)
$ErrorActionPreference = 'Stop'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentReleases\$id"
$remote = "/opt/enactspace/operations/publish-recruitment-$id"
$unit = "enactspace-recruitment-release-$id"
$runner = 'publish_recruitment_campaign_backend.py'
$tests = 'test_publish_recruitment_campaign_backend.py'
$files = @(
    @{ source = "tools/$runner"; target = $runner; sha256 = '50e8d990c6651a8ef4bf101a543118044f6b096ebb47194cb2eaa8daef963353' },
    @{ source = "tools/$tests"; target = $tests; sha256 = 'c3347dad89d422e29fa7d4554177085e2299435a2b4d3a32cd7b11c4e1b96bee' },
    @{ source = 'tools/recruitment_campaign_v2_manifest.json'; target = 'manifest.json'; sha256 = '4862607c0be62f6138543354423ab0b569efc429c0cb6432e5e2b2265edf92b2' }
)
New-Item -ItemType Directory -Path $local | Out-Null
$sshOptions = @('-T', '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
foreach ($file in $files) {
    $target = Join-Path $local $file.target
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($file.source)" `
        -OutFile $target -UseBasicParsing
    if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) {
        throw "Integrite incorrecte : $($file.target)"
    }
}
& ssh @sshOptions vps "install -d -m 700 $remote"
if ($LASTEXITCODE -ne 0) { throw 'Preparation du dossier VPS echouee.' }
foreach ($file in $files) {
    & scp (Join-Path $local $file.target) "vps:$remote/$($file.target)"
    if ($LASTEXITCODE -ne 0) { throw 'Transfert VPS echoue.' }
    $result = @(& ssh @sshOptions vps "sha256sum $remote/$($file.target)")
    if ($LASTEXITCODE -ne 0 -or $result.Count -ne 1 -or
        (([string]$result[0] -split '\s+')[0] -ne $file.sha256)) {
        throw 'Integrite distante incorrecte : aucun deploiement lance.'
    }
}
& ssh @sshOptions vps "python3 -m unittest discover -s $remote -p $tests -v"
if ($LASTEXITCODE -ne 0) { throw 'Tests du lanceur echoues : aucun deploiement lance.' }

"DOSSIER_OPERATION=$remote"
if (!$Execute) {
    & ssh @sshOptions vps "python3 $remote/$runner --directory $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Controle prealable bloque : transmettre le compte rendu.' }
    'CONTROLE_SEUL_SANS_MIGRATION_NI_DEPLOIEMENT'
    return
}

# systemd keeps the operation alive if this terminal or the SSH link closes.
"UNITE_OPERATION=$unit"
& ssh @sshOptions vps (
    "systemd-run --unit=$unit --collect --service-type=exec " +
    "--property=RuntimeMaxSec=25min --property=TimeoutStopSec=3min " +
    "/usr/bin/python3 $remote/$runner --directory $remote --execute"
)
if ($LASTEXITCODE -ne 0) { throw "Lancement non confirme. Consulter l'unite $unit et $remote/deployment.json avant toute relance." }
$deadline = [DateTime]::UtcNow.AddMinutes(29)
$report = $null
$attempt = 0
while ([DateTime]::UtcNow -lt $deadline) {
    $attempt++
    $raw = @(& ssh @sshOptions vps "if test -f $remote/deployment.json; then cat $remote/deployment.json; fi")
    if ($LASTEXITCODE -eq 0 -and $raw.Count -gt 0) {
        $report = ($raw -join "`n") | ConvertFrom-Json
        break
    }
    if ($attempt % 6 -eq 1) { "DEPLOIEMENT_EN_COURS=$unit" }
    Start-Sleep -Seconds 5
}
if ($null -eq $report) {
    throw "Compte rendu absent. Consulter $remote/deployment.json et l'unite $unit avant toute relance."
}
$report | ConvertTo-Json -Depth 8
if ($report.status -ne 'RECRUITMENT_BACKEND_DEPLOYED') {
    throw 'Bascule bloquee : transmettre le compte rendu masque.'
}
try {
    $health = Invoke-RestMethod "https://api-enactspace.kerunjombor.net/health?check=$id"
    $timeline = Invoke-RestMethod "https://api-enactspace.kerunjombor.net/api/recruitment/campaigns/timeline?check=$id"
    if ($health.ok -ne $true -or $health.version -ne '1.0.21' -or $timeline.timezone -ne 'Africa/Dakar') {
        throw 'Reponse publique inattendue.'
    }
}
catch {
    throw 'Deploiement local reussi, verification HTTPS publique echouee : transmettre le resultat.'
}
'RECRUTEMENT_BACKEND_1_0_21_SCHEMA_0033_HTTPS_OK'
'BUILD_WEB_ET_ACTIVATION_CAMPAGNE_RESTENT_A_FAIRE'
