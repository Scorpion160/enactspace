[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-f0-9]{40}$')]
    [string]$Commit,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\InterfaceCopyBackendReleases\$id"
$remote = "/opt/enactspace/operations/publish-interface-copy-$id"
$unit = "enactspace-interface-copy-release-$id"
$runner = 'publish_interface_copy_backend.py'
$tests = 'test_publish_interface_copy_backend.py'
$files = @(
    @{ source = "tools/$runner"; target = $runner; sha256 = '2da52dd0dae2703f00767076e9ea2b9c11dec3eb76654d788875e09eeac783d9' },
    @{ source = "tools/$tests"; target = $tests; sha256 = '2446086eb0268b06d1f7dd352a132180bf518c60c26b4acf66a53674ec6663e4' },
    @{ source = 'tools/publish_recruitment_campaign_backend.py'; target = 'publish_recruitment_campaign_backend.py'; sha256 = '2ad80ede7b3c51eb4b349f0d35c6b595f28fc2fa58e2c3fed59a25495efb5a15' },
    @{ source = 'tools/interface_copy_backend_manifest.json'; target = 'manifest.json'; sha256 = '75622d0a3e776c4c9adce6e194e25cbbea525b4e9746c79f62c1aaebf122ee54' }
)
$sshOptions = @('-T', '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=8')
New-Item -ItemType Directory -Path $local | Out-Null
Start-Transcript -Path (Join-Path $local 'publication.log') | Out-Null
try {
    foreach ($file in $files) {
        $target = Join-Path $local $file.target
        $url = "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($file.source)"
        Invoke-WebRequest $url -OutFile $target -UseBasicParsing
        if ((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant() -ne $file.sha256) {
            throw "Integrite incorrecte : $($file.target)"
        }
    }
    & ssh @sshOptions vps "install -d -m 700 $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Preparation du dossier VPS echouee.' }
    foreach ($file in $files) {
        & scp (Join-Path $local $file.target) "vps:$remote/$($file.target)"
        if ($LASTEXITCODE -ne 0) { throw 'Transfert VPS echoue.' }
        $hash = @(& ssh @sshOptions vps "sha256sum $remote/$($file.target)")
        if ($LASTEXITCODE -ne 0 -or $hash.Count -ne 1 -or
            ([string]$hash[0] -split '\s+')[0] -ne $file.sha256) {
            throw "Integrite VPS incorrecte : $($file.target)"
        }
    }
    & ssh @sshOptions vps "python3 -m unittest discover -s $remote -p $tests -v"
    if ($LASTEXITCODE -ne 0) { throw 'Tests du lanceur echoues.' }

    if (!$Execute) {
        & ssh @sshOptions vps "python3 $remote/$runner --directory $remote"
        if ($LASTEXITCODE -ne 0) { throw 'Controle prealable interrompu.' }
        return
    }

    "UNITE_OPERATION=$unit"
    $launch = "systemd-run --unit=$unit --collect --service-type=exec " +
        "--property=RuntimeMaxSec=25min --property=TimeoutStopSec=3min " +
        "/usr/bin/python3 $remote/$runner --directory $remote --execute"
    & ssh @sshOptions vps $launch
    if ($LASTEXITCODE -ne 0) { throw "Lancement non confirme. Verifier $unit avant toute relance." }

    $deadline = [DateTime]::UtcNow.AddMinutes(29)
    $attempt = 0
    $report = $null
    while ([DateTime]::UtcNow -lt $deadline) {
        $attempt++
        $lines = @(& ssh @sshOptions vps "if test -f $remote/deployment.json; then cat $remote/deployment.json; fi")
        if ($LASTEXITCODE -eq 0 -and $lines.Count -gt 0) {
            $report = ($lines -join "`n") | ConvertFrom-Json
            break
        }
        if ($attempt % 6 -eq 1) { "DEPLOIEMENT_EN_COURS=$unit" }
        Start-Sleep -Seconds 5
    }
    if ($null -eq $report) { throw "Recu absent. Verifier $unit et $remote/deployment.json." }
    $report | ConvertTo-Json -Depth 8
    $expectedImage = 'sha256:c39192c6670c08b4a1c1552061b95fb0290d974e01e0e5cef248c6689a72866d'
    if ($report.status -notin @('INTERFACE_COPY_BACKEND_DEPLOYED', 'INTERFACE_COPY_BACKEND_ALREADY_DEPLOYED') -or
        $report.version -ne '1.0.22' -or $report.image_id -ne $expectedImage -or
        $report.schema -ne '20261031_0033' -or $report.migration_performed -ne $false) {
        throw 'Bascule interrompue : transmettre le compte rendu.'
    }
    $api = 'https://api-enactspace.kerunjombor.net'
    $health = Invoke-RestMethod "$api/health?check=$id" -UseBasicParsing
    $timeline = Invoke-RestMethod "$api/api/recruitment/campaigns/timeline?check=$id" -UseBasicParsing
    $web = Invoke-RestMethod "https://enactspace.kerunjombor.net/version.json?check=$id" -UseBasicParsing
    if ($health.ok -ne $true -or $health.version -ne '1.0.22' -or $timeline.timezone -ne 'Africa/Dakar' -or
        $web.version -ne '1.0.24' -or [string]$web.build_number -ne '27') {
        throw 'Reponses HTTPS inattendues apres la bascule : transmettre le compte rendu.'
    }
    'BACKEND_TEXTES_1_0_22_SCHEMA_0033_HTTPS_OK'
}
finally {
    "DOSSIER_PUBLICATION_WINDOWS=$local"
    "DOSSIER_PUBLICATION_VPS=$remote"
    Stop-Transcript | Out-Null
}
