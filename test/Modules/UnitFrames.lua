-- Modules/UnitFrames.lua
-- EnhanceTBC - UnitFrame Micro Enhancer (Blizzard frames)
-- Fix: Ensure font is set before any SetText calls to avoid "Font not set".

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.UnitFrames = mod

local driver
local pendingApply = false
local hooked = false
local bucketsRegistered = false

local orig = {
  sizes = {},     -- [frame] = { scale=, w=, h= }
  portraits = {}, -- [portrait] = shown?
}

local function GetDB()
  ETBC.db.profile.unitframes = ETBC.db.profile.unitframes or {}
  local db = ETBC.db.profile.unitframes

  if db.enabled == nil then db.enabled = true end
  if db.classColorHealth == nil then db.classColorHealth = true end
  if db.healthPercentText == nil then db.healthPercentText = true end
  if db.powerValueText == nil then db.powerValueText = false end
  if db.hidePortraits == nil then db.hidePortraits = false end

  if db.player == nil then db.player = true end
  if db.target == nil then db.target = true end
  if db.focus == nil then db.focus = true end
  if db.party == nil then db.party = false end

  if db.resize == nil then db.resize = true end
  if db.scale == nil then db.scale = 1.00 end

  if db.font == nil then db.font = "Friz Quadrata TT" end
  if db.fontSize == nil then db.fontSize = 11 end
  if db.outline == nil then db.outline = "OUTLINE" end
  if db.shadow == nil then db.shadow = true end
  if db.textColor == nil then db.textColor = { 1, 1, 1 } end

  if db.onlyShowTextWhenNotFull == nil then db.onlyShowTextWhenNotFull = true end

  if db.healthTextMode == nil then
    db.healthTextMode = db.healthPercentText and "PERCENT" or "NONE"
  end
  if db.powerTextMode == nil then
    db.powerTextMode = db.powerValueText and "VALUE" or "NONE"
  end

  if db.healthTextOffsetX == nil then db.healthTextOffsetX = 0 end
  if db.healthTextOffsetY == nil then db.healthTextOffsetY = 0 end
  if db.powerTextOffsetX == nil then db.powerTextOffsetX = 0 end
  if db.powerTextOffsetY == nil then db.powerTextOffsetY = 0 end

  if db.disableBlizzardStatusText == nil then db.disableBlizzardStatusText = true end

  return db
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_UnitFramesDriver", UIParent)
end

local function InCombat()
  if InCombatLockdown and InCombatLockdown() then return true end
  if UnitAffectingCombat then return UnitAffectingCombat("player") and true or false end
  return false
end

local function LSM_Fetch(kind, key, fallback)
  if ETBC.LSM and ETBC.LSM.Fetch then
    local ok, v = pcall(ETBC.LSM.Fetch, ETBC.LSM, kind, key)
    if ok and v then return v end
  end
  return fallback
end

local function GetFrameHealthBar(frame)
  if not frame or not frame.GetName then return nil end
  local name = frame:GetName()
  if not name then return nil end
  return _G[name .. "HealthBar"] or frame.healthbar or frame.healthBar
end

local function GetFrameManaBar(frame)
  if not frame or not frame.GetName then return nil end
  local name = frame:GetName()
  if not name then return nil end
  return _G[name .. "ManaBar"] or _G[name .. "PowerBar"] or frame.manabar or frame.manaBar
end

local function GetFramePortrait(frame)
  if not frame or not frame.GetName then return nil end
  local name = frame:GetName()
  if not name then return nil end
  return _G[name .. "Portrait"] or frame.portrait
end

local function StyleFontString(fs)
  local db = GetDB()
  if not fs or not fs.SetFont then return end

  local fontPath = LSM_Fetch("font", db.font, "Fonts\\FRIZQT__.TTF")
  local size = tonumber(db.fontSize) or 11
  local outline = db.outline or ""

  fs:SetFont(fontPath, size, outline)

  local c = db.textColor or { 1, 1, 1 }
  if fs.SetTextColor then fs:SetTextColor(c[1] or 1, c[2] or 1, c[3] or 1) end

  if db.shadow then
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
  else
    fs:SetShadowOffset(0, 0)
  end
