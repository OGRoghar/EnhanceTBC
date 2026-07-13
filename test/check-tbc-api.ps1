[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$contract = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
Get-Content (Join-Path $PSScriptRoot 'tbc-api-68575.txt') | ForEach-Object {
    $symbol = $_.Trim()
    if ($symbol) { [void]$contract.Add($symbol) }
}

$findings = [Collections.Generic.List[string]]::new()
$directories = @('Core','Modules','Options','Settings','UI','Visibility')
$files = foreach ($directory in $directories) {
    Get-ChildItem (Join-Path $root $directory) -Recurse -File -Filter '*.lua'
}
foreach ($file in $files) {
    $text = Get-Content $file.FullName -Raw
    foreach ($match in [regex]::Matches($text, '\b(C_[A-Za-z0-9_]+\.[A-Za-z_][A-Za-z0-9_]*)')) {
        $symbol = $match.Groups[1].Value
        if (-not $contract.Contains($symbol)) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
            $line = ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count + 1
            $findings.Add("${relative}:${line}: API symbol not reviewed for TBC build 68575: $symbol")
        }
    }
    foreach ($match in [regex]::Matches($text, '\b(C_[A-Za-z0-9_]+)\s*\[\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']\s*\]')) {
        $symbol = "$($match.Groups[1].Value).$($match.Groups[2].Value)"
        if (-not $contract.Contains($symbol)) {
            $relative = [IO.Path]::GetRelativePath($root, $file.FullName).Replace('\','/')
            $line = ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count + 1
            $findings.Add("${relative}:${line}: indexed API symbol not reviewed for TBC build 68575: $symbol")
        }
    }
}

if ($findings.Count) {
    $findings | Sort-Object -Unique | Write-Output
    exit 1
}
Write-Output "TBC build-68575 API contract: scanned $($files.Count) first-party file(s); 0 finding(s)."
