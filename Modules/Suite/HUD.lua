local ADDON_NAME = ...
local ETBC = _G.EnhanceTBC
if not ETBC then return end

ETBC.HUDStudio = ETBC.HUDStudio or {}
local HUD = ETBC.HUDStudio
local frames = {}
local driver

local function Enabled()
  local p = ETBC.db and ETBC.db.profile
  return p and p.general.enabled and p.suite and p.suite.hud and p.suite.hud.enabled and p.hud and p.hud.enabled
end

local function UnitColor(unit)
  if UnitIsPlayer and UnitIsPlayer(unit) then
    local _, class = UnitClass(unit)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
  end
  return 0.22, 0.72, 0.32
end

local function CreateUnitFrame(unit, label, x)
  local f = ETBC.SuiteWidgets:CreatePanel("EnhanceTBC_HUD_" .. label, UIParent, 230, 52)
  f:SetPoint("CENTER", UIParent, "CENTER", x, -155)
  local health = ETBC.SuiteWidgets:CreateBar(f, 218, 24)
  health:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
  local power = ETBC.SuiteWidgets:CreateBar(f, 218, 8, { 0.15, 0.42, 0.85 })
  power:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, -3)
  local name = health:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  name:SetPoint("LEFT", health, "LEFT", 6, 0)
  local value = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  value:SetPoint("RIGHT", health, "RIGHT", -6, 0)
  f.unit, f.health, f.power, f.nameText, f.valueText = unit, health, power, name, value
  ETBC.Mover:Register("HUD" .. label, f, { default = { point = "CENTER", rel = "UIParent", relPoint = "CENTER", x = x, y = -155 } })
  frames[unit] = f
  return f
end

local function UpdateUnit(f)
  if not f then return end
  local exists = UnitExists and UnitExists(f.unit)
  ETBC.SuiteWidgets:SetShown(f, Enabled() and exists)
  if not exists then return end
  local hp, hpMax = UnitHealth(f.unit) or 0, UnitHealthMax(f.unit) or 1
  local power, powerMax = UnitPower(f.unit) or 0, UnitPowerMax(f.unit) or 1
  if hpMax < 1 then hpMax = 1 end
  if powerMax < 1 then powerMax = 1 end
  f.health:SetMinMaxValues(0, hpMax); f.health:SetValue(hp)
  f.health:SetStatusBarColor(UnitColor(f.unit))
  f.power:SetMinMaxValues(0, powerMax); f.power:SetValue(power)
  f.nameText:SetText(UnitName(f.unit) or f.unit)
  f.valueText:SetText(('%d%%'):format(math.floor((hp / hpMax) * 100 + 0.5)))
end

local function EvaluateTracker(rule)
  if type(rule) ~= "table" or rule.enabled == false then return false end
  local unit = type(rule.unit) == "string" and rule.unit or "player"
  if rule.kind == "health" then
    local max = UnitHealthMax(unit) or 0
    if max <= 0 then return false end
    local percent = (UnitHealth(unit) or 0) * 100 / max
    return percent <= (tonumber(rule.threshold) or 35)
  elseif rule.kind == "combat" then
    return (UnitAffectingCombat and UnitAffectingCombat(unit) and true or false) == (rule.inCombat ~= false)
  elseif rule.kind == "provider" and type(rule.provider) == "string" then
    local value = ETBC.FeatureSuite:GetProviderValue(rule.provider, { unit = unit })
    return value and true or false
  end
  return false
end

function HUD:EvaluateTrackers()
  local rules = ETBC.db and ETBC.db.profile and ETBC.db.profile.hud and ETBC.db.profile.hud.trackers or {}
  local out = {}
  local limit = math.min(#rules, tonumber(ETBC.db.profile.hud.maxTrackers) or 64)
  for i = 1, limit do out[i] = { id = rules[i].id or i, active = EvaluateTracker(rules[i]) } end
  return out
end

function HUD:Apply()
  if not Enabled() then
    if driver then driver:UnregisterAllEvents() end
    for _, f in pairs(frames) do ETBC.SuiteWidgets:SetShown(f, false) end
    return
  end
  if not driver then
    driver = CreateFrame("Frame", "EnhanceTBC_HUDDriver", UIParent)
    driver:SetScript("OnEvent", function(_, _, unit)
      if unit and frames[unit] then UpdateUnit(frames[unit]); return end
      for _, f in pairs(frames) do UpdateUnit(f) end
    end)
  end
  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("UNIT_HEALTH")
  driver:RegisterEvent("UNIT_MAXHEALTH")
  driver:RegisterEvent("UNIT_POWER_UPDATE")
  if not frames.player then CreateUnitFrame("player", "Player", -150) end
  if not frames.target then CreateUnitFrame("target", "Target", 150) end
  for _, f in pairs(frames) do UpdateUnit(f) end
end

ETBC.ApplyBus:Register("hud", function() HUD:Apply() end)
HUD:Apply()
