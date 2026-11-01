[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [switch]$Execute,
    [switch]$SyncFrontend,
    [switch]$ApproveBackupSchema,
    [ValidatePattern('^[a-f0-9-]{36}$')]
    [string]$ExpectedCampaignId = 'c430e401-34ca-4f4b-8713-aaab44faba6f'
)
$ErrorActionPreference = 'Stop'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\RecruitmentTestCleanup\$id"
$remote = "/opt/enactspace/operations/cleanup-recruitment-test-$id"
$unit = "enactspace-recruitment-test-cleanup-$id"
$runner = 'cleanup_recruitment_test_campaign.py'
$tests = 'test_cleanup_recruitment_*.py'
$backupArgument = if ($ApproveBackupSchema) { ' --approve-backup-schema' } else { '' }
$campaignArgument = " --expected-campaign-id $ExpectedCampaignId"
$files = @(
    @{ source = 'tools/cleanup_recruitment_test_campaign.py'; target = 'cleanup_recruitment_test_campaign.py'; sha256 = '554c9efa13f77154135465e387d99691e03ba967022284778845ff62c72d2aec' },
    @{ source = 'tools/recruitment_test_campaign_scope.py'; target = 'recruitment_test_campaign_scope.py'; sha256 = '3d877a78d7717c0733ad140b26589e73ab976d591e736df6b8bdd1264f51638a' },
    @{ source = 'tools/recruitment_backup_schema_guard.py'; target = 'recruitment_backup_schema_guard.py'; sha256 = 'c02cb1c9c1fcb8fdbf5ebb54a0417b89902e920ebdd43154994b0c92a3035823' },
    @{ source = 'tools/test_cleanup_recruitment_test_campaign.py'; target = 'test_cleanup_recruitment_test_campaign.py'; sha256 = 'e61f802f77a63f74d94a0b63d8661673e4f456b8f53c8dfb35c0753b6554e457' },
    @{ source = 'tools/test_cleanup_recruitment_backup_guard.py'; target = 'test_cleanup_recruitment_backup_guard.py'; sha256 = '89d7b90c69faca01e238850de1e782de7a853a311e8f43d941bbe273cef73675' },
    @{ source = 'tools/publish_recruitment_campaign_backend.py'; target = 'publish_recruitment_campaign_backend.py'; sha256 = '2ad80ede7b3c51eb4b349f0d35c6b595f28fc2fa58e2c3fed59a25495efb5a15' },
    @{ source = 'backend/app/scripts/prelaunch_scheduled_backup.py'; target = 'prelaunch_scheduled_backup.py'; sha256 = 'bf18b1b978bddad5e3773a33060effd8617a184bdcdb29a51d8b3206113c0a80' },
    @{ source = 'backend/test_recruitment_campaign_lifecycle.py'; target = 'test_recruitment_campaign_lifecycle.py'; sha256 = '401ef6cc965abcb7c1d63611d0e20e55d24f8a9616525302ea976021b41c1f64' },
    @{ source = 'backend/test_recruitment_test_campaign_cleanup.py'; target = 'test_recruitment_test_campaign_cleanup.py'; sha256 = '91efc46e548027b1c32dc73a9f617d04750df1f3e1aaef04d9e39e898d318d9d' },
    @{ source = 'tools/sync_recruitment_lifecycle_windows.ps1'; target = 'sync_recruitment_lifecycle_windows.ps1'; sha256 = '830ccf7b304d9d2a767f6bb44e314f81434fc7eddd80248e09474c619d5b2048' }
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
        throw 'Integrite distante incorrecte : aucune operation lancee.'
    }
}
& ssh @sshOptions vps "python3 -m unittest discover -s $remote -p '$tests' -v"
if ($LASTEXITCODE -ne 0) { throw 'Tests du lanceur echoues : aucun nettoyage lance.' }
"DOSSIER_OPERATION=$remote"
if (!$Execute) {
    & ssh @sshOptions vps "python3 $remote/$runner --operation $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Inventaire bloque : transmettre le compte rendu.' }
    'INVENTAIRE_SEUL_SANS_SUPPRESSION'
    return
}
# The remote operation continues if SSH or this terminal closes.
"UNITE_OPERATION=$unit"
& ssh @sshOptions vps (
    "systemd-run --unit=$unit --collect --service-type=exec " +
    "--property=RuntimeMaxSec=30min --property=TimeoutStopSec=3min " +
    "/usr/bin/python3 $remote/$runner --operation $remote --execute$backupArgument$campaignArgument"
)
if ($LASTEXITCODE -ne 0) {
    throw "Lancement non confirme. Consulter $remote/cleanup.json et l'unite $unit avant toute relance."
}
$deadline = [DateTime]::UtcNow.AddMinutes(34)
$report = $null
$attempt = 0
while ([DateTime]::UtcNow -lt $deadline) {
    $attempt++
    $raw = @(& ssh @sshOptions vps "if test -f $remote/cleanup.json; then cat $remote/cleanup.json; fi")
    if ($LASTEXITCODE -eq 0 -and $raw.Count -gt 0) {
        $report = ($raw -join "`n") | ConvertFrom-Json
        break
    }
    if ($attempt % 6 -eq 1) { "NETTOYAGE_TEST_EN_COURS=$unit" }
    Start-Sleep -Seconds 5
}
if ($null -eq $report) {
    throw "Compte rendu absent. Consulter $remote/cleanup.json et l'unite $unit avant toute relance."
}
$report | ConvertTo-Json -Depth 10
if ($report.status -ne 'TEST_CAMPAIGN_CLEANUP_PASSED' -or
    $report.production_services_restored -ne $true) {
    throw 'Nettoyage bloque : transmettre le compte rendu masque.'
}
$health = Invoke-RestMethod "https://api-enactspace.kerunjombor.net/health?check=$id"
$timeline = Invoke-RestMethod "https://api-enactspace.kerunjombor.net/api/recruitment/campaigns/timeline?check=$id"
if ($health.ok -ne $true -or $health.version -ne '1.0.21' -or
    $timeline.timezone -ne 'Africa/Dakar' -or @($timeline.campaigns).Count -ne 0) {
    throw 'Nettoyage local confirme, controle HTTPS public inattendu : transmettre le resultat.'
}
'CAMPAGNE_TEST_ET_DONNEES_LIEES_SUPPRIMEES'
'COMPTES_EXISTANTS_CONSERVES_ET_API_PUBLIQUE_OK'
'CAMPAGNE_REELLE_NON_CREEE'
if ($SyncFrontend) {
    & (Join-Path $local 'sync_recruitment_lifecycle_windows.ps1') -Commit $Commit
    if (!$?) { throw 'Nettoyage termine, integration interface interrompue : transmettre le resultat.' }
}
