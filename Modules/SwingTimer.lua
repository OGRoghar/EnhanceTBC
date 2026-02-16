-- Modules/SwingTimer.lua
-- EnhanceTBC - Melee Swing Timer (tracks auto-attack swing timers)
-- Monitors COMBAT_LOG_EVENT_UNFILTERED for SWING_DAMAGE/SWING_MISSED to track melee swings
-- Supports dual-wield with separate main-hand and off-hand bars

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.SwingTimer = mod

local driver
local mainHandFrame, mainHandBar, mainHandBg, mainHandSpark
local offHandFrame, offHandBar, offHandBg, offHandSpark

-- Swing state
local mainHandSpeed = 0
local offHandSpeed = 0
local mainHandNext = 0
local offHandNext = 0
local mainHandActive = false
local offHandActive = false

-- Fade state for main hand
local mhFadeEndAt = 0
local mhFadeFrom = 1
local mhFadeTo = 0
local mhFadeStartAt = 0
local mhFadeDuration = 0

-- Fade state for off hand
local ohFadeEndAt = 0
local ohFadeFrom = 1
local ohFadeTo = 0
local ohFadeStartAt = 0
local ohFadeDuration = 0

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_SwingTimerDriver", UIParent)
  driver:Hide()
end

local function GetDB()
  ETBC.db.profile.swingtimer = ETBC.db.profile.swingtimer or {}
  local db = ETBC.db.profile.swingtimer

  if db.enabled == nil then db.enabled = true end
  if db.locked == nil then db.locked = true end

  db.mainHand = db.mainHand or {}
  local mh = db.mainHand
  if mh.anchor == nil then mh.anchor = {} end
  if mh.anchor.point == nil then mh.anchor.point = "CENTER" end
  if mh.anchor.relPoint == nil then mh.anchor.relPoint = "CENTER" end
  if mh.anchor.x == nil then mh.anchor.x = 0 end
  if mh.anchor.y == nil then mh.anchor.y = -200 end

  db.offHand = db.offHand or {}
  local oh = db.offHand
  if oh.anchor == nil then oh.anchor = {} end
  if oh.anchor.point == nil then oh.anchor.point = "CENTER" end
  if oh.anchor.relPoint == nil then oh.anchor.relPoint = "CENTER" end
  if oh.anchor.x == nil then oh.anchor.x = 0 end
  if oh.anchor.y == nil then oh.anchor.y = -220 end

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

  if db.showOffHand == nil then db.showOffHand = true end

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

local function CreateSwingBar(name, anchorData)
  local barFrame = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  barFrame:SetFrameStrata("MEDIUM")
  barFrame:SetClampedToScreen(true)

  local bg = barFrame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(true)
  bg:SetTexture("Interface\\Buttons\\WHITE8x8")

  local bar = CreateFrame("StatusBar", nil, barFrame)
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("BOTTOMRIGHT", -2, 2)
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0)

  local spark = bar:CreateTexture(nil, "OVERLAY")
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
    anchorData.point = point or "CENTER"
    anchorData.relPoint = relPoint or "CENTER"
    anchorData.x = x or 0
    anchorData.y = y or 0
  end)

  local hint = barFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("CENTER", barFrame, "CENTER", 0, 0)
  hint:SetText("Drag")
  hint:Hide()
  barFrame._hint = hint

  barFrame:Hide()

  return barFrame, bar, bg, spark
end

local function EnsureFrames()
  if mainHandFrame then return end

  local db = GetDB()
  mainHandFrame, mainHandBar, mainHandBg, mainHandSpark = CreateSwingBar("EnhanceTBC_SwingTimer_MainHand", db.mainHand.anchor)
  offHandFrame, offHandBar, offHandBg, offHandSpark = CreateSwingBar("EnhanceTBC_SwingTimer_OffHand", db.offHand.anchor)
end

