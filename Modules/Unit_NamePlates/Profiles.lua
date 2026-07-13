-- EnhanceTBC - curated nameplate presets and one-level undo
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local Profiles = {}
mod.Internal.Profiles = Profiles

local PRESETS = {
  MINIMAL = { power = { enabled = false }, threat = { enabled = false }, targeting = { nonTargetAlpha = 0.65 }, enemy_nameplate_health_text = false, enemy_nameplate_debuff = false, enemy_nameplate_player_debuffs = false },
  PVE = { power = { enabled = true, textMode = "NONE", targetTextMode = "PERCENT" }, threat = { enabled = true, showPercent = false }, targeting = { targetScale = 1.08, nonTargetAlpha = 0.82 }, enemy_nameplate_debuff = true, enemy_nameplate_player_debuffs = true },
  TANK = { power = { enabled = true, targetTextMode = "PERCENT" }, threat = { enabled = true, showPercent = true }, targeting = { targetScale = 1.1, nonTargetAlpha = 0.9 }, enemy_nameplate_execute_enabled = false },
  HEALER = { power = { enabled = true, friendlyAlways = true, targetTextMode = "PERCENT" }, threat = { enabled = true, showPercent = false }, targeting = { nonTargetAlpha = 0.88 } },
  PVP = { power = { enabled = true, showEnemyPlayers = true, showEnemyNPCs = false, targetTextMode = "PERCENT" }, threat = { enabled = false, showPercent = false }, targeting = { targetScale = 1.12, nonTargetAlpha = 0.72 }, enemy_nameplate_debuff = true, enemy_nameplate_player_debuffs = true, enemy_nameplate_stance = true },
}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local result = {}; seen[value] = result
  for key, item in pairs(value) do result[copy(key, seen)] = copy(item, seen) end
  return result
end

local function merge(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" then
      target[key] = type(target[key]) == "table" and target[key] or {}
      merge(target[key], value)
    else target[key] = value end
  end
end

function Profiles:GetPresetKeys()
  return { "MINIMAL", "PVE", "TANK", "HEALER", "PVP" }
end

function Profiles:ResolveContextPreset(db)
  if not db or not db.autoPreset then return db and db.selectedPreset or "PVE" end
  local inInstance, instanceType = IsInInstance and IsInInstance()
  if inInstance and (instanceType == "pvp" or instanceType == "arena") then return "PVP" end
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
  if role == "TANK" then return "TANK" end
  if role == "HEALER" then return "HEALER" end
  return db.selectedPreset or "PVE"
end

function Profiles:Apply(key)
  local db = ETBC.db and ETBC.db.profile and ETBC.db.profile.nameplates
  local preset = PRESETS[key]
  if not db or not preset then return false, "unknown preset" end
  db.presetUndo = copy(db)
  db.presetUndo.presetUndo = nil
  merge(db, preset)
  db.selectedPreset = key
  if ETBC.ApplyBus then ETBC.ApplyBus:Notify("nameplates") end
  return true
end

function Profiles:ApplyContext()
  local db = ETBC.db and ETBC.db.profile and ETBC.db.profile.nameplates
  if not db then return false end
  if not db.autoPreset then
    if type(db.autoPresetBase) == "table" then
      local base = copy(db.autoPresetBase)
      base.autoPreset = false
      ETBC.db.profile.nameplates = base
    end
    return false
  end
  local key = self:ResolveContextPreset(db)
  if db.activeContextPreset == key then return false end
  local base = type(db.autoPresetBase) == "table" and copy(db.autoPresetBase) or copy(db)
  base.autoPresetBase, base.activeContextPreset = nil, nil
  local result = copy(base)
  merge(result, PRESETS[key] or PRESETS.PVE)
  result.autoPreset = true
  result.autoPresetBase = base
  result.activeContextPreset = key
  ETBC.db.profile.nameplates = result
  return true
end

function Profiles:Undo()
  local profile = ETBC.db and ETBC.db.profile
  local db = profile and profile.nameplates
  if not db or type(db.presetUndo) ~= "table" then return false, "nothing to undo" end
  local restored = copy(db.presetUndo)
  restored.presetUndo = nil
  profile.nameplates = restored
  if ETBC.ApplyBus then ETBC.ApplyBus:Notify("nameplates") end
  return true
end

Profiles.PRESETS = PRESETS
Profiles.Copy = copy
