-- Modules/MinimapPlus/BlizzardAdapters.lua
-- EnhanceTBC - MinimapPlus Blizzard frame/style adapter helpers (internal).

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = ETBC.Modules.MinimapPlus
if not mod then return end

mod.Internal = mod.Internal or {}
local H = {}
mod.Internal.BlizzardAdapters = H

local function GetShared()
  return mod.Internal and mod.Internal.Shared
end

local function GetState()
  local shared = GetShared()
  return shared and shared.state
end

local function CallGetDB()
  local shared = GetShared()
  if shared and type(shared.GetDB) == "function" then
    return shared.GetDB()
  end
  return nil
end

local function IsAddonLoadedCompat(addonName)
  local shared = GetShared()
  if shared and type(shared.IsAddonLoadedCompat) == "function" then
    return shared.IsAddonLoadedCompat(addonName)
  end
  return false
end

local function IsFeatureEnabled()
  local shared = GetShared()
  if shared and type(shared.IsFeatureEnabled) == "function" then
    return shared.IsFeatureEnabled()
  end
  return false
end

local function RunSetPointGuard(lockKey, fn)
  local shared = GetShared()
  if shared and type(shared.RunSetPointGuard) == "function" then
    shared.RunSetPointGuard(lockKey, fn)
    return
  end
  fn()
end

local function ApplyFont(fs, size)
  local shared = GetShared()
  if shared and type(shared.ApplyFont) == "function" then
    shared.ApplyFont(fs, size)
  end
end

local function GetConst(name, fallback)
  local shared = GetShared()
  local value = shared and shared[name]
  if value == nil then return fallback end
  return value
end

local function StyleTimeManagerClockButton()
  local state = GetState()
  local CLOCK_POINT_FLAG = GetConst("CLOCK_POINT_FLAG", "etbc_clock_button")
  if not state then return end
  if not IsAddonLoadedCompat("Blizzard_TimeManager") then return end
  if not IsFeatureEnabled() then return end

  if TimeManagerClockButton then
    TimeManagerClockButton:SetSize(35, 20)
    TimeManagerClockButton:ClearAllPoints()
    TimeManagerClockButton:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 6, CLOCK_POINT_FLAG)
    if not state.clockPointHooked then
      hooksecurefunc(TimeManagerClockButton, "SetPoint", function(frame, _, _, _, _, _, flag)
        if flag == CLOCK_POINT_FLAG then return end
        if not IsFeatureEnabled() then return end
        RunSetPointGuard("inClockPointHook", function()
          frame:ClearAllPoints()
          frame:SetPoint("BOTTOM", Minimap, "BOTTOM", 0, 6, CLOCK_POINT_FLAG)
        end)
      end)
      state.clockPointHooked = true
    end

    local label = select(2, TimeManagerClockButton:GetRegions())
    if label and label.SetJustifyH then
      label:SetJustifyH("CENTER")
      ApplyFont(label, 12)
    end

    for i, region in pairs({ TimeManagerClockButton:GetRegions() }) do
      if i ~= 2 and region and region.Hide then
        region:Hide()
      end
    end

    if StopwatchFrame and StopwatchFrame.GetRegions then
      for _, region in pairs({ StopwatchFrame:GetRegions() }) do
        if region and region.SetVertexColor then
          region:SetVertexColor(0.2, 0.2, 0.2)
        end
      end
    end
  end

  if TimeManagerFrame then
    TimeManagerFrame:ClearAllPoints()
    TimeManagerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -10, -215)
  end
end

local function MoveMinimapLFGButton()
  local state = GetState()
  local LFG_POINT_FLAG = GetConst("LFG_POINT_FLAG", "etbc_lfg_button")
  if not state then return end
  if not IsAddonLoadedCompat("Blizzard_GroupFinder_VanillaStyle") then return end
  if not LFGMinimapFrame then return end

  LFGMinimapFrame:SetScale(0.85)
  LFGMinimapFrame:ClearAllPoints()
  LFGMinimapFrame:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 1.5, 85, LFG_POINT_FLAG)

  if not state.lfgPointHooked then
    hooksecurefunc(LFGMinimapFrame, "SetPoint", function(self, _, _, _, _, _, flag)
      if flag == LFG_POINT_FLAG then return end
      RunSetPointGuard("inLfgHook", function()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", 1.5, 85, LFG_POINT_FLAG)
      end)
    end)
    state.lfgPointHooked = true
  end
end

local function StyleBattlefieldMinimap()
  if not IsAddonLoadedCompat("Blizzard_BattlefieldMap") then return end
  if not BattlefieldMapFrame then return end

  BattlefieldMapFrame:SetScale(0.84)

  if BattlefieldMapFrame.BorderFrame and BattlefieldMapFrame.BorderFrame.GetRegions then
    for _, region in pairs({ BattlefieldMapFrame.BorderFrame:GetRegions() }) do
      if region and region.SetVertexColor then
        region:SetVertexColor(0.2, 0.2, 0.2)
      end
    end
  end
end

local function MoveQuestWatchFrame()
  local state = GetState()
  local RIGHT_MANAGED_FLAG = GetConst("RIGHT_MANAGED_FLAG", "etbc_ui_parent_right_managed_frame")
  if not state then return end

  local frame = _G["UIParentRightManagedFrameContainer"]
  if not frame then return end

  frame:SetScale(0.9)
  if not state.questWatchHooked then
    hooksecurefunc(frame, "SetPoint", function(self, posA, anchor, posB, _, _, flag)
      if not IsFeatureEnabled() then return end
      if flag == RIGHT_MANAGED_FLAG then return end
      RunSetPointGuard("inRightManagedHook", function()
        self:ClearAllPoints()
        self:SetPoint(posA, anchor, posB, -90, -255, RIGHT_MANAGED_FLAG)
      end)
    end)
    state.questWatchHooked = true
  end
end

local function UpdateMinimapMask()
  local db = CallGetDB()
  local SQUARE_MASK_TEXTURE = GetConst("SQUARE_MASK_TEXTURE", "Interface\\ChatFrame\\ChatFrameBackground")
  local ROUND_MASK_TEXTURE = GetConst("ROUND_MASK_TEXTURE", "Textures\\MinimapMask")
  if not Minimap or not Minimap.SetMaskTexture then return end
  if not db then return end

  if db.enabled and db.square_mask then
    Minimap:SetMaskTexture(SQUARE_MASK_TEXTURE)
  else
    Minimap:SetMaskTexture(ROUND_MASK_TEXTURE)
  end
end

H.StyleTimeManagerClockButton = StyleTimeManagerClockButton
H.MoveMinimapLFGButton = MoveMinimapLFGButton
H.StyleBattlefieldMinimap = StyleBattlefieldMinimap
H.MoveQuestWatchFrame = MoveQuestWatchFrame
H.UpdateMinimapMask = UpdateMinimapMask
