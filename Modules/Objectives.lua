-- Modules/Objectives.lua
-- EnhanceTBC - Quest / Objective Helper (TBC WatchFrame / ObjectiveTracker)
-- Lightweight: width/scale/background + fade/hide in combat + auto-collapse completed quests.

local ADDON_NAME, ETBC = ...
local L = LibStub("AceLocale-3.0"):GetLocale("EnhanceTBC")
ETBC.Modules = ETBC.Modules or {}
local mod = {}
ETBC.Modules.Objectives = mod

local driver
local hooked = false
local cachedDB  -- Module-level cache for DB, updated by Apply()
local moverRegistered = false

local function GetDB()
  ETBC.db.profile.objectives = ETBC.db.profile.objectives or {}
  local db = ETBC.db.profile.objectives

  if db.enabled == nil then db.enabled = true end

  if db.hideInCombat == nil then db.hideInCombat = false end
  if db.fadeInCombat == nil then db.fadeInCombat = true end
  if db.combatAlpha == nil then db.combatAlpha = 0.20 end
  if db.fadeTime == nil then db.fadeTime = 0.12 end

  if db.width == nil then db.width = 300 end
  if db.clampToScreen == nil then db.clampToScreen = true end

  if db.background == nil then db.background = true end
  if db.bgAlpha == nil then db.bgAlpha = 0.35 end
  if db.borderAlpha == nil then db.borderAlpha = 0.95 end
  if db.scale == nil then db.scale = 1.00 end

  if db.fontScale == nil then db.fontScale = 1.00 end

  if db.autoCollapseCompleted == nil then db.autoCollapseCompleted = true end
  if db.onlyCollapseInDungeons == nil then db.onlyCollapseInDungeons = false end

  return db
end

local function EnsureDriver()
  if driver then return end
  driver = CreateFrame("Frame", "EnhanceTBC_ObjectivesDriver", UIParent)
end

local function VisibilityAllowed(db)
  local vis = ETBC.Modules and ETBC.Modules.Visibility
  if vis and vis.Allowed then
    return vis:Allowed("objectives")
  end
  return true
end

local function RegisterMover(frame)
  if moverRegistered then return end
  if not (ETBC.Mover and ETBC.Mover.Register) then return end
  if not frame or not frame.GetPoint then return end

  local point, rel, relPoint, x, y = frame:GetPoint(1)
  local relName = "UIParent"
  if rel and rel.GetName and rel:GetName() then
    relName = rel:GetName()
  end

  ETBC.Mover:Register("Objectives", frame, {
    name = "Objectives",
    default = {
      point = point or "TOPRIGHT",
      rel = relName,
      relPoint = relPoint or "TOPRIGHT",
      x = x or -60,
      y = y or -220,
    },
  })

  moverRegistered = true
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
  if not frame then return end
  
  -- Create backdrop frame if it doesn't exist
  if not frame._etbcBG then
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
    end
  end
  
  -- Update colors (allow re-application even if backdrop exists)
  local bg = frame._etbcBG
  if bg and bg.SetBackdropColor and bg.SetBackdropBorderColor then
    bg:SetBackdropColor(0, 0, 0, bgA or 0.35)
    bg:SetBackdropBorderColor(0.12, 0.20, 0.12, borderA or 0.95)
    bg:Show()
  end
end


local function UpdateBackdrop(frame, db)
  if not frame then return end

  if db.background then
    SetBackdrop(frame, db.bgAlpha or 0.35, db.borderAlpha or 0.95)
    if frame._etbcBG then
      frame._etbcBG:Show()
    end
  else
    if frame._etbcBG then frame._etbcBG:Hide() end
  end
end

