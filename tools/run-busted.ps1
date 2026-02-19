param(
  [switch]$Coverage
)

$ErrorActionPreference = 'Stop'

$env:LUA_PATH = (luarocks path --lr-path)
$env:LUA_CPATH = (luarocks path --lr-cpath)
$env:PATH = ((Join-Path $env:APPDATA 'luarocks\bin') + ';' + $env:PATH)

$bustedPath = Join-Path $env:APPDATA 'luarocks\bin\busted'
$args = @('--verbose')
if ($Coverage) {
  $args += '--coverage'
}

& lua $bustedPath @args
exit $LASTEXITCODE
