[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [ValidatePattern('^[a-f0-9]{40}$')] [string]$Commit,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^/opt/enactspace/operations/publish-recruitment-[a-f0-9]{32}$')]
    [string]$Operation
)
$ErrorActionPreference = 'Stop'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:TEMP "enactspace-configuration-$id.py"
$remote = "$Operation/configuration-diagnostic-$id.py"
$expected = '78eac39414e01d90609592d06bd8896c7a90bad398f6a6eaf5532ab6c08841b9'
Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/tools/diagnose_recruitment_configuration.py" `
    -OutFile $local -UseBasicParsing
if ((Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Integrite incorrecte : diagnostic non execute.'
}
& scp $local "vps:$remote"
if ($LASTEXITCODE -ne 0) { throw 'Transfert du diagnostic echoue.' }
$checksum = @(& ssh -T -o ConnectTimeout=15 vps "sha256sum $remote")
if ($LASTEXITCODE -ne 0 -or $checksum.Count -ne 1 -or
    (([string]$checksum[0] -split '\s+')[0] -ne $expected)) {
    throw 'Integrite distante incorrecte : diagnostic non execute.'
}
& ssh -T -o ConnectTimeout=15 -o ServerAliveInterval=15 vps "python3 $remote --operation $Operation"
if ($LASTEXITCODE -ne 0) { throw 'Diagnostic bloque : transmettre le compte rendu masque.' }
'DIAGNOSTIC_SEUL_SANS_CHANGEMENT_DE_CONFIGURATION_NI_DEPLOIEMENT'
