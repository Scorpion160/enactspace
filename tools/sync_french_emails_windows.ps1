param(
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
)
$ErrorActionPreference = 'Stop'
$commit = 'aa1da7f864ded9dd12dcc296a9006e4e9f028f6c'
$python = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
if (!(Test-Path -LiteralPath $python)) { throw 'Python 3.12 introuvable.' }
$manifest = @'
[
  {
    "Path": "backend/test_email_french_copy.py",
    "New": "9db470a73443c028fe769f25ffb2b528a00e15688b2f007ca32a5941511c1d4a"
  },
  {
    "Path": "backend/app/services/mobile_money_service.py",
    "New": "4ad86c9994b1fdaf126b9f2765284de32e1eb850ba3d4cb464f7681007ec43a8",
    "Old": "36cbeffd18f7abc2a4d557751a3a151d6de665fe1d8cabf0aea0479290d945bc"
  },
  {
    "Path": "backend/app/services/email_provider.py",
    "New": "c57fa5b678ce3cf3f13b33014576906da6db0112b8ce9c11495c583dbc184cac",
    "Old": "1322e525e85972f44eb54fb3d0f5325f70f075cb2ddc4f358958a73914dc0b99"
  },
  {
    "Path": "backend/app/services/email_templates.py",
    "New": "74dd43e0296c2e9ebe39e5dc0fbf8f73c9c790853ff5700fbd4f746c5ebbd0b5",
    "Old": "afb10b11cbbd8defc0dc37d0df371cf79d004344dd1c072fe96abe5653429b87"
  },
  {
    "Path": "backend/app/services/first_access.py",
    "New": "f544c11d64f91cc08b1d37c5642170691c969c66764b50c23ad2d1af74fb5864",
    "Old": "1b394832d402660fa496b53b24a29527a2907ed4377e7eeddbf046058e3424fe"
  },
  {
    "Path": "backend/app/api/routes/attendance.py",
    "New": "7837fed66ef728cb1427f12f65a5ef73fed64f3954dce93371590c1cbf3983d0",
    "Old": "b45fc1518d655c84a2a77860db993ecf1b25cb8049d99b40f5d8ab974d3af2eb"
  },
  {
    "Path": "backend/app/api/routes/chat.py",
    "New": "fd6296b4562e99d57a92472c6f3b35621da05a0fcd13bb3f66570c4486720db8",
    "Old": "8f61f3e9ec0b80f68f042853d581472aea705c2b02228fdc7e598e7f417c6a98"
  },
  {
    "Path": "backend/app/api/routes/finance.py",
    "New": "efe132bda5ebe0e2097ab9bb1c2fc76638d7cae92511803a1ede8d8721f374dc",
    "Old": "683bca89d70ca978545e2b810aad526bf8173082315de99b5448718b14b1a066"
  },
  {
    "Path": "backend/app/api/routes/tasks.py",
    "New": "aaaade64fef3dc27e3a0388ebf2377d8a1fbaf4595f73b746c566bfb1900eb2c",
    "Old": "9efa1b1451e4379f4c38baadf6a970e24922829105d4b334423c79265e89ce18"
  },
  {
    "Path": "backend/app/api/routes/posts.py",
    "New": "61846e574e4864aa579c8cf4a71d6fcc04b7df8b0bc3d5111bdcd35bd7c0efca",
    "Old": "8ef94352eebaddedfe3421f533871d37ffc3f362147544a32e641acc43ffbbd8"
  },
  {
    "Path": "backend/app/api/routes/impact.py",
    "New": "39eff90d6457d502da4c5c44b87ed0bf1e3d9dbde232b37827f983a731702d53",
    "Old": "2cc7dcb7bce0590edde49dfd519477b19f1f77ec0da6a5afe5aac5397d2bfec0"
  },
  {
    "Path": "backend/app/api/routes/events.py",
    "New": "889f552403fdc968522fa1e61b4d1fd767759ca07ce0350203dccd94e7ba3d83",
    "Old": "a2f16ddbd0397924c476dab7a3432d066aada04c82061eae780b4b39f38e602f"
  },
  {
    "Path": "backend/app/api/routes/academy.py",
    "New": "5c1b6ddc265c104345c7013ce7d113c905fd55d309756d00dbb2434b5de28a21",
    "Old": "a3882c790dac4960a7b58c9f3129de5f5bb87ef327e37e64ba4e9bc48f93fb67"
  },
  {
    "Path": "backend/app/api/routes/recruitment.py",
    "New": "d2edc614b1df8a1d44af2c165f5a8c8bce06b1f2585d30c8b8891be386b2ad91",
    "Old": "d8d8e67470efe8ce479fc15cd378d292c5d4921fc72ca9097f14e48d9e0a20a6"
  },
  {
    "Path": "backend/app/api/routes/documents.py",
    "New": "29d274677d3ea63ec2c9865211a1409c48337aea4c820d6024872a84d0fc3278",
    "Old": "97d588997e7c8d226bdf00531e7c4887184ef10dc9aa69141ab04211f6922a28"
  }
]
'@ | ConvertFrom-Json

function Get-CanonicalHash([string]$Path) {
    $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes($content)
        ))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

$id = [guid]::NewGuid().ToString('N')
$temp = Join-Path $env:TEMP "EnactSpace-FrenchEmails-$id"
$backup = Join-Path $env:LOCALAPPDATA "EnactSpace\CodeRollback\french-emails-$id"
try {
    foreach ($item in $manifest) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $actual = Get-CanonicalHash $local
            if ($actual -notin @($item.Old, $item.New)) {
                throw "Source locale differente : $($item.Path). Aucun remplacement."
            }
        } elseif ($item.Old) {
            throw "Source absente : $($item.Path). Aucun remplacement."
        }
        $download = Join-Path $temp $item.Path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$commit/$($item.Path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.New) {
            throw "Integrite incorrecte : $($item.Path). Aucun remplacement."
        }
    }

    & $python -m unittest discover -s (Join-Path $temp 'backend') -p test_email_french_copy.py -v
    if ($LASTEXITCODE -ne 0) { throw 'Tests du correctif echoues. Aucun remplacement.' }

    foreach ($item in $manifest) {
        $local = Join-Path $Repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $manifest) {
        Copy-Item -LiteralPath (Join-Path $temp $item.Path) -Destination (Join-Path $Repo $item.Path) -Force
    }
    "SAUVEGARDE_CODE=$backup"
    & $python -m unittest discover -s (Join-Path $Repo 'backend') -p test_email_french_copy.py -v
    if ($LASTEXITCODE -ne 0) { throw 'Correctif integre, mais controle global en echec : transmettre le journal.' }
    'REDACTION_FRANCAISE_EMAILS_ET_NOTIFICATIONS_CORRIGEE'
    'AUCUN_EMAIL_ENVOYE'
    'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
