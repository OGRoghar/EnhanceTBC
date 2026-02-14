-- Modules/GCDBar.lua
-- EnhanceTBC - GCD Bar (fully movable only; saves position)
-- SUCCEEDED-only mode: bar starts only when the spell successfully fires.
-- Also fixes Only-in-combat by using InCombatLockdown + regen events.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.GCDBar = mod

local driver
local barFrame, bar, bg, spark

-- Active window
local gcdStart = 0
local gcdDur = 0
local gcdActive = false

-- Fade state
local fadeEndAt = 0
local fadeFrom = 1
local fadeTo = 0
local fadeStartAt = 0
local fadeDuration = 0

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_GCDBarDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.gcdbar = ETBC.db.profile.gcdbar or {}
  local db = ETBC.db.profile.gcdbar

  if db.enabled == nil then db.enabled = true end
  if db.locked == nil then db.locked = true end

  db.anchor = db.anchor or {}
  if db.anchor.point == nil then db.anchor.point = "CENTER" end
  if db.anchor.relPoint == nil then db.anchor.relPoint = "CENTER" end
  if db.anchor.x == nil then db.anchor.x = 0 end
  if db.anchor.y == nil then db.anchor.y = 0 end

  if db.width == nil then db.width = 220 end
  if db.height == nil then db.height = 12 end

  if db.texture == nil then db.texture = "Blizzard" end

  if db.alpha == nil then db.alpha = 1.0 end
  if db.bgAlpha == nil then db.bgAlpha = 0.35 end
  if db.border == nil then db.border = true end

  if db.reverseFill == nil then db.reverseFill = false end
  if db.spark == nil then db.spark = true end

  if db.colorMode == nil then db.colorMode = "CLASS" end
  db.customColor = db.customColor or { r = 0.20, g = 1.00, b = 0.20, a = 1 }

  if db.onlyInCombat == nil then db.onlyInCombat = false end
  if db.hideOutOfCombat == nil then db.hideOutOfCombat = false end

  if db.fadeOut == nil then db.fadeOut = true end
  if db.fadeDelay == nil then db.fadeDelay = 0.15 end
  if db.fadeDuration == nil then db.fadeDuration = 0.25 end

  if db.preview == nil then db.preview = false end

  return db
end

local function GetTexturePath(textureKey)
  if LibStub then
    local ok, LSM = pcall(LibStub, "LibSharedMedia-3.0")
    if ok and LSM and LSM.Fetch then
      local path = LSM:Fetch("statusbar", textureKey, true)
      if path then return path end
    end
  end
  if textureKey == "Flat" then
    return "Interface\\Buttons\\WHITE8x8"
  end
  return "Interface\\TargetingFrame\\UI-StatusBar"
end

local function SetShownCompat(frame, shown)
  if not frame then return end
  if frame.SetShown then
    frame:SetShown(shown and true or false)
    return
  end
  if shown then
    if frame.Show then frame:Show() end
  else
    if frame.Hide then frame:Hide() end
  end
end

local function GetClassColor()
  local _, class = UnitClass("player")
  if class and CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] then
    local c = CUSTOM_CLASS_COLORS[class]
    return c.r, c.g, c.b
  end
  if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
    local c = RAID_CLASS_COLORS[class]
    return c.r, c.g, c.b
  end
  return 0.20, 1.00, 0.20
end

local function ApplyBackdrop(frame, show)
  if not frame or not frame.SetBackdrop then return end
  if not show then
    frame:SetBackdrop(nil)
    return
  end
  frame:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 14,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
  })
  frame:SetBackdropColor(0.03, 0.06, 0.03, 0.85)
  frame:SetBackdropBorderColor(0.20, 1.00, 0.20, 0.80)
end

local function EnsureFrame()
  if barFrame then return end

  barFrame = CreateFrame("Frame", "EnhanceTBC_GCDBarFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  barFrame:SetFrameStrata("MEDIUM")
  barFrame:SetClampedToScreen(true)

  bg = barFrame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(true)
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")

  bar = CreateFrame("StatusBar", nil, barFrame)
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("BOTTOMRIGHT", -2, 2)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  spark = bar:CreateTexture(nil, "OVERLAY")
  spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
  spark:SetBlendMode("ADD")
  spark:SetWidth(20)
  spark:SetHeight(36)
  spark:Hide()

  barFrame:EnableMouse(true)
  barFrame:SetMovable(true)
  barFrame:RegisterForDrag("LeftButton")

  barFrame:SetScript("OnDragStart", function(self)
    local db = GetDB()
    if db.locked then return end
    if not self.StartMoving then return end
    self:StartMoving()
  end)

  barFrame:SetScript("OnDragStop", function(self)
    if self.StopMovingOrSizing then
      self:StopMovingOrSizing()
    end
    local db = GetDB()
    local point, _, relPoint, x, y = self:GetPoint(1)
    db.anchor.point = point or "CENTER"
    db.anchor.relPoint = relPoint or "CENTER"
    db.anchor.x = x or 0
    db.anchor.y = y or 0
  end)

  local hint = barFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
  hint:SetText("Drag")
  hint:Hide()
  barFrame._hint = hint

  barFrame:Hide()
end

local function UpdateLayout(db)
  EnsureFrame()

  barFrame:SetSize(db.width, db.height)

  barFrame:ClearAllPoints()
  barFrame:SetPoint(
    db.anchor.point or "CENTER",
    UIParent,
    db.anchor.relPoint or "CENTER",
    db.anchor.x or 0,
    db.anchor.y or 0
  )

  ApplyBackdrop(barFrame, db.border)

  bar:SetStatusBarTexture(GetTexturePath(db.texture))
  bg:SetAlpha(db.bgAlpha or 0.35)

  barFrame:SetAlpha(db.alpha or 1)
  bar:SetReverseFill(db.reverseFill and true or false)

  if db.spark then spark:Show() else spark:Hide() end
  if barFrame._hint then SetShownCompat(barFrame._hint, not db.locked) end

  local r, g, b = 0.20, 1.00, 0.20
  if db.colorMode == "CLASS" then
    r, g, b = GetClassColor()
  else
    local c = db.customColor or { r = 0.2, g = 1.0, b = 0.2 }
    r, g, b = c.r or 0.2, c.g or 1.0, c.b or 0.2
  end
  bar:SetStatusBarColor(r, g, b, 1)
  bg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 1)
