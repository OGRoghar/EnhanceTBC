-- Modules/Castbar.lua
-- EnhanceTBC - Castbar Micro Tweaks (Blizzard cast bars)
-- Fix: prevent "double layer" by anchoring overlays to the real statusbar texture
-- and using OVERLAY layer + insets.

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Castbar = mod

local driver
local hooked = false

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_CastbarDriver", UIParent)
end

local function GetDB()
  ETBC.db.profile.castbar = ETBC.db.profile.castbar or {}
  local db = ETBC.db.profile.castbar

  if db.enabled == nil then db.enabled = true end

  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.fontSize == nil then db.fontSize = 11 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end

  if db.showTime == nil then db.showTime = true end
  if db.timeFormat == nil then db.timeFormat = "REMAINING" end -- REMAINING | ELAPSED | BOTH

  -- Latency overlay (player only)
  if db.showLatency == nil then db.showLatency = true end
  if db.latencyColor == nil then db.latencyColor = { 0.20, 1.00, 0.20, 0.28 } end

  if db.width == nil then db.width = 195 end
  if db.height == nil then db.height = 18 end
  if db.scale == nil then db.scale = 1.0 end

  if db.target == nil then db.target = true end
  if db.focus == nil then db.focus = true end
  if db.player == nil then db.player = true end

  if db.onlyInCombat == nil then db.onlyInCombat = false end
  if db.oocAlpha == nil then db.oocAlpha = 1.0 end
  if db.combatAlpha == nil then db.combatAlpha = 1.0 end

  return db
end

local function LSM_Fetch(kind, key, fallback)
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, v = pcall(ETBC.LSM.Fetch, ETBC.LSM, kind, key)
    if ok and v then return v end
  end
  return fallback
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function StyleFontString(fs)
  if not fs or not fs.SetFont then return end
  local db = GetDB()
  local fontPath = LSM_Fetch("font", db.font, "Fonts\\FRIZQT__.TTF")
  local size = tonumber(db.fontSize) or 11
  local outline = db.outline or ""
  fs:SetFont(fontPath, size, outline)

  if db.shadow then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
  else
    fs:SetShadowOffset(0, 0)
  end
end

local function EnsureText(bar)
  if not bar then return nil end
  if bar._etbcTimeText and bar._etbcTimeText.SetText then return bar._etbcTimeText end

  local fs = bar:CreateFontString(nil, "OVERLAY")
  fs:SetPoint("RIGHT", bar, "RIGHT", -4, 0)

  -- SetFont BEFORE SetText
  bar._etbcTimeText = fs
  StyleFontString(fs)
  fs:SetText("")
  fs:Hide()
  return fs
end

-- Returns a good "content" region inside the castbar for overlay anchoring.
-- Prefer the real statusbar texture if available.
local function GetFillRegion(bar)
  if not bar then return bar end

  -- Most Blizzard castbars are StatusBars
  if bar.GetStatusBarTexture then
    local tx = bar:GetStatusBarTexture()
    if tx and tx.GetParent then
      return tx
    end
  end

  -- Some templates expose a texture directly
  if bar.barTexture and bar.barTexture.GetParent then
    return bar.barTexture
  end

  return bar
end

local function EnsureLatency(bar)
  if not bar then return nil end
  if bar._etbcLatency and bar._etbcLatency.SetWidth then return bar._etbcLatency end

  -- Create as OVERLAY so it cannot look like a second background bar.
  local tx = bar:CreateTexture(nil, "OVERLAY")
  tx:SetTexture("Interface\\Buttons\\WHITE8x8")

  -- Anchor to the fill region (statusbar texture) with small insets.
  local region = GetFillRegion(bar)
  tx:ClearAllPoints()

  if region ~= bar and region.GetPoint then
    -- Match the vertical bounds of the real fill texture (avoid border/flash layers)
    tx:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)
    tx:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  else
    tx:SetPoint("TOPRIGHT", bar, "TOPRIGHT", -2, -2)
    tx:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 2)
  end

  tx:SetWidth(0)

  local db = GetDB()
  local c = db.latencyColor or { 0.2, 1, 0.2, 0.28 }
  tx:SetVertexColor(c[1] or 0.2, c[2] or 1, c[3] or 0.2, c[4] or 0.28)

  tx:Hide()
  bar._etbcLatency = tx
  return tx
end

local function ApplySizing(bar)
  if not bar then return end
  local db = GetDB()

  if not bar._etbcOrig then
    bar._etbcOrig = {
      w = bar.GetWidth and bar:GetWidth() or nil,
      h = bar.GetHeight and bar:GetHeight() or nil,
      scale = bar.GetScale and bar:GetScale() or 1,
    }
  end

  if not db.enabled then
    if bar.SetScale and bar._etbcOrig.scale then bar:SetScale(bar._etbcOrig.scale) end
    if bar.SetSize and bar._etbcOrig.w and bar._etbcOrig.h then bar:SetSize(bar._etbcOrig.w, bar._etbcOrig.h) end
    return
  end

  if bar.SetScale then bar:SetScale(tonumber(db.scale) or 1) end
  -- NOTE: Width/Height resizing disabled - causes size mismatch between frame and internal statusbar texture
  -- Use scale setting instead
  -- if bar.SetSize then bar:SetSize(tonumber(db.width) or 195, tonumber(db.height) or 18) end
end

local function ApplyAlpha(bar)
  local db = GetDB()
  if not db.enabled then
    if bar and bar.SetAlpha then bar:SetAlpha(1) end
    return
  end

  local a = 1
  if db.onlyInCombat then
    a = InCombat() and (db.combatAlpha or 1) or (db.oocAlpha or 0.2)
  else
    a = 1
  end

  if bar and bar.SetAlpha then bar:SetAlpha(a) end
