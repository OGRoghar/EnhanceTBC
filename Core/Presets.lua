-- Core/Presets.lua
-- Curated, reversible starting points for common EnhanceTBC setups.

local _, ETBC = ...
if not ETBC then return end

ETBC.Presets = ETBC.Presets or {}
local P = ETBC.Presets

local function Copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for k, v in pairs(value) do out[Copy(k, seen)] = Copy(v, seen) end
  return out
end

P.names = {
  ENHANCED = "Enhanced default",
  CLASSIC = "Classic",
  COMPACT = "Compact",
  HIGH_VISIBILITY = "High visibility",
  PERFORMANCE = "Performance focused",
  DEUTERANOPIA = "Colorblind: red/green",
  TRITANOPIA = "Colorblind: blue/yellow",
}

local function Ensure(profile, key)
  profile[key] = profile[key] or {}
  return profile[key]
end

function P.Apply(_, key)
  local profile = ETBC.db and ETBC.db.profile
  if not profile or not P.names[key] then return false, "unknown preset" end

  ETBC.db.global = ETBC.db.global or {}
  ETBC.db.global.lastPresetBackup = {
    profile = Copy(profile),
    preset = key,
    appliedAt = time and time() or 0,
  }

  local nameplates = Ensure(profile, "nameplates")
  local castbar = Ensure(profile, "castbar")
  local cooldowns = Ensure(profile, "cooldowns")
  local actionbars = Ensure(profile, "actionbars")
  local tooltip = Ensure(profile, "tooltip")
  local auras = Ensure(profile, "auras")

  if key == "CLASSIC" then
    nameplates.enemy_nameplate_width = 109
    nameplates.enemy_nameplate_height = 12.5
    nameplates.enemy_nameplate_health_text = false
    nameplates.enemy_nameplate_execute_enabled = false
    actionbars.fadeOOC = false
    tooltip.skin = tooltip.skin or {}
    tooltip.skin.enabled = false
  elseif key == "COMPACT" then
    nameplates.enemy_nameplate_width = 96
    nameplates.enemy_nameplate_height = 10
    nameplates.enemy_nameplate_health_text_mode = "PERCENT"
    nameplates.enemy_nameplate_name_font_size = 9
    nameplates.enemy_nameplate_health_font_size = 8
    castbar.width = 180
    castbar.height = 14
    cooldowns.size = 13
    actionbars.buttonSize = 32
    actionbars.buttonSpacing = 2
  elseif key == "HIGH_VISIBILITY" then
    nameplates.enemy_nameplate_width = 150
    nameplates.enemy_nameplate_height = 18
    nameplates.enemy_nameplate_health_text = true
    nameplates.enemy_nameplate_health_text_mode = "BOTH"
    nameplates.enemy_nameplate_name_font_size = 13
    nameplates.enemy_nameplate_health_font_size = 12
    nameplates.enemy_nameplate_background_alpha = 0.95
    nameplates.enemy_nameplate_execute_enabled = true
    nameplates.enemy_nameplate_execute_threshold = 25
    castbar.height = 20
    castbar.fontSize = 14
    cooldowns.size = 20
    cooldowns.outline = "THICKOUTLINE"
  elseif key == "PERFORMANCE" then
    nameplates.useAuraDeltaUpdates = true
    nameplates.useSpellIDAuraLookup = true
    nameplates.enemy_nameplate_player_debuffs = false
    auras.useAuraDeltaUpdates = true
    cooldowns.updateInterval = 0.12
    cooldowns.maxTracked = 200
  elseif key == "DEUTERANOPIA" then
    nameplates.enemy_nameplate_execute_enabled = true
    nameplates.enemy_nameplate_execute_color = { r = 0.15, g = 0.65, b = 1.0 }
    nameplates.enemy_nameplate_background_color = { r = 0.08, g = 0.08, b = 0.12 }
    nameplates.nameplate_unit_target_color_value = { r = 1.0, g = 0.75, b = 0.1 }
  elseif key == "TRITANOPIA" then
    nameplates.enemy_nameplate_execute_enabled = true
    nameplates.enemy_nameplate_execute_color = { r = 1.0, g = 0.25, b = 0.45 }
    nameplates.enemy_nameplate_background_color = { r = 0.06, g = 0.08, b = 0.08 }
    nameplates.nameplate_unit_target_color_value = { r = 0.75, g = 0.25, b = 1.0 }
  else -- ENHANCED
    nameplates.enemy_nameplate_width = 120
    nameplates.enemy_nameplate_height = 14
    nameplates.enemy_nameplate_health_text = true
    nameplates.enemy_nameplate_health_text_mode = "BOTH"
    nameplates.enemy_nameplate_background_alpha = 0.85
    actionbars.fadeOOC = false
    tooltip.skin = tooltip.skin or {}
    tooltip.skin.enabled = true
  end

  profile.general = profile.general or {}
  profile.general.lastPreset = key
  profile.general.setupCompleted = true
  if ETBC.RefreshAll then ETBC:RefreshAll("preset:" .. key) end
  return true
end

function P.Undo(_)
  local backup = ETBC.db and ETBC.db.global and ETBC.db.global.lastPresetBackup
  if not backup or type(backup.profile) ~= "table" then
    return false, "no preset backup available"
  end
  local profile = ETBC.db.profile
  wipe(profile)
  for k, v in pairs(Copy(backup.profile)) do profile[k] = v end
  ETBC.db.global.lastPresetBackup = nil
  if ETBC.RefreshAll then ETBC:RefreshAll("preset-undo") end
  return true
end
