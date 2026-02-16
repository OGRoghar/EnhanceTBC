-- Visibility/Visibility_Helper.lua
local ADDON_NAME, ETBC = ...

ETBC.Visibility = ETBC.Visibility or {}
local V = ETBC.Visibility

-- Cache the Blizzard API function to avoid shadowing
local BlizzIsInInstance = IsInInstance

local function IsInInstance()
  if BlizzIsInInstance then
    local inInstance = BlizzIsInInstance()
    return inInstance and true or false
  end
  return false
end

local function IsInRaidGroup()
  return (IsInRaid and IsInRaid()) and true or false
end

local function IsInPartyGroup()
  -- In Classic/TBC, IsInGroup() is true in raid too, so guard it
  local inGroup = (IsInGroup and IsInGroup()) and true or false
  return (inGroup and not IsInRaidGroup()) and true or false
end

local function IsSolo()
  return (not (IsInGroup and IsInGroup())) and true or false
end

local function IsInBattleground()
  if IsInInstance then
    local _, instType = IsInInstance()
    return instType == "pvp"
  end
  return false
end

-- Evaluate can take:
--  1) nil/""/"always"/"never"/"incombat"/etc (string)
--  2) boolean
--  3) table like your Defaults.visibility.global/modules entries
function V:Evaluate(condition)
  if condition == nil or condition == "" then return true end

  local t = type(condition)

  -- boolean pass-through
  if t == "boolean" then
    return condition and true or false
  end

  -- table form: interpret as flags (matches your Defaults.visibility.* shape)
  if t == "table" then
    -- If condition.enabled is false, treat it as "no override" -> true (safe)
    if condition.enabled == false then return true end

    if condition.inCombat and not UnitAffectingCombat("player") then return false end
    if condition.outOfCombat and UnitAffectingCombat("player") then return false end

    if condition.inInstance and not IsInInstance() then return false end
    if condition.inRaid and not IsInRaidGroup() then return false end
    if condition.inParty and not IsInPartyGroup() then return false end
    if condition.solo and not IsSolo() then return false end
    if condition.inBattleground and not IsInBattleground() then return false end

    return true
  end

  -- string form (your original)
  local s = tostring(condition):lower()

  if s == "always" then return true end
  if s == "never" then return false end

  if s == "incombat" then
    return UnitAffectingCombat("player") and true or false
  end

  if s == "outofcombat" then
    return (not UnitAffectingCombat("player")) and true or false
  end

  if s == "ininstance" then return IsInInstance() end
  if s == "inraid" then return IsInRaidGroup() end
  if s == "inparty" then return IsInPartyGroup() end
  if s == "solo" then return IsSolo() end
  if s == "inbattleground" then return IsInBattleground() end

  -- Unknown condition defaults to true (safe)
  return true
end
