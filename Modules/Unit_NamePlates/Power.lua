-- EnhanceTBC - nameplate primary-resource component
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local Power = {}
mod.Internal.Power = Power

local FALLBACK = {
  MANA = { r = 0.12, g = 0.42, b = 1 }, RAGE = { r = 0.85, g = 0.12, b = 0.12 },
  ENERGY = { r = 1, g = 0.82, b = 0.1 }, FOCUS = { r = 1, g = 0.5, b = 0.25 },
  RUNIC_POWER = { r = 0, g = 0.82, b = 1 }, LUNAR_POWER = { r = 0.3, g = 0.52, b = 0.9 },
}

local function colorFor(snapshot)
  local c = PowerBarColor and (PowerBarColor[snapshot.powerToken] or PowerBarColor[snapshot.powerType])
  return c or FALLBACK[snapshot.powerToken] or { r = 0.2, g = 0.65, b = 1 }
end

local function formatText(mode, value, maximum)
  if mode == "PERCENT" then return maximum > 0 and string.format("%d%%", math.floor(value / maximum * 100 + 0.5)) or "" end
  if mode == "VALUE" then return tostring(value) end
  if mode == "VALUE_MAX" then return value .. "/" .. maximum end
  return ""
end

function Power:Ensure(unitFrame)
  if unitFrame.etbcPowerBar then return unitFrame.etbcPowerBar end
  local bar = CreateFrame("StatusBar", nil, unitFrame, "BackdropTemplate")
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar.bg = bar:CreateTexture(nil, "BACKGROUND")
  bar.bg:SetAllPoints(bar)
  bar.bg:SetTexture("Interface\\Buttons\\WHITE8x8")
  bar.bg:SetVertexColor(0.015, 0.015, 0.02, 0.9)
  if bar.SetBackdrop then
    bar:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar:SetBackdropBorderColor(0.03, 0.03, 0.03, 1)
  end
  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
  bar:Hide()
  unitFrame.etbcPowerBar = bar
  return bar
end

function Power:ShouldShow(snapshot, db)
  local cfg = db.power or {}
  if not cfg.enabled or not snapshot or snapshot.isDead or not snapshot.isConnected then return false end
  if type(snapshot.powerMax) ~= "number" or snapshot.powerMax <= 0 then return false end
  local policy = mod.Internal.State and mod.Internal.State:GetCategoryPolicy(snapshot, db)
  if policy and policy.power == false and snapshot.category ~= "targetFocus" then return false end
  if snapshot.isFriendly then
    return cfg.friendlyAlways or ((snapshot.isTarget or snapshot.isFocus) and cfg.showFriendlyTarget ~= false)
  end
  if snapshot.isPlayer then return cfg.showEnemyPlayers ~= false end
  return cfg.showEnemyNPCs ~= false
end

function Power:Layout(unitFrame, shown, db)
  local bar, health, cast = unitFrame.etbcPowerBar, unitFrame.healthBarWrapper, unitFrame.castBarWrapper
  if not health then return end
  if bar then
    -- Blizzard's nameplate UnitFrame can be substantially wider than its
    -- visible health widget. Keep the resource component in the health
    -- wrapper's coordinate space and give it an explicit width so anchors
    -- cannot stretch it to the native plate bounds.
    if bar:GetParent() ~= health then bar:SetParent(health) end
    bar:ClearAllPoints()
    bar:SetPoint("TOP", health, "BOTTOM", 0, 0)
    bar:SetSize(health:GetWidth(), (db.power and db.power.height) or 4)
  end
  if cast then
    cast:ClearAllPoints()
    cast:SetPoint("TOP", shown and bar or health, "BOTTOM", 0, shown and 0 or -3)
  end
end

function Power:Update(nameplate, snapshot, db)
  if not nameplate or not nameplate.UnitFrame then return end
  local bar = self:Ensure(nameplate.UnitFrame)
  local shown = self:ShouldShow(snapshot, db)
  if not shown then bar:Hide(); self:Layout(nameplate.UnitFrame, false, db); return end
  local c = colorFor(snapshot)
  bar:SetMinMaxValues(0, snapshot.powerMax)
  bar:SetValue(snapshot.power or 0)
  bar:SetStatusBarColor(c.r or 0.2, c.g or 0.65, c.b or 1, 1)
  local mode = (snapshot.isTarget or snapshot.isFocus) and (db.power.targetTextMode or "PERCENT")
    or (db.power.textMode or "NONE")
  bar.text:SetText(formatText(mode, snapshot.power or 0, snapshot.powerMax))
  bar:Show()
  self:Layout(nameplate.UnitFrame, true, db)
end

function Power:Reset(unitFrame)
  if unitFrame and unitFrame.etbcPowerBar then unitFrame.etbcPowerBar:Hide() end
end

Power.FormatText = formatText