local function UpdateLayout(db)
  EnsureFrames()

  -- Main Hand
  mainHandFrame:SetSize(db.width, db.height)
  mainHandFrame:ClearAllPoints()
  mainHandFrame:SetPoint(
    db.mainHand.anchor.point or "CENTER",
    UIParent,
    db.mainHand.anchor.relPoint or "CENTER",
    db.mainHand.anchor.x or 0,
    db.mainHand.anchor.y or -200
  )

  ApplyBackdrop(mainHandFrame, db.border)
  mainHandBar:SetStatusBarTexture(GetTexturePath(db.texture))
  mainHandBg:SetAlpha(db.bgAlpha or 0.35)
  mainHandFrame:SetAlpha(db.alpha or 1)
  mainHandBar:SetReverseFill(db.reverseFill and true or false)

  if db.spark then mainHandSpark:Show() else mainHandSpark:Hide() end
  if mainHandFrame._hint then SetShownCompat(mainHandFrame._hint, not db.locked) end

  -- Off Hand
  offHandFrame:SetSize(db.width, db.height)
  offHandFrame:ClearAllPoints()
  offHandFrame:SetPoint(
    db.offHand.anchor.point or "CENTER",
    UIParent,
    db.offHand.anchor.relPoint or "CENTER",
    db.offHand.anchor.x or 0,
    db.offHand.anchor.y or -220
  )

  ApplyBackdrop(offHandFrame, db.border)
  offHandBar:SetStatusBarTexture(GetTexturePath(db.texture))
  offHandBg:SetAlpha(db.bgAlpha or 0.35)
  offHandFrame:SetAlpha(db.alpha or 1)
  offHandBar:SetReverseFill(db.reverseFill and true or false)

  if db.spark then offHandSpark:Show() else offHandSpark:Hide() end
  if offHandFrame._hint then SetShownCompat(offHandFrame._hint, not db.locked) end

  -- Colors
  local r, g, b = 0.20, 1.00, 0.20
  if db.colorMode == "CLASS" then
    r, g, b = GetClassColor()
  else
    local c = db.customColor or { r = 0.2, g = 1.0, b = 0.2 }
    r, g, b = c.r or 0.2, c.g or 1.0, c.b or 0.2
  end
  mainHandBar:SetStatusBarColor(r, g, b, 1)
  mainHandBg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 1)
  offHandBar:SetStatusBarColor(r, g, b, 1)
  offHandBg:SetVertexColor(r * 0.18, g * 0.18, b * 0.18, 1)
end

local function StartFade(isOffHand, toAlpha, duration)
  if isOffHand then
    if not offHandFrame then return end
    ohFadeFrom = offHandFrame:GetAlpha() or 1
    ohFadeTo = toAlpha or 0
    ohFadeStartAt = GetTime()
    ohFadeDuration = duration or 0.25
  else
    if not mainHandFrame then return end
    mhFadeFrom = mainHandFrame:GetAlpha() or 1
    mhFadeTo = toAlpha or 0
    mhFadeStartAt = GetTime()
    mhFadeDuration = duration or 0.25
  end
end

local function PlayerInCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return not not UnitAffectingCombat("player") end
  return false
end

local function ShouldBeVisible(db, active)
  if db.preview then return true end
  if db.onlyInCombat and not PlayerInCombat() then return false end
  if db.hideOutOfCombat and not PlayerInCombat() then return false end
  return active
end

local function UpdateWeaponSpeeds()
  -- Get main hand speed
  local mhSpeed = UnitAttackSpeed("player")
  if mhSpeed and mhSpeed > 0 then
    mainHandSpeed = mhSpeed
  end

  -- Get off hand speed (second return value)
  local _, ohSpeed = UnitAttackSpeed("player")
  if ohSpeed and ohSpeed > 0 then
    offHandSpeed = ohSpeed
  else
    offHandSpeed = 0
  end
end