end

local function FormatTime(cur, maxv, mode)
  if not cur or not maxv or maxv <= 0 then return "" end
  local remain = maxv - cur
  if remain < 0 then remain = 0 end

  if mode == "ELAPSED" then
    return string.format("%.1f", cur)
  elseif mode == "BOTH" then
    return string.format("%.1f/%.1f", cur, maxv)
  end
  return string.format("%.1f", remain)
end

local function UpdateBarText(bar)
  if not bar or not bar.IsShown or not bar:IsShown() then return end
  local db = GetDB()
  if not (db.enabled and db.showTime) then
    if bar._etbcTimeText then bar._etbcTimeText:SetText(""); bar._etbcTimeText:Hide() end
    return
  end

  local fs = EnsureText(bar)
  StyleFontString(fs)

  local cur = bar.GetValue and bar:GetValue() or 0
  local maxv = bar.GetMinMaxValues and select(2, bar:GetMinMaxValues()) or 0
  fs:SetText(FormatTime(cur, maxv, db.timeFormat or "REMAINING"))
  fs:Show()
end

local function UpdateLatency(bar)
  local db = GetDB()
  if not (db.enabled and db.showLatency) then
    if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  -- Player only
  if not bar or not bar.unit or bar.unit ~= "player" then
    if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  if not bar._etbcSentMS or not bar._etbcStartMS then
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local maxv = bar.GetMinMaxValues and select(2, bar:GetMinMaxValues()) or 0
  if not maxv or maxv <= 0 then
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local lagMS = bar._etbcStartMS - bar._etbcSentMS
  if lagMS < 0 then lagMS = 0 end

  local lagSeconds = lagMS / 1000
  if lagSeconds <= 0 then
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    return
  end

  local frac = lagSeconds / maxv
  if frac > 1 then frac = 1 end

  local tx = EnsureLatency(bar)

  local barW = (bar.GetWidth and bar:GetWidth() or 195) - 4 -- account for inset (-2,-2)
  if barW < 1 then barW = 1 end

  tx:SetWidth(barW * frac)
  tx:Show()
end

local function OnBarValueChanged(bar)
  UpdateBarText(bar)
  UpdateLatency(bar)
end

local function HookBar(bar)
  if not bar or bar._etbcHooked then return end
  bar._etbcHooked = true

  -- Hook SetValue to refresh time/latency without OnUpdate spam
  hooksecurefunc(bar, "SetValue", function()
    OnBarValueChanged(bar)
  end)

  bar:HookScript("OnShow", function()
    ApplySizing(bar)
    ApplyAlpha(bar)
    OnBarValueChanged(bar)
  end)

  bar:HookScript("OnHide", function()
    if bar._etbcLatency then bar._etbcLatency:Hide() end
    if bar._etbcTimeText then bar._etbcTimeText:Hide() end
  end)

  ApplySizing(bar)
  ApplyAlpha(bar)
end

local function GetBars()
  local db = GetDB()
  local out = {}

  if db.player then
    if _G.PlayerCastingBarFrame then table.insert(out, _G.PlayerCastingBarFrame) end
    if _G.CastingBarFrame then table.insert(out, _G.CastingBarFrame) end
  end

  if db.target and _G.TargetFrameSpellBar then
    table.insert(out, _G.TargetFrameSpellBar)
  end

  if db.focus and _G.FocusFrameSpellBar then
    table.insert(out, _G.FocusFrameSpellBar)
  end

  return out
end

local function Apply()
  EnsureDriver()

  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local db = GetDB()
  if not (generalEnabled and db.enabled) then
    for _, bar in ipairs(GetBars()) do
      ApplySizing(bar)
      if bar and bar._etbcTimeText then bar._etbcTimeText:SetText(""); bar._etbcTimeText:Hide() end
      if bar and bar._etbcLatency then bar._etbcLatency:Hide() end
      if bar and bar.SetAlpha then bar:SetAlpha(1) end
    end
    return
  end

  for _, bar in ipairs(GetBars()) do
    HookBar(bar)
    ApplySizing(bar)
    ApplyAlpha(bar)
    OnBarValueChanged(bar)
  end
end

local function EnsureHooks()
  if hooked then return end
  hooked = true

  EnsureDriver()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")

  -- latency capture (player casts only)
  driver:RegisterEvent("UNIT_SPELLCAST_SENT")
  driver:RegisterEvent("UNIT_SPELLCAST_START")
  driver:RegisterEvent("UNIT_SPELLCAST_STOP")
  driver:RegisterEvent("UNIT_SPELLCAST_FAILED")
  driver:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
  driver:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
  driver:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

  driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
      Apply()
      return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
      for _, bar in ipairs(GetBars()) do ApplyAlpha(bar) end
      return
    end

    if unit ~= "player" then return end

    local function StampSent()
      local ms = GetTime and math.floor(GetTime() * 1000) or 0
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then pb._etbcSentMS = ms end
    end

    local function StampStart()
      local ms = GetTime and math.floor(GetTime() * 1000) or 0
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then pb._etbcStartMS = ms end
    end

    if event == "UNIT_SPELLCAST_SENT" then
      StampSent()
      return
    end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
      StampStart()
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb then
        HookBar(pb)
        OnBarValueChanged(pb)
      end
      return
    end

    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      local pb = _G.PlayerCastingBarFrame or _G.CastingBarFrame
      if pb and pb._etbcLatency then pb._etbcLatency:Hide() end
      return
    end
  end)
end

EnsureHooks()

ETBC.ApplyBus:Register("castbar", Apply)
ETBC.ApplyBus:Register("general", Apply)