end

local function EnsureText(bar, key, point, x, y, justify)
  if not bar then return nil end

  local fs = bar[key]
  if fs and fs.SetText then
    return fs
  end

  fs = bar:CreateFontString(nil, "OVERLAY")
  fs:SetPoint(point, bar, point, x or 0, y or 0)
  if justify and fs.SetJustifyH then fs:SetJustifyH(justify) end

  -- IMPORTANT: set font BEFORE any SetText calls
  bar[key] = fs
  StyleFontString(fs)
  fs:SetText("")
  fs:Hide()

  return fs
end

local function PositionText(fs, bar, point, x, y, justify)
  if not fs or not bar then return end
  fs:ClearAllPoints()
  fs:SetPoint(point, bar, point, x or 0, y or 0)
  if justify and fs.SetJustifyH then fs:SetJustifyH(justify) end
end

local function UnitIsPlayerClass(unit)
  if not unit or unit == "" then return nil end
  if not UnitIsPlayer or not UnitClass then return nil end
  if not UnitIsPlayer(unit) then return nil end
  local _, class = UnitClass(unit)
  return class
end

local function ApplyClassColor(bar, unit)
  local db = GetDB()
  if not (db.enabled and db.classColorHealth) then return end
  if not bar or not bar.SetStatusBarColor then return end

  local class = UnitIsPlayerClass(unit)
  if not class or not RAID_CLASS_COLORS or not RAID_CLASS_COLORS[class] then return end

  local c = RAID_CLASS_COLORS[class]
  bar:SetStatusBarColor(c.r, c.g, c.b)
end

local function RegisterManagedBar(unit, bar)
  mod._unitBars = mod._unitBars or {}
  mod._unitBars[unit] = mod._unitBars[unit] or {}
  table.insert(mod._unitBars[unit], bar)
end

local function RegisterManagedPowerBar(unit, bar)
  mod._unitPowerBars = mod._unitPowerBars or {}
  mod._unitPowerBars[unit] = mod._unitPowerBars[unit] or {}
  table.insert(mod._unitPowerBars[unit], bar)
end

local function ClearManagedBars()
  mod._unitBars = {}
  mod._unitPowerBars = {}
end

local function UpdateHealthTextForUnit(unit)
  local db = GetDB()
  if not db.enabled then return end

  local mode = db.healthTextMode or "NONE"
  if mode == "NONE" then
    local barsNone = mod._unitBars and mod._unitBars[unit]
    if barsNone then
      for _, bar in ipairs(barsNone) do
        if bar._etbcHealthText then bar._etbcHealthText:SetText(""); bar._etbcHealthText:Hide() end
      end
    end
    return
  end

  local bars = mod._unitBars and mod._unitBars[unit]
  if not bars then return end

  local cur = UnitHealth and UnitHealth(unit) or 0
  local maxv = UnitHealthMax and UnitHealthMax(unit) or 0
  if maxv <= 0 then
    for _, bar in ipairs(bars) do
      if bar._etbcHealthText then bar._etbcHealthText:SetText(""); bar._etbcHealthText:Hide() end
    end
    return
  end

  local pct = math.floor((cur / maxv) * 100 + 0.5)
  local show = true
  if db.onlyShowTextWhenNotFull and pct >= 100 then show = false end

  local text
  if mode == "PERCENT" then
    text = pct .. "%"
  elseif mode == "VALUE" then
    text = tostring(cur)
  elseif mode == "BOTH" then
    text = tostring(cur) .. " / " .. tostring(maxv) .. " (" .. pct .. "%)"
  else
    text = ""
  end

  for _, bar in ipairs(bars) do
    local fs = EnsureText(bar, "_etbcHealthText", "CENTER", 0, 0, "CENTER")
    if fs then
      StyleFontString(fs)

      PositionText(fs, bar, "CENTER", db.healthTextOffsetX or 0, db.healthTextOffsetY or 0, "CENTER")

      if show then
        fs:SetText(text)
        fs:Show()
      else
        fs:SetText("")
        fs:Hide()
      end
    end
  end
