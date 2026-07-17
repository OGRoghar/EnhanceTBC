-- EnhanceTBC - nameplate primary-resource component
local _, ETBC = ...
local mod = ETBC.Modules and ETBC.Modules.Nameplates
if not mod then return end

mod.Internal = mod.Internal or {}
local Power = {}
mod.Internal.Power = Power
local shared = mod.Internal.Shared or {}

local FALLBACK = {
  MANA = { r = 0.12, g = 0.42, b = 1 }, RAGE = { r = 0.85, g = 0.12, b = 0.12 },
  ENERGY = { r = 1, g = 0.82, b = 0.1 }, FOCUS = { r = 1, g = 0.5, b = 0.25 },
  RUNIC_POWER = { r = 0, g = 0.82, b = 1 }, LUNAR_POWER = { r = 0.3, g = 0.52, b = 0.9 },
}

local function colorFor(snapshot)
  local c = PowerBarColor and (PowerBarColor[snapshot.powerToken] or PowerBarColor[snapshot.powerType])
  return c or FALLBACK[snapshot.powerToken] or { r = 0.2, g = 0.65, b = 1 }
end

local function rgb(color)
  return color.r or color[1] or 0.2, color.g or color[2] or 0.65, color.b or color[3] or 1
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
  bar.bg:SetVertexColor(0.012, 0.014, 0.018, 0.96)
  bar.highlight = bar:CreateTexture(nil, "ARTWORK")
  bar.highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
  bar.highlight:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
  bar.highlight:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -1, -1)
  bar.highlight:SetHeight(1)
  bar.highlight:SetVertexColor(1, 1, 1, 0.14)
  if bar.SetBackdrop then
    bar:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    bar:SetBackdropBorderColor(0.015, 0.017, 0.022, 1)
  end
  bar.text = bar:CreateFontString(nil, "OVERLAY")
  bar.text:SetPoint("CENTER")
  bar.text:SetFont("Fonts\\FRIZQT__.TTF", 7, "OUTLINE")
  bar.text:SetTextColor(0.96, 0.97, 1, 1)
  if bar.text.SetShadowColor then bar.text:SetShadowColor(0, 0, 0, 0.9) end
  if bar.text.SetShadowOffset then bar.text:SetShadowOffset(1, -1) end
  bar:Hide()
  unitFrame.etbcPowerBar = bar

  local health = unitFrame.healthBar
  if health and health.HookScript and not unitFrame.etbcWidthSyncHooked then
    unitFrame.etbcWidthSyncHooked = true
    health:HookScript("OnSizeChanged", function()
      if unitFrame.etbcSyncingWidth or unitFrame.etbcWidthSyncPending then return end
      unitFrame.etbcWidthSyncPending = true
      local function RepairWidth()
        unitFrame.etbcWidthSyncPending = false
        if not unitFrame.etbcPowerBar then return end
        local db = shared.GetDB and shared.GetDB()
        if db then
          Power:Layout(unitFrame, unitFrame.etbcPowerBar:IsShown(), db)
        end
      end
      if C_Timer and C_Timer.After then C_Timer.After(0, RepairWidth) else RepairWidth() end
    end)
  end
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
  local bar, wrapper, health, cast = unitFrame.etbcPowerBar, unitFrame.healthBarWrapper,
    unitFrame.healthBar, unitFrame.castBarWrapper
  local anchor = health or wrapper
  if not anchor then return end
  local visibleWidth = wrapper and wrapper:GetWidth() or anchor:GetWidth()

  -- Blizzard applies selected-nameplate sizing directly to its StatusBar.
  -- Reassert the wrapper as the one width authority for both visible bars.
  if health and wrapper and type(visibleWidth) == "number" then
    unitFrame.etbcSyncingWidth = true
    health:ClearAllPoints()
    health:SetPoint("BOTTOM", wrapper, "BOTTOM", 0, 0)
    health:SetSize(visibleWidth, wrapper:GetHeight())
    unitFrame.etbcSyncingWidth = false
  end
  if bar then
    -- Attach to the actual Blizzard health StatusBar, not only our sizing
    -- wrapper. Blizzard can reanchor its selected health bar after
    -- PLAYER_TARGET_CHANGED; parenting here makes power follow that native
    -- movement automatically instead of being left behind with the wrapper.
    if bar:GetParent() ~= anchor then bar:SetParent(anchor) end
    bar:ClearAllPoints()
    bar:SetPoint("TOP", anchor, "BOTTOM", 0, 0)
    -- The native StatusBar can retain Blizzard's full nameplate width even
    -- while our wrapper constrains the visible health fill. Size power from
    -- that visible wrapper so health and power always scale together.
    bar:SetSize(visibleWidth, (db.power and db.power.height) or 6)
    if bar.SetFrameLevel and anchor.GetFrameLevel then
      local level = anchor:GetFrameLevel()
      if type(level) == "number" then bar:SetFrameLevel(level + 1) end
    end
  end
  if cast then
    cast:ClearAllPoints()
    cast:SetPoint("TOP", shown and bar or anchor, "BOTTOM", 0, shown and 0 or -3)
  end
end

function Power:Update(nameplate, snapshot, db)
  if not nameplate or not nameplate.UnitFrame then return end
  local bar = self:Ensure(nameplate.UnitFrame)
  local shown = self:ShouldShow(snapshot, db)
  if not shown then bar:Hide(); self:Layout(nameplate.UnitFrame, false, db); return end
  local c = colorFor(snapshot)
  local r, g, b = rgb(c)
  local healthTexture = nameplate.UnitFrame.healthBar and nameplate.UnitFrame.healthBar.GetStatusBarTexture
    and nameplate.UnitFrame.healthBar:GetStatusBarTexture()
  if healthTexture and healthTexture.GetTexture then
    local texture = healthTexture:GetTexture()
    if texture then bar:SetStatusBarTexture(texture) end
  end
  bar:SetMinMaxValues(0, snapshot.powerMax)
  bar:SetValue(snapshot.power or 0)
  bar:SetStatusBarColor(r, g, b, 1)
  if bar.SetBackdropBorderColor then
    bar:SetBackdropBorderColor(r * 0.28, g * 0.28, b * 0.28, 1)
  end
  local mode = (snapshot.isTarget or snapshot.isFocus) and (db.power.targetTextMode or "PERCENT")
    or (db.power.textMode or "NONE")
  local text = formatText(mode, snapshot.power or 0, snapshot.powerMax)
  bar.text:SetText(text)
  bar.text:SetShown(text ~= "" and ((db.power and db.power.height) or 6) >= 6)
  bar:Show()
  self:Layout(nameplate.UnitFrame, true, db)
end

function Power:Reset(unitFrame)
  if unitFrame and unitFrame.etbcPowerBar then unitFrame.etbcPowerBar:Hide() end
end

Power.FormatText = formatText
