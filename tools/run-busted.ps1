param(
  [switch]$Coverage
)

$ErrorActionPreference = 'Stop'

$luaExe = 'C:\Users\Roghar\AppData\Local\Programs\Lua51\lua.exe'
if (-not (Test-Path $luaExe)) {
  throw "Lua 5.1 not found at: $luaExe"
}

$luaVersion = & $luaExe -e "print(_VERSION)"
if ($luaVersion -notmatch 'Lua 5\.1') {
  throw "Expected Lua 5.1, got: $luaVersion"
}

$rocksShare = Join-Path $env:APPDATA 'luarocks\share\lua\5.1'
$rocksLib = Join-Path $env:APPDATA 'luarocks\lib\lua\5.1'

if (-not (Test-Path $rocksShare)) {
  throw "LuaRocks 5.1 share path not found: $rocksShare"
}

$env:LUA_PATH = ".\?.lua;.\?\init.lua;$rocksShare\?.lua;$rocksShare\?\init.lua;"
$env:LUA_CPATH = "$rocksLib\?.dll;"
$env:PATH = ((Join-Path $env:APPDATA 'luarocks\bin') + ';' + $env:PATH)

$runnerPath = Join-Path $env:TEMP 'etbc_busted_runner.lua'
$coverageFlag = if ($Coverage) { 'true' } else { 'false' }
$runner = @"
package.path = os.getenv('LUA_PATH') .. ';' .. package.path
package.cpath = os.getenv('LUA_CPATH') .. ';' .. package.cpath

local okLoader, loader = pcall(require, 'luarocks.loader')
if okLoader and loader and loader.add_context then
  pcall(loader.add_context, 'busted', '1.11.1-2')
end

local busted = require('busted')
local opts = {
  path = '.',
  cwd = '.',
  root_file = 'spec',
  pattern = busted.defaultpattern or '_spec',
  verbose = true,
  suppress_pending = false,
  defer_print = false,
  sound = false,
  tags = {},
  excluded_tags = {},
  output = busted.defaultoutput or 'plain_terminal',
  lang = 'en',
  filelist = nil,
  coverage = $coverageFlag,
}

local status, failures = busted(opts)
print((status or '') .. '\n')
os.exit(tonumber(failures) or 1)
"@

Set-Content -Path $runnerPath -Value $runner -Encoding ASCII

& $luaExe $runnerPath
exit $LASTEXITCODE