local function UpdateVisual(db)
  if not mainHandFrame or not offHandFrame then return end

  local now = GetTime()

  -- Update weapon speeds (in case they changed from buffs/debuffs)
  UpdateWeaponSpeeds()

  -- Main Hand logic
  local mhActive = mainHandActive
  if mhActive then
    if mainHandSpeed <= 0 or (now >= mainHandNext) then
      mainHandActive = false
      mhActive = false
    end
  end

  -- Off Hand logic
  local ohActive = offHandActive
  if ohActive then
    if offHandSpeed <= 0 or (now >= offHandNext) then
      offHandActive = false
      ohActive = false
    end
  end

  -- Preview overrides
  if db.preview then
    local fakeDur = 2.0
    local fakeStart = now - (now % fakeDur)
    mainHandNext = fakeStart + fakeDur
    mainHandSpeed = fakeDur
    mainHandActive = true
    mhActive = true

    if db.showOffHand then
      offHandNext = fakeStart + fakeDur
      offHandSpeed = fakeDur
      offHandActive = true
      ohActive = true
    end
  end

  -- Main Hand visibility
  local mhWantVisible = ShouldBeVisible(db, mhActive)

  if mhWantVisible and not mainHandFrame:IsShown() then
    mainHandFrame:Show()
    mainHandFrame:SetAlpha(db.alpha or 1)
    mhFadeStartAt = 0
  elseif (not mhWantVisible) and mainHandFrame:IsShown() then
    mainHandFrame:Hide()
  end

  if mainHandFrame:IsShown() then
    if not mhActive then
      mainHandBar:SetValue(0)
      if db.spark then mainHandSpark:Hide() end

      if db.fadeOut and not db.preview then
        if mhFadeEndAt == 0 then
          mhFadeEndAt = now + (db.fadeDelay or 0.15)
        end
        if mhFadeEndAt > 0 and now >= mhFadeEndAt then
          if mhFadeStartAt == 0 then
            StartFade(false, 0, db.fadeDuration or 0.25)
          end
        end
      end
    else
      mainHandFrame:SetAlpha(db.alpha or 1)
      mhFadeEndAt = 0
      mhFadeStartAt = 0

      local elapsed = now - (mainHandNext - mainHandSpeed)
      local t = elapsed / ((mainHandSpeed > 0) and mainHandSpeed or 1)
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end
      mainHandBar:SetValue(t)

      if db.spark then
        local w = mainHandBar:GetWidth()
        local x = w * t
        mainHandSpark:ClearAllPoints()
        mainHandSpark:SetPoint("CENTER", mainHandBar, "LEFT", x, 0)
        mainHandSpark:Show()
      end
    end

    if mhFadeStartAt and mhFadeStartAt > 0 and mhFadeDuration and mhFadeDuration > 0 then
      local tt = (now - mhFadeStartAt) / mhFadeDuration
      if tt >= 1 then
        mainHandFrame:SetAlpha(mhFadeTo)
        mhFadeStartAt = 0
        if mhFadeTo <= 0.01 then
          mainHandFrame:Hide()
        end
      else
        local a = mhFadeFrom + (mhFadeTo - mhFadeFrom) * tt
        mainHandFrame:SetAlpha(a)
      end
    end
  end

  -- Off Hand visibility
  if not db.showOffHand or offHandSpeed <= 0 then
    offHandFrame:Hide()
    return
  end

  local ohWantVisible = ShouldBeVisible(db, ohActive)

  if ohWantVisible and not offHandFrame:IsShown() then
    offHandFrame:Show()
    offHandFrame:SetAlpha(db.alpha or 1)
    ohFadeStartAt = 0
  elseif (not ohWantVisible) and offHandFrame:IsShown() then
    offHandFrame:Hide()
  end

  if offHandFrame:IsShown() then
    if not ohActive then
      offHandBar:SetValue(0)
      if db.spark then offHandSpark:Hide() end

      if db.fadeOut and not db.preview then
        if ohFadeEndAt == 0 then
          ohFadeEndAt = now + (db.fadeDelay or 0.15)
        end
        if ohFadeEndAt > 0 and now >= ohFadeEndAt then
          if ohFadeStartAt == 0 then
            StartFade(true, 0, db.fadeDuration or 0.25)
          end
        end
      end
    else
      offHandFrame:SetAlpha(db.alpha or 1)
      ohFadeEndAt = 0
      ohFadeStartAt = 0

      local elapsed = now - (offHandNext - offHandSpeed)
      local t = elapsed / ((offHandSpeed > 0) and offHandSpeed or 1)
      if t < 0 then t = 0 end
      if t > 1 then t = 1 end
      offHandBar:SetValue(t)

      if db.spark then
        local w = offHandBar:GetWidth()
        local x = w * t
        offHandSpark:ClearAllPoints()
        offHandSpark:SetPoint("CENTER", offHandBar, "LEFT", x, 0)
        offHandSpark:Show()
      end
    end

    if ohFadeStartAt and ohFadeStartAt > 0 and ohFadeDuration and ohFadeDuration > 0 then
      local tt = (now - ohFadeStartAt) / ohFadeDuration
      if tt >= 1 then
        offHandFrame:SetAlpha(ohFadeTo)
        ohFadeStartAt = 0
        if ohFadeTo <= 0.01 then
          offHandFrame:Hide()
        end
      else
        local a = ohFadeFrom + (ohFadeTo - ohFadeFrom) * tt
        offHandFrame:SetAlpha(a)
      end
    end
  end
