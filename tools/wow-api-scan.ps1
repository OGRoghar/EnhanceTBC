param(
  [switch]$Strict
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$scanRoots = @("Core", "Modules", "Settings", "UI", "Options", "Visibility")
$files = @()
foreach ($root in $scanRoots) {
  if (Test-Path $root) {
    $files += Get-ChildItem $root -Recurse -Filter *.lua -File -ErrorAction SilentlyContinue
  }
}

$rules = @(
  @{
    Id = "WAPI001"
    Severity = "warn"
    Title = "UnitAffectingCombat without explicit bool normalization"
    Description = "Project convention for 20505 is explicit bool normalization when storing combat state (prefer 'not not UnitAffectingCombat(...)' or '... and true or false')."
    Pattern = '=\s*.*UnitAffectingCombat\('
    IgnorePattern = 'not\s+not\s+UnitAffectingCombat\(|UnitAffectingCombat\(.*\)\s*and\s*true\s*or\s*false'
  },
  @{
    Id = "WAPI002"
    Severity = "warn"
    Title = "Direct legacy container API call"
    Description = "For cross-client safety, prefer local compatibility wrappers that use C_Container first and fallback to GetContainer* APIs."
    Pattern = '(?<![A-Za-z0-9_\.])(GetContainerNumSlots|GetContainerItemLink|GetContainerItemInfo|GetContainerNumFreeSlots|GetContainerItemCooldown|PickupContainerItem|UseContainerItem)\('
    IgnorePattern = 'local\s+function\s+(GetBag|UseBag)|function\s+(GetBag|UseBag)|C_Container|C\.GetContainer'
  },
  @{
    Id = "WAPI003"
    Severity = "info"
    Title = "SetCVar without safety wrapper"
    Description = "Prefer pcall(SetCVar, ...) or a SafeSetCVar helper in addon logic to reduce runtime hard-fail risk."
    Pattern = '(?<!pcall\()\bSetCVar\('
    IgnorePattern = 'function\s+SafeSetCVar|local\s+function\s+SafeSetCVar'
  },
  @{
    Id = "WAPI004"
    Severity = "warn"
    Title = "GetInboxHeaderInfo unpack missing sender guard"
    Description = "Mailbox parsing should validate sender nil-safety before using unpacked fields."
    Pattern = '\bGetInboxHeaderInfo\('
    IgnorePattern = 'if\s+not\s+sender\s+then'
  },
  @{
    Id = "WAPI005"
    Severity = "info"
    Title = "Direct IsInInstance usage in broad logic"
    Description = "Prefer centralized wrapper/normalizer for inInstance + instanceType handling in visibility/state systems."
    Pattern = '\bIsInInstance\('
    IgnorePattern = 'local\\s+function\\s+(InInstance|InLegacyInstance|GetInstanceType)|pcall\\(IsInInstance\\)|=\\s*IsInInstance\\(\\)'
  }
)

$ruleExemptions = @{
  WAPI002 = @(
    "Modules/Vendor.lua",
    "Modules/MinimapPlus.lua"
  )
  WAPI004 = @(
    "Modules/Mailbox.lua"
  )
  WAPI005 = @(
    "Modules/Unit_NamePlates.lua",
    "Modules/Visibility.lua"
  )
}

$results = New-Object System.Collections.Generic.List[object]

function Add-Finding {
  param(
    [string]$File,
    [int]$Line,
    [string]$RuleId,
    [string]$Severity,
    [string]$Title,
    [string]$Description,
    [string]$Code
  )

  $results.Add([PSCustomObject]@{
    file = $File
    line = $Line
    rule = $RuleId
    severity = $Severity
    title = $Title
    description = $Description
    code = $Code.Trim()
  })
}

foreach ($file in $files) {
  $relative = Resolve-Path -Relative $file.FullName
  $normalized = ($relative -replace '^[.][\\/]+', '') -replace '\\', '/'
  $lines = Get-Content $file.FullName

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.TrimStart().StartsWith("--")) { continue }

    foreach ($rule in $rules) {
      if ($ruleExemptions.ContainsKey($rule.Id)) {
        if ($ruleExemptions[$rule.Id] -contains $normalized) {
          continue
        }
      }

      if ($line -imatch $rule.Pattern) {
        if ($rule.IgnorePattern -and ($line -imatch $rule.IgnorePattern)) {
          continue
        }
        Add-Finding -File $relative -Line ($i + 1) -RuleId $rule.Id -Severity $rule.Severity -Title $rule.Title -Description $rule.Description -Code $line
      }
    }
  }
}

Write-Host ""
Write-Host "== WoW API Scanner (20505-focused) =="
Write-Host ("Scanned {0} Lua files" -f $files.Count)

if ($results.Count -eq 0) {
  Write-Host "No findings."
  exit 0
}

$bySeverity = $results | Group-Object severity | Sort-Object Name
foreach ($group in $bySeverity) {
  Write-Host ("{0}: {1}" -f $group.Name.ToUpper(), $group.Count)
}

Write-Host ""
Write-Host "Top findings:"
$results |
  Sort-Object severity, file, line |
  Select-Object -First 200 |
  ForEach-Object {
    Write-Host ("[{0}] {1}:{2} {3}" -f $_.rule, $_.file, $_.line, $_.title)
    Write-Host ("  -> {0}" -f $_.description)
    Write-Host ("  -> {0}" -f $_.code)
  }

$warnCount = ($results | Where-Object { $_.severity -eq "warn" }).Count
if ($Strict -and $warnCount -gt 0) {
  Write-Host ""
  Write-Host "Scanner failed in strict mode (warn findings present)." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Scanner completed." -ForegroundColor Green
exit 0
