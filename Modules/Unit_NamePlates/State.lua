-- EnhanceTBC - unified visible-nameplate state model
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local State = { byGUID = {}, byUnit = {} }
mod.Internal.State = State

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function isUnit(a, b)
  return a and b and call(UnitIsUnit, a, b) == true
end

local function categoryFor(s)
  if s.isTarget or s.isFocus then return "targetFocus" end
  if s.classification == "worldboss" or s.classification == "elite"
    or s.classification == "rareelite" or s.classification == "rare" then
    return "bossesElitesRares"
  end
  local creatureType = s.creatureType and string.lower(s.creatureType) or ""
  if creatureType == "totem" then return "totems" end
  if s.isPet or s.isGuardian then return "petsGuardians" end
  if s.classification == "minus" or s.classification == "trivial" then return "minorUnits" end
  if s.isFriendly then
    return s.isPlayer and "friendlyPlayers" or "friendlyNPCs"
  end
  return s.isPlayer and "enemyPlayers" or "enemyNPCs"
end

function State:Update(unit, dirty)
  if type(unit) ~= "string" or unit == "" or call(UnitExists, unit) == false then return nil end
  local guid = call(UnitGUID, unit)
  if not guid then return nil end
  local s = self.byGUID[guid] or {}
  s.guid, s.token, s.dirty = guid, unit, dirty or "all"
  s.name = call(UnitName, unit)
  local _, class = call(UnitClass, unit)
  s.class = class
  s.reaction = call(UnitReaction, unit, "player")
  s.level = call(UnitLevel, unit)
  s.classification = call(UnitClassification, unit)
  s.creatureType = call(UnitCreatureType, unit)
  s.isPlayer = call(UnitIsPlayer, unit) == true
  s.isFriendly = call(UnitIsFriend, "player", unit) == true
  s.isTarget, s.isFocus = isUnit(unit, "target"), isUnit(unit, "focus")
  s.isPet = isUnit(unit, "pet") or (call(UnitPlayerControlled, unit) == true and not s.isPlayer)
  s.isGuardian = false
  s.isDead = call(UnitIsDeadOrGhost, unit) == true
  s.isConnected = call(UnitIsConnected, unit) ~= false
  s.health, s.healthMax = call(UnitHealth, unit), call(UnitHealthMax, unit)
  local powerType, powerToken = call(UnitPowerType, unit)
  s.powerType, s.powerToken = powerType, powerToken
  s.power = powerType ~= nil and call(UnitPower, unit, powerType) or nil
  s.powerMax = powerType ~= nil and call(UnitPowerMax, unit, powerType) or nil
  if type(UnitDetailedThreatSituation) == "function" then
    local ok, isTanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, "player", unit)
    if ok then
      s.isTanking, s.threatStatus, s.threatPercent, s.threatRaw = isTanking, status, scaled, raw
    else
      s.isTanking, s.threatStatus, s.threatPercent, s.threatRaw = nil, nil, nil, nil
    end
  end
  s.targetOfTarget = call(UnitName, unit .. "target")
  s.category = categoryFor(s)
  self.byGUID[guid], self.byUnit[unit] = s, s
  return s
end

function State:Get(unit)
  return self.byUnit[unit] or self:Update(unit)
end

function State:Remove(unit, guid)
  local s = guid and self.byGUID[guid] or self.byUnit[unit]
  if not s then return end
  self.byGUID[s.guid], self.byUnit[s.token] = nil, nil
end

function State:Clear()
  self.byGUID, self.byUnit = {}, {}
end

function State:GetCategoryPolicy(snapshot, db)
  return snapshot and db and db.categories and db.categories[snapshot.category] or nil
end