end

local function UpdatePowerTextForUnit(unit)
  local db = GetDB()
  if not db.enabled then return end

  local mode = db.powerTextMode or "NONE"
  if mode == "NONE" then
    local barsNone = mod._unitPowerBars and mod._unitPowerBars[unit]
    if barsNone then
      for _, bar in ipairs(barsNone) do
        if bar._etbcPowerText then bar._etbcPowerText:SetText(""); bar._etbcPowerText:Hide() end
      end
    end
    return
  end

  local bars = mod._unitPowerBars and mod._unitPowerBars[unit]
  if not bars then return end

  local cur = UnitPower and UnitPower(unit) or 0
  local maxv = UnitPowerMax and UnitPowerMax(unit) or 0
  if maxv <= 0 then
    for _, bar in ipairs(bars) do
      if bar._etbcPowerText then bar._etbcPowerText:SetText(""); bar._etbcPowerText:Hide() end
    end
    return
  end

  local pct = math.floor((cur / maxv) * 100 + 0.5)

  local text
  if mode == "PERCENT" then
    text = pct .. "%"
  elseif mode == "VALUE" then
    text = tostring(cur)
  elseif mode == "BOTH" then
    text = tostring(cur) .. " / " .. tostring(maxv) .. " (" .. pct .. "%)"
  else
    text = ""
  end

  for _, bar in ipairs(bars) do
    local fs = EnsureText(bar, "_etbcPowerText", "RIGHT", -4, 0, "RIGHT")
    if fs then
      StyleFontString(fs)
      PositionText(fs, bar, "RIGHT", (db.powerTextOffsetX or 0) - 4, db.powerTextOffsetY or 0, "RIGHT")
      fs:SetText(text)
      fs:Show()
    end
  end
end

local function StoreOriginalFrameSize(frame)
  if not frame or orig.sizes[frame] then return end
  orig.sizes[frame] = {
    scale = frame.GetScale and frame:GetScale() or 1,
    w = frame.GetWidth and frame:GetWidth() or nil,
    h = frame.GetHeight and frame:GetHeight() or nil,
  }
end

local function RestoreOriginalFrameSize(frame)
  local o = orig.sizes[frame]
  if not o or not frame then return end
  if frame.SetScale and o.scale then frame:SetScale(o.scale) end
  if frame.SetSize and o.w and o.h then frame:SetSize(o.w, o.h) end
end

local function ApplyFrameSizing(frame)
  local db = GetDB()
  if not (db.enabled and db.resize) then
    RestoreOriginalFrameSize(frame)
    return
  end

  if not frame or not frame.SetScale then return end
  StoreOriginalFrameSize(frame)

  local sc = tonumber(db.scale) or 1.0
  frame:SetScale(sc)

  if frame.SetSize then
    local o = orig.sizes[frame]
    if o and o.w and o.h then
      frame:SetSize(o.w, o.h)
    end
  end
end

local function ApplyPortrait(frame)
  local db = GetDB()
  if not frame then return end

  local portrait = GetFramePortrait(frame)
  if not portrait or not portrait.Show then return end

  if orig.portraits[portrait] == nil then
    orig.portraits[portrait] = portrait:IsShown() and true or false
  end

  if db.enabled and db.hidePortraits then
    portrait:Hide()
  else
    if orig.portraits[portrait] then portrait:Show() else portrait:Hide() end
  end
end

