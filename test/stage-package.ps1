[CmdletBinding()]
param([Parameter(Mandatory)][string] $Destination)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$destinationPath = [IO.Path]::GetFullPath($Destination)
if ($destinationPath -eq [IO.Path]::GetPathRoot($destinationPath) -or $destinationPath -eq $root) {
    throw "Unsafe package staging destination: $destinationPath"
}
if (Test-Path -LiteralPath $destinationPath) { Remove-Item -LiteralPath $destinationPath -Recurse -Force }
New-Item -ItemType Directory -Path $destinationPath | Out-Null

$runtime = @('Core','Libs','locales','Media','Modules','Options','Settings','UI','Visibility')
foreach ($directory in $runtime) {
    $source = Join-Path $root $directory
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination $destinationPath -Recurse }
}
foreach ($file in @('EnhanceTBC.toc','LICENSE','README.md','CHANGELOG.md','TESTING.md','.pkgmeta')) {
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $destinationPath
}
$packageParent = Split-Path -Parent $destinationPath
foreach ($child in @('EnhanceTBC_HUD','EnhanceTBC_Inventory','EnhanceTBC_Combat')) {
    $source = Join-Path $root (Join-Path 'Children' $child)
    $target = Join-Path $packageParent $child
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
    Copy-Item -LiteralPath $source -Destination $target -Recurse
}
Write-Output "Staged package: $destinationPath"
