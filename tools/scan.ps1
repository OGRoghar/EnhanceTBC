param(
  [switch]$Strict
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$failed = $false

function Section([string]$name) {
  Write-Host ""
  Write-Host "== $name =="
}

function Fail([string]$msg) {
  Write-Host "ERROR: $msg" -ForegroundColor Red
  $script:failed = $true
}

function Warn([string]$msg) {
  Write-Host "WARN: $msg" -ForegroundColor Yellow
  if ($Strict) {
    $script:failed = $true
  }
}

Section "TOC Includes"
$tocPath = Join-Path $repoRoot "EnhanceTBC.toc"
if (-not (Test-Path $tocPath)) {
  Fail "EnhanceTBC.toc not found"
} else {
  $missing = @()
  Get-Content $tocPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    if ($line -notmatch "\.(lua|xml)$") { return }
    $fsPath = $line -replace "\\", [IO.Path]::DirectorySeparatorChar
    if (-not (Test-Path $fsPath)) {
      $missing += $line
    }
  }

  if ($missing.Count -gt 0) {
    $missing | ForEach-Object { Fail "Missing TOC include: $_" }
  } else {
    Write-Host "OK: TOC includes resolve."
  }
}

Section "Settings/ApplyBus Key Consistency"
$settingsKeys = @()
Get-ChildItem Settings -Filter *.lua -ErrorAction SilentlyContinue | ForEach-Object {
  Get-Content $_.FullName | ForEach-Object {
    if ($_ -match 'RegisterGroup\("([^"]+)"') {
      $settingsKeys += $matches[1]
    }
  }
}
$settingsKeys = $settingsKeys | Sort-Object -Unique

$applyKeys = @()
Get-ChildItem Core,Modules,Visibility -Filter *.lua -ErrorAction SilentlyContinue | ForEach-Object {
  Get-Content $_.FullName | ForEach-Object {
    if ($_ -match 'ApplyBus:Register\("([^"]+)"') {
      $applyKeys += $matches[1]
    }
  }
}
$applyKeys = $applyKeys | Sort-Object -Unique

$missingApply = $settingsKeys | Where-Object { $_ -notin $applyKeys }
if ($missingApply) {
  $missingApply | ForEach-Object { Fail "Settings key missing ApplyBus register: $_" }
} else {
  Write-Host "OK: every settings group has a module ApplyBus register."
}

Section "Removed Module Regression Check"
$leftovers = @()
$leftoverPatterns = @(
  "PlayerNameplates",
  "Settings_PlayerNameplates",
  "Modules\\PlayerFrame",
  "Settings_PlayerFrame"
)
$codeRoots = @("Core", "Modules", "Settings", "UI", "Options", "Visibility", "EnhanceTBC.toc")
foreach ($root in $codeRoots) {
  if (-not (Test-Path $root)) { continue }
  Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
    $path = $_.FullName
    foreach ($pat in $leftoverPatterns) {
      $match = Select-String -Path $path -Pattern ([Regex]::Escape($pat)) -SimpleMatch -ErrorAction SilentlyContinue
      if ($match) {
        $leftovers += "$($_.FullName):$pat"
      }
    }
  }
}
if ($leftovers.Count -gt 0) {
  $leftovers | ForEach-Object { Warn "Potential leftover reference: $_" }
} else {
  Write-Host "OK: no obvious removed-module leftovers."
}

Section "Luacheck"
$lua51 = $null
$lua51Candidate = Join-Path $env:LOCALAPPDATA "Programs\Lua51\lua.exe"
if (Test-Path $lua51Candidate) {
  $lua51 = @{ Source = $lua51Candidate }
} else {
  $luaCmd = Get-Command lua -ErrorAction SilentlyContinue
  if ($luaCmd) {
    $luaVer = (& $luaCmd.Source -v 2>&1 | Out-String)
    if ($luaVer -match "Lua\s+5\.1") {
      $lua51 = @{ Source = $luaCmd.Source }
    }
  }
}

$luacheckEntry = $null
$entryCandidates = @(
  (Join-Path $env:APPDATA "luarocks\bin\luacheck"),
  (Join-Path $env:APPDATA "luarocks\bin\luacheck.bat"),
  (Join-Path $env:APPDATA "luarocks\bin\luacheck.cmd"),
  (Join-Path $env:APPDATA "luarocks\bin\luacheck.exe")
)
foreach ($candidate in $entryCandidates) {
  if (Test-Path $candidate) {
    $luacheckEntry = $candidate
    break
  }
}

$luacheckMain51 = Join-Path $env:APPDATA "luarocks\share\lua\5.1\luacheck\main.lua"

if (-not $lua51) {
  Warn "Lua 5.1 not found. Luacheck skipped (project is Lua 5.1 only)."
} elseif (-not $luacheckEntry -or -not (Test-Path $luacheckMain51)) {
  Warn "luacheck is not installed for Lua 5.1. Install with Lua51 luarocks and retry."
} else {
  # WoW addons rely on many globals; --no-global keeps signal useful without huge false positives.
  $checkArgs = @("--codes", "--no-global", "Core", "Modules", "Settings", "UI", "Options", "Visibility", "--exclude-files", "Libs/**")

  $rocksLuaPath = (Join-Path $env:APPDATA "luarocks\share\lua\5.1\?.lua") + ";" +
                  (Join-Path $env:APPDATA "luarocks\share\lua\5.1\?\init.lua")
  $rocksCLibPath = (Join-Path $env:APPDATA "luarocks\lib\lua\5.1\?.dll")

  if ($env:LUA_PATH) {
    $env:LUA_PATH = $rocksLuaPath + ";" + $env:LUA_PATH
  } else {
    $env:LUA_PATH = $rocksLuaPath
  }

  if ($env:LUA_CPATH) {
    $env:LUA_CPATH = $rocksCLibPath + ";" + $env:LUA_CPATH
  } else {
    $env:LUA_CPATH = $rocksCLibPath
  }

  $luaVersion = (& $lua51.Source -e "print(_VERSION)" | Out-String).Trim()
  Write-Host ("Using Lua interpreter: " + $lua51.Source)
  Write-Host ("Lua version: " + $luaVersion)
  Write-Host ("Using luacheck entry: " + $luacheckEntry)

  try {
    & $lua51.Source $luacheckEntry @checkArgs
  } catch {
    Warn ("luacheck invocation failed: " + $_.Exception.Message)
  }

  if ($LASTEXITCODE -ne 0) {
    Warn "luacheck reported issues."
  } else {
    Write-Host "OK: luacheck passed."
  }
}

if ($failed) {
  Write-Host ""
  Write-Host "Scan failed." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Scan passed." -ForegroundColor Green
exit 0