local function ApplyToUnitFrame(frame, unit, which)
  local db = GetDB()
  if not (db.enabled) then return end
  if which == "player" and not db.player then return end
  if which == "target" and not db.target then return end
  if which == "focus" and not db.focus then return end
  if which == "party" and not db.party then return end
  if not frame then return end

  if which ~= "party" then
    ApplyFrameSizing(frame)
  end

  ApplyPortrait(frame)

  local hb = GetFrameHealthBar(frame)
  if hb then
    if db.healthTextMode and db.healthTextMode ~= "NONE" then
      local fs = EnsureText(hb, "_etbcHealthText", "CENTER", 0, 0, "CENTER")
      StyleFontString(fs)
      RegisterManagedBar(unit, hb)
    else
      if hb._etbcHealthText then hb._etbcHealthText:SetText(""); hb._etbcHealthText:Hide() end
    end

    if db.classColorHealth then
      ApplyClassColor(hb, unit)
    end
  end

  local pb = GetFrameManaBar(frame)
  if pb then
    if db.powerTextMode and db.powerTextMode ~= "NONE" then
      local fs = EnsureText(pb, "_etbcPowerText", "RIGHT", -4, 0, "RIGHT")
      StyleFontString(fs)
      RegisterManagedPowerBar(unit, pb)
    else
      if pb._etbcPowerText then pb._etbcPowerText:SetText(""); pb._etbcPowerText:Hide() end
    end
  end
end

local blizzStatusText = nil

local function SaveBlizzardStatusText()
  if blizzStatusText then return end
  blizzStatusText = {
    statusTextDisplay = GetCVar("statusTextDisplay"),
    statusTextPercentage = GetCVar("statusTextPercentage"),
    statusText = GetCVar("statusText"),
    statusTextMana = GetCVar("statusTextMana"),
  }
end

local function ApplyBlizzardStatusText(db, enable)
  if not db.disableBlizzardStatusText then return end

  if enable then
    SaveBlizzardStatusText()
    pcall(SetCVar, "statusTextDisplay", "NONE")
    pcall(SetCVar, "statusTextPercentage", "0")
    pcall(SetCVar, "statusText", "0")
    pcall(SetCVar, "statusTextMana", "0")
    return
  end

  if blizzStatusText then
    if blizzStatusText.statusTextDisplay ~= nil then
      pcall(SetCVar, "statusTextDisplay", blizzStatusText.statusTextDisplay)
    end
    if blizzStatusText.statusTextPercentage ~= nil then
      pcall(SetCVar, "statusTextPercentage", blizzStatusText.statusTextPercentage)
    end
    if blizzStatusText.statusText ~= nil then pcall(SetCVar, "statusText", blizzStatusText.statusText) end
    if blizzStatusText.statusTextMana ~= nil then pcall(SetCVar, "statusTextMana", blizzStatusText.statusTextMana) end
    blizzStatusText = nil
  end
end

local function RefreshAll()
  ClearManagedBars()

  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then
    ApplyBlizzardStatusText(db, false)
    if _G.PlayerFrame then RestoreOriginalFrameSize(PlayerFrame); ApplyPortrait(PlayerFrame) end
    if _G.TargetFrame then RestoreOriginalFrameSize(TargetFrame); ApplyPortrait(TargetFrame) end
    if _G.FocusFrame then RestoreOriginalFrameSize(FocusFrame); ApplyPortrait(FocusFrame) end
    for i = 1, 4 do
      local f = _G["PartyMemberFrame" .. i]
      if f then ApplyPortrait(f) end
    end
    return
  end

  ApplyBlizzardStatusText(db, true)

  if _G.PlayerFrame then ApplyToUnitFrame(PlayerFrame, "player", "player") end
  if _G.TargetFrame then ApplyToUnitFrame(TargetFrame, "target", "target") end
  if _G.FocusFrame then ApplyToUnitFrame(FocusFrame, "focus", "focus") end

  for i = 1, 4 do
    local f = _G["PartyMemberFrame" .. i]
    if f then ApplyToUnitFrame(f, "party" .. i, "party") end
  end

  if db.healthTextMode and db.healthTextMode ~= "NONE" then
    UpdateHealthTextForUnit("player")
    UpdateHealthTextForUnit("target")
    UpdateHealthTextForUnit("focus")
    for i = 1, 4 do UpdateHealthTextForUnit("party" .. i) end
  end

  if db.powerTextMode and db.powerTextMode ~= "NONE" then
    UpdatePowerTextForUnit("player")
    UpdatePowerTextForUnit("target")
    UpdatePowerTextForUnit("focus")
    for i = 1, 4 do UpdatePowerTextForUnit("party" .. i) end
  end
