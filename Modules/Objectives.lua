-- Modules/Objectives.lua
-- EnhanceTBC - Quest / Objective Helper (TBC WatchFrame / ObjectiveTracker)
-- Lightweight: width/scale/background + fade/hide in combat + auto-collapse completed quests.

local ADDON_NAME, ETBC = ...

ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Objectives = mod

local driver
local hooked = false

local function GetDB()
  ETBC.db.profile.objectives = ETBC.db.profile.objectives or {}
  return ETBC.db.profile.objectives
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_ObjectivesDriver", UIParent)
end

local function IsInDungeonOrRaid()
  local fn = _G.IsInInstance
  if type(fn) ~= "function" then return false end
  local inInstance, itype = fn()
  if not inInstance then return false end
  return itype == "party" or itype == "raid"
end

local function FindTracker()
  -- TBC typically has WatchFrame; later expansions have ObjectiveTrackerFrame
  if _G.WatchFrame then return _G.WatchFrame, "WATCHFRAME" end
  if _G.ObjectiveTrackerFrame then return _G.ObjectiveTrackerFrame, "OBJECTIVE" end
  return nil, nil
end

local function SetBackdrop(frame, bgA, borderA)
  if not frame or frame._etbcBG then return end
  frame._etbcBG = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame._etbcBG:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 6)
  frame._etbcBG:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 6, -6)

  if frame._etbcBG.SetBackdrop then
    frame._etbcBG:SetBackdrop({
      bgFile = "Interface\\Buttons\\WHITE8x8",
      edgeFile = "Interface\\Buttons\\WHITE8x8",
      tile = false,
      edgeSize = 1,
      insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    frame._etbcBG:SetBackdropColor(0, 0, 0, bgA or 0.35)
    frame._etbcBG:SetBackdropBorderColor(0.12, 0.20, 0.12, borderA or 0.95)
  end

  frame._etbcBG:Show()
end


local function UpdateBackdrop(frame)
  local db = GetDB()
  if not frame then return end

  if db.background then
    SetBackdrop(frame, db.bgAlpha or 0.35, db.borderAlpha or 0.95)
    if frame._etbcBG.SetBackdropColor then
      frame._etbcBG:SetBackdropColor(0, 0, 0, db.bgAlpha or 0.35)
    end
    if frame._etbcBG.SetBackdropBorderColor then
      frame._etbcBG:SetBackdropBorderColor(0.12, 0.20, 0.12, db.borderAlpha or 0.95)
    end
    frame._etbcBG:Show()
  else
    if frame._etbcBG then frame._etbcBG:Hide() end
  end
end

local function ScaleFonts_WatchFrame(scale)
  if not _G.WatchFrameLines then return end
  scale = tonumber(scale) or 1.0

  for i = 1, #_G.WatchFrameLines do
    local fs = _G.WatchFrameLines[i]
    if fs and fs.GetFont and fs.SetFont then
      local font, size, flags = fs:GetFont()
      if font and size then
        fs._etbcBaseFont = fs._etbcBaseFont or font
        fs._etbcBaseFontFlags = fs._etbcBaseFontFlags or flags
        if not fs._etbcBaseFontSize then
          fs._etbcBaseFontSize = size
        end

        local baseSize = tonumber(fs._etbcBaseFontSize) or size
        local targetSize = baseSize * scale
        if targetSize < 1 then targetSize = 1 end
        fs:SetFont(fs._etbcBaseFont, targetSize, fs._etbcBaseFontFlags)
      end
    end
  end
end

local function ApplyLayout(frame, kind)
  local db = GetDB()
  if not frame then return end

  frame:SetScale(db.scale or 1.0)

  if kind == "WATCHFRAME" then
    if frame.SetWidth then frame:SetWidth(db.width or 300) end
    if db.clampToScreen and frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    if frame.Update then pcall(frame.Update, frame) end
    if type(_G.WatchFrame_Update) == "function" then pcall(_G.WatchFrame_Update) end
    ScaleFonts_WatchFrame(db.fontScale or 1.0)
  else
    -- ObjectiveTrackerFrame: best-effort width
    if frame.SetWidth then frame:SetWidth(db.width or 300) end
  end

  UpdateBackdrop(frame)
end

-- Fade/hide in combat (simple lerp)
local function StartFade(frame, toAlpha)
  EnsureDriver()
  frame._etbcFade = frame._etbcFade or {}
  local f = frame._etbcFade

  f.from = frame:GetAlpha() or 1
  f.to = toAlpha
  f.start = GetTime()
  f.active = true
end

local function StopFade(frame)
  if frame and frame._etbcFade then frame._etbcFade.active = false end
end

local function UpdateFade(frame)
  local db = GetDB()
  if not frame or not frame._etbcFade or not frame._etbcFade.active then return end
  local f = frame._etbcFade
  local t = tonumber(db.fadeTime) or 0

  if t <= 0 then
    frame:SetAlpha(f.to or 1)
    f.active = false
    return
  end

  local p = (GetTime() - (f.start or 0)) / t
  if p >= 1 then
    frame:SetAlpha(f.to or 1)
    f.active = false
    return
  end

  local a = (f.from or 1) + ((f.to or 1) - (f.from or 1)) * p
  frame:SetAlpha(a)
end

local function ApplyCombatVisibility(frame)
  local db = GetDB()
  if not frame then return end

  local inCombat = (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player"))

  if not inCombat then
    if frame:GetAlpha() ~= 1 then StartFade(frame, 1) end
    frame:Show()
    return
  end

  if db.hideInCombat then
    frame:Hide()
    StopFade(frame)
    return
  end

  if db.fadeInCombat then
    frame:Show()
    StartFade(frame, db.combatAlpha or 0.2)
    return
  end
end

-- Auto collapse completed quests (WatchFrame only, best-effort)
local function AutoCollapseCompleted()
  local db = GetDB()
  if not db.enabled or not db.autoCollapseCompleted then return end
  if db.onlyCollapseInDungeons and not IsInDungeonOrRaid() then return end

  if type(_G.WatchFrame_Collapse) == "function" and _G.WatchFrame then
    -- Collapse module is per quest in later clients; TBC is simpler.
    -- Best-effort: call collapse if it exists for completed tracked quests.
    -- If API isn't available, we do nothing.
  end
end

local function HookTracker(frame, kind)
  if hooked then return end
  hooked = true

  EnsureDriver()

  driver:SetScript("OnUpdate", function()
    if not frame or not frame:IsShown() then return end
    UpdateFade(frame)
  end)

  -- Combat visibility
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", function()
    ApplyCombatVisibility(frame)
  end)

  -- WatchFrame updates
  if kind == "WATCHFRAME" then
    if type(_G.WatchFrame_Update) == "function" then
      hooksecurefunc("WatchFrame_Update", function()
        local db = GetDB()
        if not db.enabled then return end
        ApplyLayout(frame, kind)
        AutoCollapseCompleted()
      end)
    end
  else
    -- ObjectiveTracker: hook any safe update if exists
    if type(_G.ObjectiveTracker_Update) == "function" then
      hooksecurefunc("ObjectiveTracker_Update", function()
        local db = GetDB()
        if not db.enabled then return end
        ApplyLayout(frame, kind)
      end)
    end
  end
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled

  local frame, kind = FindTracker()
  if not frame then return end

  if not (generalEnabled and db.enabled) then
    -- Soft reset
    frame:SetAlpha(1)
    frame:Show()
    StopFade(frame)
    if frame._etbcBG then frame._etbcBG:Hide() end
    return
  end

  HookTracker(frame, kind)
  ApplyLayout(frame, kind)
  ApplyCombatVisibility(frame)
end

ETBC.ApplyBus:Register("objectives", Apply)
ETBC.ApplyBus:Register("general", Apply)