end

local function OnSwing(isOffHand)
  local now = GetTime()
  UpdateWeaponSpeeds()

  if isOffHand then
    if offHandSpeed > 0 then
      offHandNext = now + offHandSpeed
      offHandActive = true
      ohFadeEndAt = 0
      ohFadeStartAt = 0
    end
  else
    if mainHandSpeed > 0 then
      mainHandNext = now + mainHandSpeed
      mainHandActive = true
      mhFadeEndAt = 0
      mhFadeStartAt = 0
    end
  end
end

local function Apply()
  EnsureDriver()
  EnsureFrames()

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
    driver:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    driver:RegisterEvent("UNIT_INVENTORY_CHANGED")

    driver:SetScript("OnEvent", function(self, event, ...)
      if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        UpdateLayout(GetDB())
        UpdateWeaponSpeeds()
        return
      end

      if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Combat state changed, refresh immediately
        return
      end

      if event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
          UpdateWeaponSpeeds()
        end
        return
      end

      if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subevent, _, sourceGUID = CombatLogGetCurrentEventInfo()
        
        -- Only track player's swings
        if sourceGUID ~= UnitGUID("player") then return end
        
        if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
          -- Determine if this is off-hand based on timing
          -- If we have an off-hand weapon, track alternating swings
          local now = GetTime()
          local isOffHand = false
          
          -- If we have both weapons, use timing to determine which hand
          if offHandSpeed > 0 and mainHandSpeed > 0 then
            -- Check which swing is expected next (within threshold)
            local threshold = 0.05  -- 50ms tolerance
            if mainHandActive and offHandActive then
              -- Both active, pick the one that's about to finish
              local mhRemain = mainHandNext - now
              local ohRemain = offHandNext - now
              
              -- If off-hand is within threshold, it's likely the off-hand
              if ohRemain <= threshold and ohRemain < mhRemain then
                isOffHand = true
              elseif mhRemain > threshold and ohRemain < mhRemain then
                isOffHand = true
              end
            elseif offHandActive then
              -- Only off-hand is active
              local ohRemain = offHandNext - now
              if ohRemain <= threshold then
                isOffHand = true
              end
            end
          end
          
          OnSwing(isOffHand)
        end
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
      mainHandFrame:Show()
      if db.showOffHand then
        offHandFrame:Show()
      end
    else
      mainHandFrame:Hide()
      offHandFrame:Hide()
    end
  else
    if mainHandFrame then mainHandFrame:Hide() end
    if offHandFrame then offHandFrame:Hide() end
    driver:Hide()
  end
end

ETBC.ApplyBus:Register("swingtimer", Apply)
ETBC.ApplyBus:Register("general", Apply)
