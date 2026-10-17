param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$id = [guid]::NewGuid().ToString('N')
$temp = Join-Path $env:TEMP "EnactSpace-PayDunya-Headers-$id"
$remote = "/opt/enactspace/staging/paydunya-headers-$id"
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\paydunya-headers-$id"
$checks = @{
    'backend/app/services/payments/paydunya_provider.py' = 'de3b23a4e5cc67f82dc40085247dfdabfe2a00da5110268746fcbe444b0efa29'
    'backend/test_prelaunch_payment_transport.py' = 'cfda10dfe5679e4f03d1fb8cceea1c4b335abcefc0a777308b057982814094e2'
    'tools/verify_paydunya_sandbox.py' = 'd21dd3d62f162459bc1474093a60d3997a475da4bcb22047e63eee792ca39f44'
}
$previous = @{
    'backend/app/services/payments/paydunya_provider.py' = '940665cb00897911410e7cb0bd6113b99cc7b9a1d59ff7b0e8fab4bb8a0fe9d7'
    'backend/test_prelaunch_payment_transport.py' = '6fc82e33fe63d4719f39712230156c07dc7f04cd788fb6fc02a14af4c57312c1'
}
try {
    foreach ($relative in $checks.Keys) {
        $file = Join-Path $temp $relative
        New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$relative" -OutFile $file -UseBasicParsing
        if ((Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $checks[$relative]) {
            throw "Integrite incorrecte : $relative"
        }
    }
    foreach ($relative in $previous.Keys) {
        $actual = (Get-FileHash (Join-Path $repo $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $previous[$relative] -and $actual -ne $checks[$relative]) {
            throw "Source locale differente : $relative. Aucun remplacement."
        }
    }
    ssh vps "install -d -m 700 $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Preparation VPS echouee.' }
    foreach ($relative in $checks.Keys) {
        scp (Join-Path $temp $relative) "vps:$remote/"
        if ($LASTEXITCODE -ne 0) { throw "Transfert echoue : $relative" }
    }
    $manifest = @{}
    foreach ($relative in $previous.Keys) {
        $manifest[(Split-Path $relative -Leaf)] = $checks[$relative]
    }
    $manifestFile = Join-Path $temp 'manifest.json'
    [IO.File]::WriteAllText($manifestFile, ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
    scp $manifestFile "vps:$remote/manifest.json"
    if ($LASTEXITCODE -ne 0) { throw 'Transfert manifeste echoue.' }
    $remoteHash = ssh vps "sha256sum $remote/verify_paydunya_sandbox.py"
    if ($LASTEXITCODE -ne 0 -or ([string]$remoteHash -split '\s+')[0] -ne $checks['tools/verify_paydunya_sandbox.py']) {
        throw 'Integrite outil VPS incorrecte.'
    }
    ssh vps "python3 $remote/verify_paydunya_sandbox.py $remote"
    if ($LASTEXITCODE -ne 0) { throw 'Verification bloquee : sources locales non remplacees.' }
    foreach ($relative in $previous.Keys) {
        $saved = Join-Path $backup $relative
        New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $repo $relative) -Destination $saved
    }
    foreach ($relative in $previous.Keys) {
        Copy-Item -LiteralPath (Join-Path $temp $relative) -Destination (Join-Path $repo $relative) -Force
    }
    "SAUVEGARDE_CODE=$backup"
    'PAYDUNYA_ENTETES_ET_REJEU_COMPTABLE_VALIDES'
    'RECEPTION_AUTOMATIQUE_IPN_NON_ENCORE_VERIFIEE'
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    'PAIEMENTS_PRODUCTION_NON_ACTIVES'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
