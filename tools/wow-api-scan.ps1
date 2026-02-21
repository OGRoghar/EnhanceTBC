param(
  [switch]$Strict,
  [string]$ApiRoot = "tools/2.5.5.65895",
  [int]$MaxFindings = 200
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$scanRoots = @("Core", "Modules", "Settings", "UI", "Options", "Visibility")

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

function Normalize-RelativePath {
  param([string]$FullPath)

  $relative = Resolve-Path -Relative $FullPath
  return (($relative -replace '^[.][\\/]+', '') -replace '\\', '/')
}

function Get-ApiIndex {
  param([string]$ApiBasePath)

  $generatedPath = Join-Path $ApiBasePath "Blizzard_APIDocumentationGenerated"
  if (-not (Test-Path $generatedPath)) {
    throw "API docs not found: $generatedPath"
  }

  $namespaces = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $namespacedFunctions = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $globalFunctions = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

  # API docs are emitted as local table literals ending with "};".
  $blockRegex = New-Object System.Text.RegularExpressions.Regex(
    'local\s+[A-Za-z_][A-Za-z0-9_]*\s*=\s*\{(.*?)\};',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  $functionRegex = New-Object System.Text.RegularExpressions.Regex(
    '\{\s*Name\s*=\s*"([A-Za-z_][A-Za-z0-9_]*)"\s*,\s*Type\s*=\s*"Function"',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )

  Get-ChildItem $generatedPath -File -Filter *.lua | ForEach-Object {
    $content = Get-Content $_.FullName -Raw

    $blocks = $blockRegex.Matches($content)
    foreach ($block in $blocks) {
      $blockText = $block.Groups[1].Value

      $namespace = ""
      $namespaceMatch = [regex]::Match($blockText, 'Namespace\s*=\s*"([^"]*)"')
      if ($namespaceMatch.Success) {
        $namespace = $namespaceMatch.Groups[1].Value
      }

      if ($namespace) {
        [void]$namespaces.Add($namespace)
      }

      $matches = $functionRegex.Matches($blockText)
      foreach ($m in $matches) {
        $fn = $m.Groups[1].Value
        if ($namespace) {
          [void]$namespacedFunctions.Add("$namespace.$fn")
        } else {
          [void]$globalFunctions.Add($fn)
        }
      }
    }
  }

  # Generated docs are incomplete for some namespaced APIs in this client build.
  # Merge observed C_* calls from the full API dump to reduce false positives.
  $observedCallRegex = New-Object System.Text.RegularExpressions.Regex(
    '\b(C_[A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*\('
  )

  Get-ChildItem $ApiBasePath -Recurse -File -Filter *.lua | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $matches = $observedCallRegex.Matches($content)
    foreach ($m in $matches) {
      $namespace = $m.Groups[1].Value
      $fn = $m.Groups[2].Value
      [void]$namespaces.Add($namespace)
      [void]$namespacedFunctions.Add("$namespace.$fn")
    }
  }

  return [PSCustomObject]@{
    Namespaces = $namespaces
    NamespacedFunctions = $namespacedFunctions
    GlobalFunctions = $globalFunctions
  }
}

function Get-DeprecatedMap {
  param([string]$ApiBasePath)

  $map = @{}
  $depFiles = Get-ChildItem $ApiBasePath -Recurse -File -Filter *.lua | Where-Object {
    $_.DirectoryName -match 'Blizzard_Deprecated'
  }

  foreach ($file in $depFiles) {
    $lines = Get-Content $file.FullName

    foreach ($line in $lines) {
      if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(C_[A-Za-z0-9_]+\.[A-Za-z0-9_]+);') {
        $legacy = $matches[1]
        $replacement = $matches[2]
        if (-not $map.ContainsKey($legacy)) {
          $map[$legacy] = $replacement
        }
      }
    }

    $pendingUseHint = $null
    for ($i = 0; $i -lt $lines.Count; $i++) {
      $line = $lines[$i]

      if ($line -match '^\s*--\s*Use\s+([A-Za-z0-9_\.]+)\s+instead\.') {
        $pendingUseHint = $matches[1]
        continue
      }

      if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\(') {
        $legacy = $matches[1]
        $replacement = $pendingUseHint
        $pendingUseHint = $null

        if (-not $replacement) {
          $maxSearch = [Math]::Min($i + 20, $lines.Count - 1)
          for ($j = $i; $j -le $maxSearch; $j++) {
            if ($lines[$j] -match '\b(C_[A-Za-z0-9_]+\.[A-Za-z0-9_]+)\s*\(') {
              $replacement = $matches[1]
              break
            }
          }
        }

        if ($replacement -and -not $map.ContainsKey($legacy)) {
          $map[$legacy] = $replacement
        }
        continue
      }

      if ($line -notmatch '^\s*--') {
        $pendingUseHint = $null
      }
    }
  }

  return $map
}

$apiBasePath = Join-Path $repoRoot $ApiRoot
if (-not (Test-Path $apiBasePath)) {
  Write-Host ""
  Write-Host "ERROR: API root not found: $apiBasePath" -ForegroundColor Red
  exit 1
}

