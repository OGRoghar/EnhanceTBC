-- Modules/Visibility.lua
local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Visibility = mod

local driver

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_VisibilityDriver", UIParent)
  driver:Hide()
end

local function InInstance()
  local inInst, instType = IsInInstance()
  return inInst, instType
end

local function IsInParty()
  return (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0
end

local function IsInRaid()
  return (GetNumRaidMembers and GetNumRaidMembers() or 0) > 0
end

local function IsInBattleground()
  local inInst, instType = InInstance()
  return inInst and instType == "pvp"
end

local function IsSolo()
  return (not IsInRaid()) and (not IsInParty())
end

local function MatchRules(rules)
  if not rules then return true end

  local inCombat = UnitAffectingCombat("player") and true or false
  local inInst = InInstance()
  local inRaid = IsInRaid()
  local inParty = IsInParty()
  local solo = IsSolo()
  local inBG = IsInBattleground()

  if rules.inCombat and not inCombat then return false end
  if rules.outOfCombat and inCombat then return false end
  if rules.inInstance and not inInst then return false end
  if rules.inRaid and not inRaid then return false end
  if rules.inParty and not inParty then return false end
  if rules.solo and not solo then return false end
  if rules.inBattleground and not inBG then return false end

  return true
end

function mod:Allowed(moduleKey)
  local p = ETBC.db.profile
  local v = p.visibility
  if not (p.general.enabled and v and v.enabled) then
    return true -- visibility system off => allow
  end

  local rules = nil
  if v.modules and v.modules[moduleKey] and v.modules[moduleKey].enabled then
    rules = v.modules[moduleKey]
  elseif v.global and v.global.enabled then
    rules = v.global
  end

  return MatchRules(rules)
end

local function NotifyAffected()
  -- modules that we currently support visibility for
  ETBC.ApplyBus:Notify("auras")
  ETBC.ApplyBus:Notify("actiontracker")
  ETBC.ApplyBus:Notify("combattext")
end

local function Apply()
  EnsureDriver()

  local p = ETBC.db.profile
  local v = p.visibility
  local enabled = p.general.enabled and v and v.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)

  if not enabled then
    driver:Hide()
    NotifyAffected()
    return
  end

  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  driver:RegisterEvent("GROUP_ROSTER_UPDATE")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")

  driver:SetScript("OnEvent", function()
    NotifyAffected()
  end)

  driver:Show()
  NotifyAffected()
end

ETBC.ApplyBus:Register("visibility", Apply)
ETBC.ApplyBus:Register("general", Apply)
