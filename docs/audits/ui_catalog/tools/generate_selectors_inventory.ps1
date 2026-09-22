param(
    [string]$FrontendRoot = (Join-Path $PSScriptRoot "..\..\..\..\frontend\lib")
)

$ErrorActionPreference = "Stop"
$FrontendRoot = (Resolve-Path -LiteralPath $FrontendRoot).Path
$output = Join-Path $PSScriptRoot "..\selectors_inventory.csv"
$rows = [System.Collections.Generic.List[object]]::new()

function Get-Domain([string]$Relative) {
    $parts = $Relative.Split("/")
    if ($parts.Length -gt 2 -and $parts[0] -eq "features") { return $parts[1] }
    if ($parts.Length -gt 1) { return $parts[0] }
    return "shared"
}

function Get-SelectorType([string]$Context) {
    $value = $Context.ToLowerInvariant()
    if ($value -match "role") { return "role_picker" }
    if ($value -match "pole") { return "pole_picker" }
    if ($value -match "project") { return "project_picker" }
    if ($value -match "member|user|participant|assignee") { return "member_picker" }
    if ($value -match "status|state") { return "status_picker" }
    if ($value -match "sort|order") { return "sort_picker" }
    if ($value -match "filter|filtre") { return "filter_picker" }
    return "dropdown"
}

$lexicalOccurrences = 0
$candidateId = 0
$constructorPattern = "(?m)\b(DropdownButton(?:FormField)?|DropdownMenu)\s*(?:<[^>]+>)?\s*\("
$lexicalPattern = "\b(?:DropdownButton(?:FormField)?|DropdownMenu)\b"

Get-ChildItem -LiteralPath $FrontendRoot -Filter "*.dart" -Recurse |
    Sort-Object FullName |
    ForEach-Object {
        $file = $_
        $text = Get-Content -LiteralPath $file.FullName -Raw
        $lines = Get-Content -LiteralPath $file.FullName
        $lexicalOccurrences += ([regex]::Matches($text, $lexicalPattern)).Count
        $relative = $file.FullName.Substring($FrontendRoot.Length).TrimStart([char[]]"\\/").Replace("\", "/")
        $className = "top_level"
        $methodName = "build_or_callback"
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex += 1) {
            $sourceLine = $lines[$lineIndex]
            $classMatch = [regex]::Match($sourceLine, "^\s*class\s+([A-Za-z0-9_]+)")
            if ($classMatch.Success) { $className = $classMatch.Groups[1].Value }
            $methodMatch = [regex]::Match($sourceLine, "^\s*(?:[A-Za-z0-9_<>?, ]+\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*(?:async\s*)?\{")
            if ($methodMatch.Success) { $methodName = $methodMatch.Groups[1].Value }
            $matches = [regex]::Matches($sourceLine, $constructorPattern)
            foreach ($match in $matches) {
                $candidateId += 1
                $contextStart = [Math]::Max(0, $lineIndex - 12)
                $contextEnd = [Math]::Min($lines.Count - 1, $lineIndex + 12)
                $context = ($lines[$contextStart..$contextEnd] -join "`n")
            $controlled = "not_detected"
            $valueMatch = [regex]::Match($context, "value\s*:\s*([A-Za-z_][A-Za-z0-9_.]*)")
            if ($valueMatch.Success) { $controlled = $valueMatch.Groups[1].Value }
            $options = "dynamic"
            $itemsMatch = [regex]::Match($context, "items\s*:\s*([A-Za-z_][A-Za-z0-9_.]*)")
            if ($itemsMatch.Success) { $options = $itemsMatch.Groups[1].Value }
            $permission = if ($context -match "can[A-Z]|role|permission|isAdmin|isFinance|isSecretary") { "possible_guard_review" } else { "not_detected_static" }

            $rows.Add([pscustomobject]@{
                selector_id = ("SEL{0:D3}" -f $candidateId)
                domaine = Get-Domain $relative
                fichier = ("frontend/lib/" + $relative)
                classe = $className
                methode = $methodName
                ligne = ($lineIndex + 1)
                widget = $match.Groups[1].Value
                variable_controlee = $controlled
                type = Get-SelectorType $context
                options_source = $options
                permission_dependency = $permission
                mobile = "runtime_required"
                desktop = "runtime_required"
                validation = "probable_instance_static"
                capture_dediee = "pending_runtime_dedup"
                lexical_occurrences_total = 0
                probable_instances_total = 0
                validated_instances_total = 0
                duplicates_grouped_total = 0
                commentaire = "DropdownMenuItem and DropdownMenuEntry are excluded from instance candidates."
            })
            }
        }
    }

$groupedDuplicates = ($rows | Group-Object fichier, classe, methode, variable_controlee, widget | Where-Object Count -gt 1 | Measure-Object).Count
foreach ($row in $rows) {
    $row.lexical_occurrences_total = $lexicalOccurrences
    $row.probable_instances_total = $candidateId
    $row.validated_instances_total = 0
    $row.duplicates_grouped_total = $groupedDuplicates
}

$rows | Export-Csv -LiteralPath $output -NoTypeInformation -Encoding utf8
Write-Output "lexical_occurrences=$lexicalOccurrences probable_instances=$candidateId validated_instances=0 duplicates_grouped=$groupedDuplicates"