end

local function QueueApply()
  pendingApply = true
  if InCombat() then
    EnsureDriver()
    driver:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  pendingApply = false
  RefreshAll()
end

local function HandleHealthBucket(units)
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then return end
  if type(units) ~= "table" then return end

  for unit in pairs(units) do
    if db.healthTextMode and db.healthTextMode ~= "NONE" then
      UpdateHealthTextForUnit(unit)
    end
    if db.classColorHealth then
      local bars = mod._unitBars and mod._unitBars[unit]
      if bars then
        for _, bar in ipairs(bars) do
          ApplyClassColor(bar, unit)
        end
      end
    end
  end
end

local function HandlePowerBucket(units)
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  if not (generalEnabled and db.enabled) then return end
  if type(units) ~= "table" then return end

  if db.powerTextMode and db.powerTextMode ~= "NONE" then
    for unit in pairs(units) do
      UpdatePowerTextForUnit(unit)
    end
  end
end

local function EnsureHooks()
  if hooked then return end
  hooked = true

  EnsureDriver()
  driver:UnregisterAllEvents()
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:RegisterEvent("PLAYER_TARGET_CHANGED")
  driver:RegisterEvent("PLAYER_FOCUS_CHANGED")
  driver:RegisterEvent("GROUP_ROSTER_UPDATE")

  if not bucketsRegistered and ETBC and ETBC.RegisterBucketEvent then
    ETBC:RegisterBucketEvent({ "UNIT_HEALTH", "UNIT_MAXHEALTH" }, 0.08, HandleHealthBucket)
    ETBC:RegisterBucketEvent({ "UNIT_POWER_UPDATE", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }, 0.08, HandlePowerBucket)
    bucketsRegistered = true
  else
    driver:RegisterEvent("UNIT_HEALTH")
    driver:RegisterEvent("UNIT_MAXHEALTH")
    driver:RegisterEvent("UNIT_POWER_UPDATE")
    driver:RegisterEvent("UNIT_MAXPOWER")
    driver:RegisterEvent("UNIT_DISPLAYPOWER")
  end

  driver:RegisterEvent("PLAYER_REGEN_ENABLED")

  driver:SetScript("OnEvent", function(_, event, arg1)
    local db = GetDB()
    local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
    if not (generalEnabled and db.enabled) then
      if event == "PLAYER_ENTERING_WORLD" then
        RefreshAll()
      end
      return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
      QueueApply()
      return
    end

    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
      QueueApply()
      return
    end

    if event == "PLAYER_REGEN_ENABLED" then
      if pendingApply then
        pendingApply = false
        RefreshAll()
      end
      return
    end

    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
      if db.healthTextMode and db.healthTextMode ~= "NONE" and arg1 then
        UpdateHealthTextForUnit(arg1)
      end
      if db.classColorHealth and arg1 then
        local bars = mod._unitBars and mod._unitBars[arg1]
        if bars then
          for _, bar in ipairs(bars) do
            ApplyClassColor(bar, arg1)
          end
        end
      end
      return
    end

    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
      if db.powerTextMode and db.powerTextMode ~= "NONE" and arg1 then
        UpdatePowerTextForUnit(arg1)
      end
      return
    end
  end)
end

local function Apply()
  EnsureHooks()
  QueueApply()
end

ETBC.ApplyBus:Register("unitframes", Apply)
ETBC.ApplyBus:Register("general", Apply)
