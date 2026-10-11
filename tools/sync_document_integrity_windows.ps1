param(
    [string]$Repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927',
    [string]$Commit = '27cb557d65f07f3569071df0d3404b98f0ac0c8f'
)
$ErrorActionPreference = 'Stop'
$python = "$env:LOCALAPPDATA\Programs\Python\Python312\python.exe"
$temp = Join-Path $env:TEMP ('EnactSpace-Documents-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\documents-' + [guid]::NewGuid().ToString('N'))
$manifest = @'
[
  {
    "path": "backend/app/api/routes/documents.py",
    "old": "29d274677d3ea63ec2c9865211a1409c48337aea4c820d6024872a84d0fc3278",
    "new": "f83102544c2971682b5c9d37fb4d382e9480d928f613b7b766f50e3a20cd4789"
  },
  {
    "path": "backend/app/services/institutional_pdf_service.py",
    "old": "bca28037a2a3cc82db7cdd870bab90c86d74e6abce9afe09d4f126da593f3d4a",
    "new": "79b1a2da646e7a3fda2d3f1495a2f7902ee77dc4246917fd944244e943e0b70a"
  },
  {
    "path": "backend/app/services/institutional_document_service.py",
    "old": "edaa811f00663272be0e4a9c0f81fa51129c7d103ea6b8ccb30f4cce8598e3ab",
    "new": "cd6bbb97e3d670ecfb85750ebd99adc432372f5f3e0630775ad2210e67aa6895"
  },
  {
    "path": "backend/app/api/routes/institutional_document_generation.py",
    "old": "afc9aff040d1e4af31f0d8259b32709336457990fdd5dd14f37d6f1991863bf8",
    "new": "a1343adc796c4cc865f3da7135c308e79e5edd73038aa9961c2fba5aa7e2418e"
  },
  {
    "path": "frontend/lib/features/documents/widgets/institutional_request_form.dart",
    "old": "14aadd208dee18300ee5179be789e54ffc09a3247fec18ee91904b98076bfc73",
    "new": "532353c25adb1e871ce8b81c4a4f795f1bd013f28ba707891c729da0096bfebe"
  },
  {
    "path": "frontend/lib/features/documents/screens/institutional_documents_hub_screen.dart",
    "old": "9d4708faa81231035e93de470e0666c6bb4f0f21832fc62a2a4f331e74508914",
    "new": "bddd94781dfd048640c64ea4029a977eac9ef13217e15bab21beae1d1e48cb26"
  },
  {
    "path": "backend/app/api/routes/files.py",
    "old": "502350ef7bd8aa034a735758f571db96cc06c7e9a81242e5184878306a12622a",
    "new": "1e96ad8c2aeaf7c9cf7a82f7af0bb531c526fdb4cb72e9e8a4708780ae735ba9"
  },
  {
    "path": "backend/app/resources/institutional_documents/templates/pv_pole.tex",
    "old": "a0664de2ce21f992c35c521e0731be6a343e0d0d0f393d7bc67947565c4750e6",
    "new": "ea22f3e45ad7318ca9ed5a8dc6366ecacb5ca4218bd32a560b56b178f3e2e609"
  },
  {
    "path": "backend/app/resources/institutional_documents/templates/pv_reunion_generale.tex",
    "old": "7acc3ac927a2cd4a4e61be293f3d3200f37ae903415dff17099b07c9b80ceb9f",
    "new": "bd822434984b8bce8c4a70b7323711a9fbf2acd273ffc5e71ce50c1b02509642"
  },
  {
    "path": "backend/app/api/routes/institutional_documents.py",
    "old": "1d8f268878f90330dbcf819e11e54b5c3b664076aa9d862d072489c6c199a641",
    "new": "9bed74796dcd00f2ff175b98c07b973d642066bea0a7623535100a809b1f83be"
  },
  {
    "path": "backend/test_institutional_document_integrity.py",
    "old": null,
    "new": "221846bddfce0b54f064c6ad1051d3541515c6ddc903e3a08fa8b2a57025cbe7"
  },
  {
    "path": "frontend/test/institutional_draft_edit_test.dart",
    "old": null,
    "new": "75973cf67a38570084d025aa3f8417ee5d1885aa8ba43d1a10e6b32abd35b270"
  },
  {
    "path": "docs/INSTITUTIONAL_DOCUMENTS_INTEGRITY_20261011.md",
    "old": null,
    "new": "6469844404eb6173d12b8e849ef7396b9183542a8c9780dd8fb6f6b7a03e293c"
  }
]
'@ | ConvertFrom-Json

function Get-CanonicalHash([string]$Path) {
    $content = [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

try {
    if (!(Test-Path -LiteralPath $python -PathType Leaf)) { throw 'Python 3.12 introuvable.' }
    foreach ($item in $manifest) {
        $local = Join-Path $Repo $item.path
        if (Test-Path -LiteralPath $local -PathType Leaf) {
            $current = Get-CanonicalHash $local
            if ($current -ne $item.new -and (!$item.old -or $current -ne $item.old)) {
                throw "Source locale differente : $($item.path). Aucun remplacement."
            }
        } elseif ($item.old) {
            throw "Source locale absente : $($item.path). Aucun remplacement."
        }
    }

    foreach ($item in $manifest) {
        $download = Join-Path $temp $item.path
        New-Item -ItemType Directory -Path (Split-Path $download) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.path)" -OutFile $download -UseBasicParsing
        if ((Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.new) {
            throw "Integrite incorrecte : $($item.path). Aucun remplacement."
        }
    }

    $checker = Join-Path $temp 'check_syntax.py'
    $code = @'
import ast, sys
from pathlib import Path
for path in Path(sys.argv[1]).rglob('*.py'):
    ast.parse(path.read_text(encoding='utf-8'), filename=str(path))
print('SYNTAXE_BACKEND_DOCUMENTS_OK')
'@
    [IO.File]::WriteAllText($checker, $code, [Text.UTF8Encoding]::new($false))
    & $python $checker $temp
    if ($LASTEXITCODE -ne 0) { throw 'Syntaxe Python invalide. Aucun remplacement.' }

    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $newFiles = @()
    foreach ($item in $manifest) {
        $local = Join-Path $Repo $item.path
        if (Test-Path -LiteralPath $local -PathType Leaf) {
            $saved = Join-Path $backup $item.path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        } else { $newFiles += $item.path }
    }
    [IO.File]::WriteAllText((Join-Path $backup 'new-files.json'), (ConvertTo-Json -InputObject @($newFiles)), [Text.UTF8Encoding]::new($false))
    foreach ($item in $manifest) {
        $local = Join-Path $Repo $item.path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp $item.path) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    'CORRECTIONS_DOCUMENTS_INTEGREES'

    Push-Location (Join-Path $Repo 'frontend')
    try {
        dart format lib/features/documents/widgets/institutional_request_form.dart lib/features/documents/screens/institutional_documents_hub_screen.dart test/institutional_draft_edit_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue : transmettre le journal.' }
        flutter analyze lib/features/documents/widgets/institutional_request_form.dart lib/features/documents/screens/institutional_documents_hub_screen.dart test/institutional_draft_edit_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : sources integrees et sauvegardees, transmettre le journal.' }
        flutter test --reporter expanded test/institutional_documents_test.dart test/institutional_documents_service_test.dart test/institutional_draft_edit_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : sources integrees et sauvegardees, transmettre le journal.' }
        'BROUILLONS_ET_DOCUMENTS_TESTS_FLUTTER_OK'
        'AUCUN_EMAIL_ENVOYE'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