try {
  $api = Get-ApiIndex -ApiBasePath $apiBasePath
} catch {
  Write-Host ""
  Write-Host ("ERROR: Failed to load API index: " + $_.Exception.Message) -ForegroundColor Red
  exit 1
}

$deprecatedMap = Get-DeprecatedMap -ApiBasePath $apiBasePath

$deprecatedRegex = $null
if ($deprecatedMap.Count -gt 0) {
  $legacyNames = $deprecatedMap.Keys | Sort-Object -Unique
  $escaped = $legacyNames | ForEach-Object { [regex]::Escape($_) }
  $pattern = '(?<![A-Za-z0-9_\.])(' + ($escaped -join '|') + ')\s*\('
  $deprecatedRegex = New-Object System.Text.RegularExpressions.Regex($pattern)
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

$files = @()
foreach ($root in $scanRoots) {
  if (Test-Path $root) {
    $files += Get-ChildItem $root -Recurse -Filter *.lua -File -ErrorAction SilentlyContinue
  }
}

foreach ($file in $files) {
  $normalized = Normalize-RelativePath -FullPath $file.FullName
  $lines = Get-Content $file.FullName

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()

    if ($trimmed.StartsWith("--")) {
      continue
    }

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

        Add-Finding -File $normalized -Line ($i + 1) -RuleId $rule.Id -Severity $rule.Severity -Title $rule.Title -Description $rule.Description -Code $line
      }
    }

    $namespaceMatches = [regex]::Matches($line, '\b(C_[A-Za-z0-9_]+)\.([A-Za-z0-9_]+)\s*\(')
    foreach ($m in $namespaceMatches) {
      $namespace = $m.Groups[1].Value
      $fn = $m.Groups[2].Value
      $fullName = "$namespace.$fn"

      if (-not $api.Namespaces.Contains($namespace)) {
        Add-Finding -File $normalized -Line ($i + 1) -RuleId "WAPI100" -Severity "error" -Title "Unknown API namespace for 20505" -Description ("Namespace '{0}' is not present in the loaded API docs ({1})." -f $namespace, $ApiRoot) -Code $line
      } elseif (-not $api.NamespacedFunctions.Contains($fullName)) {
        Add-Finding -File $normalized -Line ($i + 1) -RuleId "WAPI101" -Severity "warn" -Title "Unknown namespaced API function for 20505" -Description ("Function '{0}' is not present in the loaded API docs ({1})." -f $fullName, $ApiRoot) -Code $line
      }
    }

    $isFunctionDefinition = ($line -match '^\s*(?:local\s+)?function\s+[A-Za-z_][A-Za-z0-9_]*\s*\(') -or
                            ($line -match '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*function\s*\(')

    if (-not $isFunctionDefinition -and $deprecatedRegex) {
      $legacyMatches = $deprecatedRegex.Matches($line)
      foreach ($m in $legacyMatches) {
        $legacyName = $m.Groups[1].Value
        $replacement = $deprecatedMap[$legacyName]
        if ($replacement) {
          Add-Finding -File $normalized -Line ($i + 1) -RuleId "WAPI102" -Severity "info" -Title "Deprecated global API fallback call" -Description ("'{0}' has a modern replacement: '{1}'." -f $legacyName, $replacement) -Code $line
        }
      }
    }
  }
}

Write-Host ""
Write-Host "== WoW API Scanner (20505 using loaded docs) =="
Write-Host ("API root: {0}" -f $ApiRoot)
Write-Host ("Scanned {0} Lua files" -f $files.Count)
Write-Host ("Loaded {0} namespaces" -f $api.Namespaces.Count)
Write-Host ("Loaded {0} namespaced functions" -f $api.NamespacedFunctions.Count)
Write-Host ("Loaded {0} global functions" -f $api.GlobalFunctions.Count)
Write-Host ("Loaded {0} deprecation mappings" -f $deprecatedMap.Count)

if ($results.Count -eq 0) {
  Write-Host "No findings."
  exit 0
}

$severityOrder = @{ "error" = 0; "warn" = 1; "info" = 2 }
$bySeverity = $results | Group-Object severity | Sort-Object { $severityOrder[$_.Name] }
foreach ($group in $bySeverity) {
  Write-Host ("{0}: {1}" -f $group.Name.ToUpper(), $group.Count)
}

Write-Host ""
Write-Host "Top findings:"
$results |
  Sort-Object { $severityOrder[$_.severity] }, file, line |
  Select-Object -First $MaxFindings |
  ForEach-Object {
    Write-Host ("[{0}] {1}:{2} {3}" -f $_.rule, $_.file, $_.line, $_.title)
    Write-Host ("  -> {0}" -f $_.description)
    Write-Host ("  -> {0}" -f $_.code)
  }

$errorCount = ($results | Where-Object { $_.severity -eq "error" }).Count
$warnCount = ($results | Where-Object { $_.severity -eq "warn" }).Count

if ($errorCount -gt 0) {
  Write-Host ""
  Write-Host "Scanner failed (error findings present)." -ForegroundColor Red
  exit 1
}

if ($Strict -and $warnCount -gt 0) {
  Write-Host ""
  Write-Host "Scanner failed in strict mode (warn findings present)." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Scanner completed." -ForegroundColor Green
exit 0
