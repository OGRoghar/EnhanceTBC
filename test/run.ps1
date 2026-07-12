[CmdletBinding()]
param([string] $Lua)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script = Join-Path $PSScriptRoot 'run.lua'

if ($Lua) {
    & $Lua $script $root
    exit $LASTEXITCODE
}

foreach ($name in @('lua5.1', 'lua51', 'lua')) {
    $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        $version = (& $command.Source -v 2>&1 | Out-String)
        if ($version -match 'Lua 5\.1') {
            & $command.Source $script $root
            exit $LASTEXITCODE
        }
    }
}

$devRuntime = Join-Path $root '..\Documents\Tools\Lua51'
$bridge = Join-Path $devRuntime 'Luac51.cs'
if (Test-Path -LiteralPath $bridge) {
    Add-Type -Path $bridge
    $env:ETBC_TEST_ROOT = $root
    $exitCode = [Luac51]::Run($script)
    if ([Luac51]::LastMessage) { Write-Error ([Luac51]::LastMessage) -ErrorAction Continue }
    exit $exitCode
}

throw 'Lua 5.1 runtime not found. Install lua5.1 or pass -Lua <path>.'
