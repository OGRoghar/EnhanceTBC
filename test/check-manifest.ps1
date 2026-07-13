[CmdletBinding()]
param(
    [string] $Path = (Join-Path $PSScriptRoot '..'),
    [string] $Toc = 'EnhanceTBC.toc',
    [switch] $SelfTest
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

function Test-CaseExactPath([string] $Root, [string] $Relative) {
    $current = [IO.Path]::GetFullPath($Root)
    foreach ($part in ($Relative.Replace('\','/') -split '/')) {
        if (-not $part -or $part -eq '.') { continue }
        if ($part -eq '..') { $current = Split-Path -Parent $current; continue }
        $match = Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ceq $part } | Select-Object -First 1
        if (-not $match) { return $false }
        $current = $match.FullName
    }
    return $true
}

function Invoke-ManifestCheck([string] $AddonRoot, [string] $TocName) {
    $root = [IO.Path]::GetFullPath($AddonRoot)
    $errors = [Collections.Generic.List[string]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $loads = [Collections.Generic.List[string]]::new()
    $seen = @{}
    $active = @{}
    $stats = @{ XmlCount = 0 }

    function Visit([string] $Relative, [string] $FromDirectory) {
        $combined = if ($FromDirectory) { Join-Path $FromDirectory $Relative } else { Join-Path $root $Relative }
        $full = [IO.Path]::GetFullPath($combined)
        if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
            $errors.Add("Manifest path escapes addon root: $Relative")
            return
        }
        $rel = [IO.Path]::GetRelativePath($root, $full).Replace('\','/')
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            $errors.Add("Missing reachable manifest path: $rel")
            return
        }
        if (-not (Test-CaseExactPath $root $rel)) {
            $errors.Add("Path casing mismatch: $rel")
        }
        $key = $full.ToLowerInvariant()
        if ($active[$key]) {
            $errors.Add("Manifest include cycle reaches: $rel")
            return
        }
        if ($seen[$key]) {
            $errors.Add("Duplicate reachable load: $rel")
            return
        }
        $seen[$key] = $true
        $loads.Add($rel)
        if ([IO.Path]::GetExtension($full) -ine '.xml') { return }

        $stats.XmlCount++
        $active[$key] = $true
        try {
            [xml]$document = Get-Content -LiteralPath $full -Raw
        } catch {
            $errors.Add("Malformed reachable XML $rel`: $($_.Exception.Message)")
            $active.Remove($key)
            return
        }
        $inline = @($document.SelectNodes('//*[local-name()="Scripts"]/*[not(@file)]'))
        if ($inline.Count) { $warnings.Add("Dynamic inline XML scripts require manual review: $rel") }
        foreach ($node in @($document.SelectNodes('//*[local-name()="Include" or local-name()="Script"][@file]'))) {
            Visit ([string]$node.file) (Split-Path -Parent $full)
        }
        $active.Remove($key)
    }

    $tocPath = Join-Path $root $TocName
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        $errors.Add("Missing TOC: $TocName")
    } else {
        foreach ($line in Get-Content -LiteralPath $tocPath) {
            $entry = $line.Trim()
            if ($entry -and -not $entry.StartsWith('#')) { Visit $entry $root }
        }
    }

    [pscustomobject]@{ Errors = $errors; Warnings = $warnings; Loads = $loads; XmlCount = $stats.XmlCount }
}

if ($SelfTest) {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ("etbc-manifest-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp | Out-Null
    try {
        $cases = @(
            @{ Name='missing'; Toc='missing.xml'; Xml=$null; Expected='Missing reachable' },
            @{ Name='malformed'; Toc='bad.xml'; Xml='<Ui><Script'; Expected='Malformed reachable' },
            @{ Name='cycle'; Toc='a.xml'; Xml='<Ui><Include file="a.xml"/></Ui>'; Expected='cycle' },
            @{ Name='case'; Toc='FILE.lua'; Extra=@{ 'File.lua'='return true' }; Expected='casing mismatch' }
        )
        foreach ($case in $cases) {
            $dir = Join-Path $temp $case.Name
            New-Item -ItemType Directory -Path $dir | Out-Null
            Set-Content -LiteralPath (Join-Path $dir 'Test.toc') -Value $case.Toc
            if ($case.ContainsKey('Xml') -and $case.Xml) { Set-Content -LiteralPath (Join-Path $dir $case.Toc) -Value $case.Xml }
            if ($case.ContainsKey('Extra')) { foreach ($item in $case.Extra.GetEnumerator()) { Set-Content (Join-Path $dir $item.Key) $item.Value } }
            $result = Invoke-ManifestCheck $dir 'Test.toc'
            if (-not (($result.Errors -join "`n") -match $case.Expected)) { throw "Manifest fixture '$($case.Name)' did not fail as expected." }
        }
        $inlineDir = Join-Path $temp 'inline'
        New-Item -ItemType Directory -Path $inlineDir | Out-Null
        Set-Content (Join-Path $inlineDir 'Test.toc') 'inline.xml'
        Set-Content (Join-Path $inlineDir 'inline.xml') '<Ui><Scripts><OnLoad>print("fixture")</OnLoad></Scripts></Ui>'
        $inlineResult = Invoke-ManifestCheck $inlineDir 'Test.toc'
        if ($inlineResult.Errors.Count -or -not (($inlineResult.Warnings -join "`n") -match 'inline XML scripts')) {
            throw 'Inline XML fixture was not classified as a non-blocking warning.'
        }
        Write-Output 'Manifest negative fixtures: 5 passed.'
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force
    }
}

$result = Invoke-ManifestCheck $Path $Toc
$resolvedRoot = (Resolve-Path -LiteralPath $Path).Path
$reachable = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$result.Loads | ForEach-Object { [void]$reachable.Add($_) }

if ($Toc -eq 'EnhanceTBC.toc') {
    foreach ($manifest in @(
        'Manifests/Libraries.xml','Manifests/Locales.xml','Manifests/Core.xml',
        'Manifests/UI.xml','Manifests/Settings.xml','Manifests/Modules.xml',
        'Manifests/Modules/Castbar.xml','Manifests/Modules/UnitNameplates.xml','Manifests/Modules/MinimapPlus.xml'
    )) {
        if (-not $reachable.Contains($manifest)) { $result.Errors.Add("Required manifest is not reachable: $manifest") }
    }

    foreach ($directory in @('Core','Modules','Options','Settings','UI','Visibility','locales')) {
        foreach ($luaFile in Get-ChildItem (Join-Path $resolvedRoot $directory) -Recurse -File -Filter '*.lua') {
            $relativeLua = [IO.Path]::GetRelativePath($resolvedRoot, $luaFile.FullName).Replace('\','/')
            if (-not $reachable.Contains($relativeLua)) { $result.Errors.Add("First-party runtime Lua is unreachable: $relativeLua") }
        }
    }

    foreach ($acePath in @(
        'Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua',
        'Libs/AceConfig-3.0/AceConfigCmd-3.0/AceConfigCmd-3.0.lua',
        'Libs/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua',
        'Libs/AceConfig-3.0/AceConfig-3.0.lua'
    )) {
        $count = @($result.Loads | Where-Object { $_ -ieq $acePath }).Count
        if ($count -ne 1) { $result.Errors.Add("AceConfig runtime path must load exactly once: $acePath (found $count)") }
    }

    foreach ($legacy in @('AceConfigCmd-3.0','AceConfigDialog-3.0','AceConfigRegistry-3.0')) {
        if (Test-Path -LiteralPath (Join-Path $resolvedRoot (Join-Path 'Libs' $legacy))) {
            $result.Errors.Add("Obsolete duplicate AceConfig directory remains: Libs/$legacy")
        }
    }
}
foreach ($xmlFile in Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Filter '*.xml') {
    $relativeXml = [IO.Path]::GetRelativePath($resolvedRoot, $xmlFile.FullName).Replace('\','/')
    if ($reachable.Contains($relativeXml)) { continue }
    try {
        [xml]$unreachableXml = Get-Content -LiteralPath $xmlFile.FullName -Raw
        foreach ($node in @($unreachableXml.SelectNodes('//*[local-name()="Include" or local-name()="Script"][@file]'))) {
            $target = Join-Path $xmlFile.DirectoryName ([string]$node.file)
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                $result.Warnings.Add("Unreachable XML has unresolved reference (informational): $relativeXml -> $($node.file)")
            }
        }
    } catch {
        $result.Warnings.Add("Unreachable malformed XML (informational): $relativeXml")
    }
}
$result.Warnings | Sort-Object -Unique | ForEach-Object { Write-Warning $_ }
if ($result.Errors.Count) {
    $result.Errors | Sort-Object -Unique | ForEach-Object { Write-Output "ERROR: $_" }
    exit 1
}
Write-Output "Manifest graph: $($result.Loads.Count) reachable file(s), $($result.XmlCount) XML manifest(s), 0 error(s)."
