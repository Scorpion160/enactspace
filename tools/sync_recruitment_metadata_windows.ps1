param([Parameter(Mandatory=$true)][string]$Commit)
$ErrorActionPreference = 'Stop'
$repo = 'C:\Users\DIOP\Documents\EnactSpaceRecovery\enactspace-20260927'
$frontend = Join-Path $repo 'frontend'
$baseline = '9c9a1e88879de576ce5856f65eb69ea1843d8f56'
$temp = Join-Path $env:TEMP ('EnactSpace-RecruitmentMetadata-' + [guid]::NewGuid().ToString('N'))
$backup = Join-Path $env:LOCALAPPDATA ('EnactSpace\CodeRollback\recruitment-metadata-' + [guid]::NewGuid().ToString('N'))
$observed = @{}
$files = @(
    @{ Path = 'frontend/lib/features/recruitment/screens/public/public_application_flow_screen.dart'; Hash = 'b5111afcd0a7407058f7eecfdf0ab1126d092a2de8220f638172bdd70ac1791e'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/models/recruitment_application_metadata.dart'; Hash = 'b44eda202bf63733b20783f04ecabaef13cee955d3923dbd3e21e796c3c1a4f0'; New = $true },
    @{ Path = 'frontend/lib/features/recruitment/services/recruitment_service.dart'; Hash = '918102a6636f22b08aa08ecb1bdffc556df4cb153dfa73d50096a437c1f2cfad'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/screens/internal/application_detail_panel.dart'; Hash = '704900a58eca4191fb5b506a2f4c42c65df6283036b50f363a37e29cd03a6443'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/widgets/internal/recruitment_internal_widgets.dart'; Hash = '135ddb7a424a9a9954bbdfc029b29a3c88223b34fd9d6ce6eb133c623633bb33'; New = $false },
    @{ Path = 'frontend/lib/features/recruitment/screens/recruitment_screen.dart'; Hash = 'e6ed0deec6e551338e5ffd74623fa1f181673f24103ecd0b1930bf65b8f50e49'; New = $false },
    @{ Path = 'frontend/test/recruitment_public_test.dart'; Hash = '1a447e6848895a1538bd833c433291ae33c2d155766c28b191acca2df8a8ac96'; New = $false },
    @{ Path = 'frontend/test/recruitment_submission_contract_test.dart'; Hash = '75391217f73f03150506cad43e357de92dfba13f981ff8d351631a8b89ceb690'; New = $false },
    @{ Path = 'frontend/test/recruitment_application_metadata_test.dart'; Hash = '00cadec643d225665b1908f9cd9abc68f39f8a1d0aafebd0b52f5f2110d5a0bd'; New = $true },
    @{ Path = 'backend/app/schemas/recruitment.py'; Hash = 'b83ad62209b165a9bc10bd8282e85e1d29283181e3f56e3b860ee1d656a04a06'; New = $false },
    @{ Path = 'backend/app/api/routes/recruitment.py'; Hash = '96f8035aa7bae7abd69610c36366ae6d4ee7aed87481caf7718babf1c96493c8'; New = $false },
    @{ Path = 'backend/app/services/recruitment_application_metadata.py'; Hash = '72ea57878d52b69b5dd7c131df35c7d534322515171d90063bbd9c4d6fd25066'; New = $true },
    @{ Path = 'backend/tests/test_recruitment_application_metadata.py'; Hash = 'df71c6ba0963d9c2f97d570a0381b81fbbfcac7f24762af4fbc58f20689d6d4f'; New = $true }
)
function Canonical($path) {
    [IO.File]::ReadAllText($path).Replace("`r`n", "`n").TrimEnd()
}
try {
    New-Item -ItemType Directory -Path $temp | Out-Null
    foreach ($item in $files) {
        $candidate = Join-Path $temp ('candidate/' + $item.Path)
        New-Item -ItemType Directory -Path (Split-Path $candidate) -Force | Out-Null
        Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$Commit/$($item.Path)" -OutFile $candidate -UseBasicParsing
        if ((Get-FileHash $candidate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $item.Hash) {
            throw "Integrite incorrecte : $($item.Path)"
        }
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $observed[$item.Path] = (Get-FileHash $local -Algorithm SHA256).Hash
            $comparison = Join-Path $temp ('local/' + $item.Path)
            New-Item -ItemType Directory -Path (Split-Path $comparison) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $comparison
            $variants = @($candidate)
            if (!$item.New) {
                $original = Join-Path $temp ('baseline/' + $item.Path)
                New-Item -ItemType Directory -Path (Split-Path $original) -Force | Out-Null
                Invoke-WebRequest "https://raw.githubusercontent.com/Scorpion160/enactspace/$baseline/$($item.Path)" -OutFile $original -UseBasicParsing
                $variants += $original
            }
            if ($item.Path.EndsWith('.dart')) {
                # Also accept the already-applied removal of the repeated sentence.
                if (!$item.New) {
                    $copyVariant = $original + '.copy.dart'
                    $copy = [IO.File]::ReadAllText($original).Replace(
                        'Parle-nous de toi et de ce qui te donne envie d’agir. Tes réponses restent en place si tu reviens en arrière.',
                        'Parle-nous de toi et de ce qui te donne envie d’agir.'
                    )
                    [IO.File]::WriteAllText($copyVariant, $copy, [Text.UTF8Encoding]::new($false))
                    $variants += $copyVariant
                }
                & dart format $comparison @variants | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'Comparaison du formatage echouee.' }
            }
            $known = $false
            foreach ($variant in $variants) {
                if ((Canonical $comparison) -ceq (Canonical $variant)) { $known = $true }
            }
            if (!$known) { throw "Source locale differente : $($item.Path). Aucun remplacement." }
        } elseif (!$item.New) {
            throw "Source locale absente : $($item.Path)"
        }
    }
    # Validate candidate schemas in an isolated Python process, without touching
    # production files, database, workers, or sending messages.
    $bundle = @{}
    foreach ($relative in @(
        'backend/app/services/recruitment_application_metadata.py',
        'backend/app/schemas/recruitment.py',
        'backend/tests/test_recruitment_application_metadata.py'
    )) {
        $bundle[$relative] = [IO.File]::ReadAllText((Join-Path $temp ('candidate/' + $relative)))
    }
    $bundle['route'] = [IO.File]::ReadAllText((Join-Path $temp 'candidate/backend/app/api/routes/recruitment.py'))
    $data = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($bundle | ConvertTo-Json -Depth 5 -Compress)))
    $probe = @'