local function ScaleFonts_WatchFrame(scale)
  if not _G.WatchFrameLines then return end
  scale = tonumber(scale) or 1.0

  for i = 1, #_G.WatchFrameLines do
    local fs = _G.WatchFrameLines[i]
    if fs and type(fs) == "table" and fs.GetFont and fs.SetFont then
      local font, size, flags = fs:GetFont()
      if font and size and tonumber(size) then
        fs._etbcBaseFont = fs._etbcBaseFont or font
        fs._etbcBaseFontFlags = fs._etbcBaseFontFlags or flags
        if not fs._etbcBaseFontSize then
          fs._etbcBaseFontSize = size
        end

        local baseSize = tonumber(fs._etbcBaseFontSize) or size
        local targetSize = baseSize * scale
        if targetSize < 1 then targetSize = 1 end
        local ok, err = pcall(fs.SetFont, fs, fs._etbcBaseFont, targetSize, fs._etbcBaseFontFlags)
        if not ok and ETBC.Debug then
          ETBC:Debug("Failed to set font on WatchFrame line " .. i .. ": " .. tostring(err))
        end
      end
    end
  end
end

local function ApplyLayout(frame, kind, db)
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

  UpdateBackdrop(frame, db)
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

local function UpdateFade(frame, db)
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

local function ApplyCombatVisibility(frame, db)
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
-- Note: TBC WatchFrame doesn't have per-quest collapse API like later expansions
-- This is a placeholder for potential future implementation
local function AutoCollapseCompleted(db)
  if not db.enabled or not db.autoCollapseCompleted then return end
  if db.onlyCollapseInDungeons and not IsInDungeonOrRaid() then return end

  -- TBC WatchFrame API doesn't support auto-collapsing individual completed quests
  -- In later expansions, this would iterate tracked quests and collapse completed ones
  -- For now, this is intentionally left as a no-op
end

local function HookTracker(frame, kind)
  if hooked then return end
  hooked = true

  EnsureDriver()

  -- Only run OnUpdate when there's an active fade
  driver:SetScript("OnUpdate", function()
    if not frame or not frame:IsShown() then return end
    if not frame._etbcFade or not frame._etbcFade.active then return end
    if not cachedDB then cachedDB = GetDB() end
    UpdateFade(frame, cachedDB)
  end)

  -- Combat visibility
  driver:RegisterEvent("PLAYER_REGEN_DISABLED")
  driver:RegisterEvent("PLAYER_REGEN_ENABLED")
  driver:RegisterEvent("PLAYER_ENTERING_WORLD")
  driver:SetScript("OnEvent", function()
    if not cachedDB then cachedDB = GetDB() end
    ApplyCombatVisibility(frame, cachedDB)
  end)

  -- WatchFrame updates
  if kind == "WATCHFRAME" then
    if type(_G.WatchFrame_Update) == "function" then
      hooksecurefunc("WatchFrame_Update", function()
        if not cachedDB then cachedDB = GetDB() end
        if not cachedDB.enabled then return end
        ApplyLayout(frame, kind, cachedDB)
        AutoCollapseCompleted(cachedDB)
      end)
    end
  else
    -- ObjectiveTracker: hook any safe update if exists
    if type(_G.ObjectiveTracker_Update) == "function" then
      hooksecurefunc("ObjectiveTracker_Update", function()
        if not cachedDB then cachedDB = GetDB() end
        if not cachedDB.enabled then return end
        ApplyLayout(frame, kind, cachedDB)
      end)
    end
  end
end

local function Apply()
  EnsureDriver()

  local db = GetDB()
  cachedDB = db  -- Update module-level cache so closures use latest settings
  local generalEnabled = ETBC.db.profile.general and ETBC.db.profile.general.enabled
  local allowed = VisibilityAllowed(db)

  local frame, kind = FindTracker()
  if not frame then return end

  if not (generalEnabled and db.enabled and allowed) then
    -- Soft reset
    frame:SetAlpha(1)
    frame:Show()
    StopFade(frame)
    if frame._etbcBG then frame._etbcBG:Hide() end
    return
  end

  RegisterMover(frame)
  if ETBC.Mover and ETBC.Mover.Apply then
    ETBC.Mover:Apply("Objectives")
  end

  HookTracker(frame, kind)
  ApplyLayout(frame, kind, db)
  ApplyCombatVisibility(frame, db)
end

ETBC.ApplyBus:Register("objectives", Apply)
ETBC.ApplyBus:Register("general", Apply)