end

local function StartFade(toAlpha, duration)
  if not barFrame then return end
  fadeFrom = barFrame:GetAlpha() or 1
  fadeTo = toAlpha or 0
  fadeStartAt = GetTime()
  fadeDuration = duration or 0.25
end

local function PlayerInCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function ShouldBeVisible(db, active)
  if db.preview then return true end
  if db.onlyInCombat and not PlayerInCombat() then return false end
  if db.hideOutOfCombat and not PlayerInCombat() then return false end
  return active
end

local function BeginGCDWindow(durationHint)
  local now = GetTime()
  gcdStart = now
  gcdDur = durationHint or 1.5
  if gcdDur < 0.75 then gcdDur = 0.75 end
  if gcdDur > 2.0 then gcdDur = 2.0 end
  gcdActive = true
  fadeEndAt = 0
  fadeStartAt = 0
end

local function UpdateVisual(db)
  if not barFrame then return end

  local now = GetTime()

  local active = gcdActive
  if active then
    if (now - gcdStart) >= (gcdDur or 0) then
      gcdActive = false
      active = false
    end
  end

  -- Preview overrides
  if db.preview then
    local fakeDur = 1.5
    local fakeStart = now - (now % fakeDur)
    gcdStart = fakeStart
    gcdDur = fakeDur
    gcdActive = true
    active = true
  end

  local wantVisible = ShouldBeVisible(db, active)

  if wantVisible and not barFrame:IsShown() then
    barFrame:Show()
    barFrame:SetAlpha(db.alpha or 1)
    fadeStartAt = 0
  elseif (not wantVisible) and barFrame:IsShown() then
    barFrame:Hide()
    return
  end

  if not active then
    bar:SetValue(0)
    if db.spark then spark:Hide() end

    if db.fadeOut and not db.preview then
      if fadeEndAt == 0 then
        fadeEndAt = now + (db.fadeDelay or 0.15)
      end
      if fadeEndAt > 0 and now >= fadeEndAt then
        if fadeStartAt == 0 then
          StartFade(0, db.fadeDuration or 0.25)
        end
      end
    end
  else
    barFrame:SetAlpha(db.alpha or 1)
    fadeEndAt = 0
    fadeStartAt = 0

    local t = (now - gcdStart) / ((gcdDur and gcdDur > 0) and gcdDur or 1.5)
    if t < 0 then t = 0 end
    if t > 1 then t = 1 end
    bar:SetValue(t)

    if db.spark then
      local w = bar:GetWidth()
      local x = w * t
      spark:ClearAllPoints()
      spark:SetPoint("CENTER", bar, "LEFT", x, 0)
      spark:Show()
    end
  end

  if fadeStartAt and fadeStartAt > 0 and fadeDuration and fadeDuration > 0 then
    local tt = (now - fadeStartAt) / fadeDuration
    if tt >= 1 then
      barFrame:SetAlpha(fadeTo)
      fadeStartAt = 0
      if fadeTo <= 0.01 then
        barFrame:Hide()
      end
    else
      local a = fadeFrom + (fadeTo - fadeFrom) * tt
      barFrame:SetAlpha(a)
    end
  end
end

local function Apply()
  EnsureDriver()
  EnsureFrame()

  local db = GetDB()
  local enabled = ETBC.db.profile.general.enabled and db.enabled

  driver:UnregisterAllEvents()
  driver:SetScript("OnEvent", nil)
  driver:SetScript("OnUpdate", nil)

  if enabled then
    UpdateLayout(db)

    driver:RegisterEvent("PLAYER_ENTERING_WORLD")
    driver:RegisterEvent("UI_SCALE_CHANGED")
    driver:RegisterEvent("DISPLAY_SIZE_CHANGED")
    driver:RegisterEvent("PLAYER_REGEN_DISABLED")
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")

    -- SUCCEEDED-only: start gcd only when the spell actually fires.
    driver:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")

    driver:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
      if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        UpdateLayout(GetDB())
        return
      end

      -- Combat state changes => immediate refresh via OnUpdate tick
      if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        return
      end

      if event == "UNIT_SPELLCAST_SUCCEEDED" then
        BeginGCDWindow(1.5)
      end
    end)

    driver._accum = 0
    driver:SetScript("OnUpdate", function(self, elapsed)
      self._accum = (self._accum or 0) + elapsed
      if self._accum >= 0.02 then
        self._accum = 0
        UpdateVisual(GetDB())
      end
    end)

    driver:Show()

    if db.preview then
      barFrame:Show()
    else
      barFrame:Hide()
    end
  else
    if barFrame then barFrame:Hide() end
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("gcdbar", Apply)
ETBC.ApplyBus:Register("general", Apply)