import ast, base64, json, sys, types, unittest
bundle = json.loads(base64.b64decode('CANDIDATE_BUNDLE'))
for source in bundle.values():
    ast.parse(source)
for name, path in [
    ('app.services.recruitment_application_metadata', 'backend/app/services/recruitment_application_metadata.py'),
    ('app.schemas.recruitment', 'backend/app/schemas/recruitment.py'),
    ('candidate_metadata_tests', 'backend/tests/test_recruitment_application_metadata.py')
]:
    module = types.ModuleType(name)
    sys.modules[name] = module
    exec(compile(bundle[path], '<candidate>', 'exec'), module.__dict__)
result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromModule(module))
if not result.wasSuccessful():
    sys.exit(1)
print('PROMOTION_ET_CANAUX_BACKEND_TESTS_OK_AUCUNE_MODIFICATION_PRODUCTION')
'@
    $probe = $probe.Replace('CANDIDATE_BUNDLE', $data)
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($probe))
    & ssh vps "printf '%s' '$encoded' | base64 -d | docker exec -i enactspace_backend python -"
    if ($LASTEXITCODE -ne 0) { throw 'Tests backend candidats echoues : aucune source locale remplacee.' }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if ($observed.ContainsKey($item.Path) -and
            (Get-FileHash $local -Algorithm SHA256).Hash -ne $observed[$item.Path]) {
            throw "Source modifiee pendant la preparation : $($item.Path)"
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        if (Test-Path -LiteralPath $local) {
            $saved = Join-Path $backup $item.Path
            New-Item -ItemType Directory -Path (Split-Path $saved) -Force | Out-Null
            Copy-Item -LiteralPath $local -Destination $saved
        }
    }
    foreach ($item in $files) {
        $local = Join-Path $repo $item.Path
        New-Item -ItemType Directory -Path (Split-Path $local) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $temp ('candidate/' + $item.Path)) -Destination $local -Force
    }
    "SAUVEGARDE_CODE=$backup"
    Push-Location $frontend
    try {
        $dartFiles = @($files | Where-Object { $_.Path.EndsWith('.dart') } | ForEach-Object { $_.Path.Substring(9) })
        & dart format @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Formatage echoue.' }
        & flutter analyze @dartFiles
        if ($LASTEXITCODE -ne 0) { throw 'Analyse echouee : transmettre le journal.' }
        & flutter test --reporter expanded test/recruitment_public_test.dart test/recruitment_mobile_text_test.dart test/recruitment_journey_test.dart test/recruitment_application_metadata_test.dart test/recruitment_submission_contract_test.dart test/recruitment_internal_test.dart
        if ($LASTEXITCODE -ne 0) { throw 'Tests echoues : transmettre le journal.' }
        'PROMOTION_ET_CANAUX_SOURCES_INTEGRES_ET_TESTES'
        'BUILD_ET_DEPLOIEMENT_NON_EFFECTUES'
    } finally { Pop-Location }
} finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
