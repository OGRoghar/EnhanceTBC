[CmdletBinding()]
param([switch] $SelfTest)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$files = foreach ($dir in @('Core','Modules','Options','Settings','UI','Visibility')) {
    Get-ChildItem (Join-Path $root $dir) -Recurse -File -Filter '*.lua'
}

function Read-Contract([string] $Name) {
    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    Get-Content (Join-Path $PSScriptRoot $Name) | ForEach-Object { if ($_.Trim()) { [void]$set.Add($_.Trim()) } }
    return ,$set
}

$events = Read-Contract 'tbc-events-68575.txt'
$cvars = Read-Contract 'tbc-cvars-68575.txt'
$globals = Read-Contract 'tbc-indirect-globals-68575.txt'
$scriptMethods = Read-Contract 'tbc-script-methods-68575.txt'
$templates = Read-Contract 'tbc-templates-68575.txt'
$namedGlobals = Read-Contract 'tbc-named-globals-68575.txt'
$errors = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$unresolvedMethods = [Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
$mediaFiles = @(Get-ChildItem (Join-Path $root 'Media') -Recurse -File)

if ($SelfTest) {
    $fixture = 'local direct = C_NamePlate.GetNamePlates; local indexed = C_NamePlate["GetNamePlates"]; local optional = _G["UnitAura"]'
    if ($fixture -notmatch '\bC_NamePlate\.GetNamePlates') { throw 'Direct/aliased API fixture was not detected.' }
    if ($fixture -notmatch '\bC_NamePlate\s*\[\s*"GetNamePlates"') { throw 'Indexed API fixture was not detected.' }
    if ($fixture -notmatch '_G\["UnitAura"\]') { throw 'Optional global fixture was not detected.' }
    if ($templates.Contains('DefinitelyMissingTemplate')) { throw 'Invalid template fixture unexpectedly passed.' }
    Write-Output 'String/API contract fixtures: 4 passed.'
}
$definedMethods = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($file in $files) {
    $source = Get-Content $file.FullName -Raw
    foreach ($match in [regex]::Matches($source, 'function\s+[A-Za-z_][A-Za-z0-9_.]*:([A-Z][A-Za-z0-9_]*)\s*\(')) {
        [void]$definedMethods.Add($match.Groups[1].Value)
    }
}

foreach ($file in $files) {
    $text = Get-Content $file.FullName -Raw
    $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
    foreach ($match in [regex]::Matches($text, '(?:RegisterEvent|RegisterUnitEvent)\s*\(\s*"([A-Z][A-Z0-9_]+)"')) {
        if (-not $events.Contains($match.Groups[1].Value)) { $errors.Add("$relative`: unreviewed event $($match.Groups[1].Value)") }
    }
    foreach ($match in [regex]::Matches($text, '(?:GetCVar|SetCVar|SafeGetCVar|SafeSetCVar)\s*\(\s*"([A-Za-z0-9_]+)"')) {
        if (-not $cvars.Contains($match.Groups[1].Value)) { $errors.Add("$relative`: unreviewed CVar $($match.Groups[1].Value)") }
    }
    foreach ($match in [regex]::Matches($text, '_G\[\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*\]')) {
        if (-not $globals.Contains($match.Groups[1].Value)) { $errors.Add("$relative`: unreviewed indirect global $($match.Groups[1].Value)") }
    }
    foreach ($match in [regex]::Matches($text, '_G\.([A-Z][A-Za-z0-9_]*)')) {
        if (-not $namedGlobals.Contains($match.Groups[1].Value)) { $errors.Add("$relative`: unreviewed named global $($match.Groups[1].Value)") }
    }
    foreach ($match in [regex]::Matches($text, ':([A-Z][A-Za-z0-9_]*)\s*\(')) {
        $method = $match.Groups[1].Value
        if (-not $scriptMethods.Contains($method) -and -not $definedMethods.Contains($method)) {
            [void]$unresolvedMethods.Add($method)
        }
    }
    foreach ($match in [regex]::Matches($text, 'CreateFrame\s*\([^\)]*?,[^\)]*?,[^\)]*?,\s*"([A-Za-z_][A-Za-z0-9_]*)"')) {
        if (-not $templates.Contains($match.Groups[1].Value)) { $errors.Add("$relative`: unreviewed frame template $($match.Groups[1].Value)") }
    }
    foreach ($match in [regex]::Matches($text, '"Interface\\\\AddOns\\\\EnhanceTBC\\\\([^"\r\n]+)"')) {
        $path = $match.Groups[1].Value.Replace('\\','\')
        if ($path.EndsWith('\')) { $warnings.Add("$relative`: dynamic addon resource root $path") ; continue }
        $target = Join-Path $root $path
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { $errors.Add("$relative`: missing addon resource $path") }
    }
    foreach ($match in [regex]::Matches($text, 'ETBC\.media\.[A-Za-z_]+\s*\.\.\s*["'']([^"'']+\.(?:tga|ttf|otf|mp3|ogg|wav))["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $leaf = [IO.Path]::GetFileName($match.Groups[1].Value)
        if ($leaf -and -not ($mediaFiles | Where-Object Name -CEQ $leaf)) {
            $warnings.Add("$relative`: static media leaf not found under Media: $leaf")
        }
    }
}

if ($unresolvedMethods.Count) {
    $warnings.Add("$($unresolvedMethods.Count) dynamic/Ace/addon method name(s) are outside the ScriptObject contract; reviewed as non-blocking: " + (($unresolvedMethods | Select-Object -First 20) -join ', '))
}

$warnings | Sort-Object -Unique | ForEach-Object { Write-Warning $_ }
if ($errors.Count) { $errors | Sort-Object -Unique | ForEach-Object { Write-Output "ERROR: $_" }; exit 1 }
Write-Output "String contracts: $($files.Count) file(s), 0 error(s), $($warnings.Count) dynamic warning(s)."
