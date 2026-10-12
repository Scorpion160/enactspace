param([Parameter(Mandatory=$true)][string]$Commit, [switch]$Execute)
$ErrorActionPreference = 'Stop'
$id = [guid]::NewGuid().ToString('N')
$local = Join-Path $env:LOCALAPPDATA "EnactSpace\BackendPackages\chat-$id"
$remote = "/opt/enactspace/operations/chat-release-$id"
New-Item -ItemType Directory -Path $local | Out-Null
$files = @(
    @{ Name = 'chat.py'; Path = 'backend/app/api/routes/chat.py'; Hash = '90b2ba0e16acded9cb2d8e48ee605e16e7713ae577a18712cde988af297ee6e1' }
    @{ Name = 'email_delivery_service.py'; Path = 'backend/app/services/email_delivery_service.py'; Hash = '77332b5a582909b58d1c571124f0d03b67907055b4d52dd357423cff4931057a' }
    @{ Name = 'test_chat_thread_notifications.py'; Path = 'backend/tests/test_chat_thread_notifications.py'; Hash = '422ae514033502605c306fa0a56b5adab2f2cfd6f6f5f87e962719810eb4d538' }
    @{ Name = 'test_chat_email_privacy.py'; Path = 'backend/tests/test_chat_email_privacy.py'; Hash = '3c92afd8e39294c86699748de2e18c634b00d1e4aa901947324b0df80f96e045' }
    @{ Name = 'test_chat_shared_content.py'; Path = 'backend/tests/test_chat_shared_content.py'; Hash = '289ff855a4f57c0f65537af3606d471154e6292e3c41725a561be5fc4f456ba6' }
    @{ Name = 'deploy_chat_backend.py'; Path = 'tools/deploy_chat_backend.py'; Hash = '4ef894ac59d0296f8e878646080fe3bf6fc88b2f2726dc8a398807ab98197447' }
)
$manifest = @{}
foreach ($item in $files) {
    $file = Join-Path $local $item.Name
    Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $file -UseBasicParsing
    if ((Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) { throw "Integrite incorrecte : $($item.Name)" }
    $manifest[$item.Name] = $item.Hash
}
[IO.File]::WriteAllText((Join-Path $local 'manifest.json'), ($manifest | ConvertTo-Json), [Text.UTF8Encoding]::new($false))
& ssh vps "install -d -m 700 $remote"
if ($LASTEXITCODE -ne 0) { throw 'Preparation VPS echouee.' }
foreach ($name in @($files.Name) + @('manifest.json')) {
    & scp (Join-Path $local $name) "vps:$remote/"
    if ($LASTEXITCODE -ne 0) { throw "Transfert echoue : $name" }
}
$expected = $manifest['deploy_chat_backend.py']
$result = & ssh vps "sha256sum $remote/deploy_chat_backend.py"
if ($LASTEXITCODE -ne 0 -or (([string]$result -split '\s+')[0]) -ne $expected) { throw 'Integrite du programme VPS incorrecte.' }
$executeArg = if ($Execute) { '--execute' } else { '' }
& ssh vps "python3 $remote/deploy_chat_backend.py --directory $remote --commit $Commit $executeArg"
if ($LASTEXITCODE -ne 0) { throw 'Operation bloquee : transmettre le compte rendu masque.' }
$health = Invoke-RestMethod 'https://api-enactspace.kerunjombor.net/health'
if ($health.ok -ne $true -or $health.version -ne '1.0.15') { throw 'Verification publique API echouee.' }
'API_PUBLIQUE_OK'
