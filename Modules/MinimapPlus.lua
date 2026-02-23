-- Modules/MinimapPlus.lua
-- EnhanceTBC - Minimap styling, info rows, and addon button sink.

local _, ETBC = ...
ETBC.Modules = ETBC.Modules or {}

local mod = {}
ETBC.Modules.MinimapPlus = mod
mod.Internal = mod.Internal or {}
mod.Internal.Shared = mod.Internal.Shared or {}

local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)

local MINIMAP_SIZE = 165
local ROUND_MASK_TEXTURE = "Textures\\MinimapMask"

local SQUARE_MASK_TEXTURE = "Interface\\ChatFrame\\ChatFrameBackground"
local MINIMAP_CONTAINER_FLAG = "etbc_minimap_container"
local RIGHT_MANAGED_FLAG = "etbc_ui_parent_right_managed_frame"
local TRACKING_POINT_FLAG = "etbc_tracking_button"
local LFG_POINT_FLAG = "etbc_lfg_button"
local ZONE_TEXT_POINT_FLAG = "etbc_zone_text_button"
local CLOCK_POINT_FLAG = "etbc_clock_button"
local TRACKING_NONE_TEXTURE = "Interface\\Minimap\\Tracking\\None"

local SINK_ICON_SIZE = 18
local SINK_ICON_SPACING = 4
local SINK_PADDING = 6
local SINK_MIN_WIDTH = 104
local SINK_MIN_HEIGHT = 32
local SINK_TRACKING_ROW_HEIGHT = 16

local state = {
  styled = false,
  containerHooked = false,
  zoneTextPointHooked = false,
  clockPointHooked = false,
  gameTimeShowHooked = false,
  questWatchHooked = false,
  trackingPointHooked = false,
  lfgPointHooked = false,
  toggleButtonShow = nil,
  eventFrame = nil,
  performanceFrame = nil,
  iconsFrame = nil,
  sinkFrame = nil,
  sinkDragHandle = nil,
  sinkManaged = {},
  msTicker = nil,
  fpsTicker = nil,
  friendsTicker = nil,
  guildTicker = nil,
  sinkScanTicker = nil,
  sinkEmptyNotified = false,
  minimapShapeOverridden = false,
  originalGetMinimapShape = nil,
}

local C = C_Container

local function IsAddonLoadedCompat(addonName)
  if type(addonName) ~= "string" or addonName == "" then return false end
  if C_AddOns and C_AddOns.IsAddOnLoaded then
    return not not C_AddOns.IsAddOnLoaded(addonName)
  end
  if IsAddOnLoaded then
    return not not IsAddOnLoaded(addonName)
  end
  return false
end

local function GetBagNumSlots(bag)
  if C and C.GetContainerNumSlots then
    return C.GetContainerNumSlots(bag) or 0
  end
  if GetContainerNumSlots then
    return GetContainerNumSlots(bag) or 0
  end
  return 0
end
mod.Internal.Shared.IsAddonLoadedCompat = IsAddonLoadedCompat
mod.Internal.Shared.GetBagNumSlots = GetBagNumSlots

local function GetBagNumFreeSlots(bag)
  if C and C.GetContainerNumFreeSlots then
    local free = C.GetContainerNumFreeSlots(bag)
    return tonumber(free) or 0
  end
  if GetContainerNumFreeSlots then
    local free = select(1, GetContainerNumFreeSlots(bag))
    return tonumber(free) or 0
  end
  return 0
end
mod.Internal.Shared.GetBagNumFreeSlots = GetBagNumFreeSlots

local function RunSetPointGuard(lockKey, fn)
  if state[lockKey] then return end
  state[lockKey] = true
  local ok, err = pcall(fn)
  state[lockKey] = false
  if not ok and ETBC and ETBC.Debug then
    ETBC:Debug("MinimapPlus SetPoint hook error: " .. tostring(err))
  end
end

local function GetDB()
  ETBC.db.profile.minimapPlus = ETBC.db.profile.minimapPlus or {}
  local db = ETBC.db.profile.minimapPlus

  if db.enabled == nil then db.enabled = true end

  if db.minimap_icons == nil and db.minimapIcons ~= nil then db.minimap_icons = db.minimapIcons end
  if db.minimapIcons == nil and db.minimap_icons ~= nil then db.minimapIcons = db.minimap_icons end
  if db.minimap_icons == nil then db.minimap_icons = true end
  if db.minimapIcons == nil then db.minimapIcons = db.minimap_icons end

  if db.minimap_performance == nil and db.minimapPerformance ~= nil then
    db.minimap_performance = db.minimapPerformance
  end
  if db.minimapPerformance == nil and db.minimap_performance ~= nil then
    db.minimapPerformance = db.minimap_performance
  end
  if db.minimap_performance == nil then db.minimap_performance = false end
  if db.minimapPerformance == nil then db.minimapPerformance = db.minimap_performance end

  if db.square_mask == nil and db.squareMinimap ~= nil then db.square_mask = db.squareMinimap end
  if db.squareMinimap == nil and db.square_mask ~= nil then db.squareMinimap = db.square_mask end
  if db.square_mask == nil then db.square_mask = true end
  if db.squareMinimap == nil then db.squareMinimap = db.square_mask end

  if db.hideMinimapToggleButton == nil then db.hideMinimapToggleButton = true end
  if db.showTrackingState == nil then db.showTrackingState = true end
  if db.enableTrackingQuickToggle == nil then db.enableTrackingQuickToggle = false end

  if db.sink_addons == nil then
    if db.autoScan ~= nil then
      db.sink_addons = db.autoScan and true or false
    else
      db.sink_addons = true
    end
  end

  if db.sink_visible == nil and db.sinkEnabled ~= nil then db.sink_visible = db.sinkEnabled end
  if db.sinkEnabled == nil and db.sink_visible ~= nil then db.sinkEnabled = db.sink_visible end
  if db.sink_visible == nil then db.sink_visible = false end
  if db.sinkEnabled == nil then db.sinkEnabled = db.sink_visible end

  if db.sink_scan_interval == nil then
    if type(db.scanInterval) == "number" then
      db.sink_scan_interval = db.scanInterval
    else
      db.sink_scan_interval = 5
    end
  end
  db.scanInterval = db.sink_scan_interval

  db.sink_anchor = db.sink_anchor or {}
  if db.sink_anchor.point == nil and db.sinkPoint ~= nil then db.sink_anchor.point = db.sinkPoint end
  if db.sink_anchor.relPoint == nil and db.sinkRelPoint ~= nil then db.sink_anchor.relPoint = db.sinkRelPoint end
  if db.sink_anchor.x == nil and db.sinkX ~= nil then db.sink_anchor.x = db.sinkX end
  if db.sink_anchor.y == nil and db.sinkY ~= nil then db.sink_anchor.y = db.sinkY end

  if db.sink_moved == nil then
    db.sink_moved = (db.sink_anchor.x ~= nil or db.sink_anchor.y ~= nil)
  end

  if db.sink_anchor.point == nil then db.sink_anchor.point = "TOPRIGHT" end
  if db.sink_anchor.relPoint == nil then db.sink_anchor.relPoint = "TOPRIGHT" end
  if db.sink_anchor.x == nil then db.sink_anchor.x = -200 end
  if db.sink_anchor.y == nil then db.sink_anchor.y = -120 end

  db.sinkPoint = db.sink_anchor.point
  db.sinkRelPoint = db.sink_anchor.relPoint
  db.sinkX = db.sink_anchor.x
  db.sinkY = db.sink_anchor.y

  return db
end
mod.Internal.Shared.RunSetPointGuard = RunSetPointGuard

mod.Internal.Shared.state = state
mod.Internal.Shared.GetDB = GetDB
mod.Internal.Shared.TRACKING_NONE_TEXTURE = TRACKING_NONE_TEXTURE
mod.Internal.Shared.LDBIcon = LDBIcon
mod.Internal.Shared.SINK_ICON_SIZE = SINK_ICON_SIZE
mod.Internal.Shared.SINK_ICON_SPACING = SINK_ICON_SPACING
mod.Internal.Shared.SINK_PADDING = SINK_PADDING
mod.Internal.Shared.SINK_MIN_WIDTH = SINK_MIN_WIDTH
mod.Internal.Shared.SINK_MIN_HEIGHT = SINK_MIN_HEIGHT
mod.Internal.Shared.SINK_TRACKING_ROW_HEIGHT = SINK_TRACKING_ROW_HEIGHT
mod.Internal.Shared.ROUND_MASK_TEXTURE = ROUND_MASK_TEXTURE
mod.Internal.Shared.SQUARE_MASK_TEXTURE = SQUARE_MASK_TEXTURE
mod.Internal.Shared.RIGHT_MANAGED_FLAG = RIGHT_MANAGED_FLAG
mod.Internal.Shared.LFG_POINT_FLAG = LFG_POINT_FLAG
mod.Internal.Shared.CLOCK_POINT_FLAG = CLOCK_POINT_FLAG

local function IsFeatureEnabled()
  local db = GetDB()
  local generalEnabled = ETBC.db and ETBC.db.profile and ETBC.db.profile.general and ETBC.db.profile.general.enabled
  return (generalEnabled and db.enabled) and true or false
end

mod.Internal.Shared.IsFeatureEnabled = IsFeatureEnabled

local function ApplyMinimapShapeOverride(enabled)
  if enabled then
    if not state.minimapShapeOverridden then
      state.originalGetMinimapShape = _G.GetMinimapShape
      _G.GetMinimapShape = function()
        return "SQUARE"
      end
      state.minimapShapeOverridden = true
    end
    if LDBIcon and LDBIcon.SetButtonRadius then
      LDBIcon:SetButtonRadius(0)
    end
    return
  end

  if state.minimapShapeOverridden then
    _G.GetMinimapShape = state.originalGetMinimapShape
    state.originalGetMinimapShape = nil
    state.minimapShapeOverridden = false
  end
end

local function ApplyFont(fs, size)
  if ETBC.Theme and ETBC.Theme.ApplyFontString then
    ETBC.Theme:ApplyFontString(fs, nil, size)
    return
  end
  if fs and fs.SetFont then
    local path = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    pcall(fs.SetFont, fs, path, size or 10, "OUTLINE")
  end
end

mod.Internal.Shared.ApplyFont = ApplyFont

local function ApplyBackdrop(frame)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropBorderColor(0.04, 0.04, 0.04)
end

local function GetTrackingInternal()
  return mod.Internal and mod.Internal.Tracking
end

local function GetTrackingSnapshot()
  local H = GetTrackingInternal()
  if H and H.GetTrackingSnapshot then
    return H.GetTrackingSnapshot()
  end
  return {
    activeCount = 0,
    names = {},
    texture = TRACKING_NONE_TEXTURE,
  }
end

mod.Internal.Shared.GetTrackingSnapshot = GetTrackingSnapshot

local function TrackingWidget_OnEnter(self)
  local H = GetTrackingInternal()
  if H and H.TrackingWidget_OnEnter then
    H.TrackingWidget_OnEnter(self)
  end
end

local function TrackingWidget_OnLeave()
  local H = GetTrackingInternal()
  if H and H.TrackingWidget_OnLeave then
    H.TrackingWidget_OnLeave()
  end
end

local function TrackingWidget_OnClick()
  local H = GetTrackingInternal()
  if H and H.TrackingWidget_OnClick then
    H.TrackingWidget_OnClick()
  end
end

mod.Internal.Shared.TrackingWidget_OnEnter = TrackingWidget_OnEnter
mod.Internal.Shared.TrackingWidget_OnLeave = TrackingWidget_OnLeave
mod.Internal.Shared.TrackingWidget_OnClick = TrackingWidget_OnClick

local function IconsEnabled()
  local db = GetDB()
  return db.enabled and db.minimap_icons
end
mod.Internal.Shared.IconsEnabled = IconsEnabled

local function PerformanceEnabled()
  local db = GetDB()
  return db.enabled and db.minimap_performance
end
mod.Internal.Shared.PerformanceEnabled = PerformanceEnabled

local function GetTimersInternal()
  return mod.Internal and mod.Internal.Timers
end

local function StopTickers()
  local H = GetTimersInternal()
  if H and H.StopTickers then
    H.StopTickers()
    return
  end
end

local function AfterDelay(delay, fn)
  local H = GetTimersInternal()
  if H and H.AfterDelay then
    return H.AfterDelay(delay, fn)
  end
  fn()
  return true
end

mod.Internal.Shared.AfterDelay = AfterDelay

local function StartTickers()
  local H = GetTimersInternal()
  if H and H.StartTickers then
    H.StartTickers()
  end
end

local function GetSinkInternal()
  return mod.Internal and mod.Internal.Sink
end

local function ApplySinkAnchor()
  local H = GetSinkInternal()
  if H and H.ApplySinkAnchor then
    H.ApplySinkAnchor()
  end
end

mod.Internal.Shared.ApplySinkAnchor = ApplySinkAnchor

local function SetManagedButtonsShown(shown)
  local H = GetSinkInternal()
  if H and H.SetManagedButtonsShown then
    H.SetManagedButtonsShown(shown)
  end
end

local function GetEventsInternal()
  return mod.Internal and mod.Internal.Events
end

local function GetSinkButtonsInternal()
  return mod.Internal and mod.Internal.SinkButtons
end

local function GetSinkFrameInternal()
  return mod.Internal and mod.Internal.SinkFrame
end

local function GetSinkScanInternal()
  return mod.Internal and mod.Internal.SinkScan
end

local function GetPerformanceFrameInternal()
  return mod.Internal and mod.Internal.PerformanceFrame
end

local function GetIconsFrameInternal()
  return mod.Internal and mod.Internal.IconsFrame
end

local function GetBlizzardAdaptersInternal()
  return mod.Internal and mod.Internal.BlizzardAdapters
end

local function EnsureEventFrame()
  local H = GetEventsInternal()
  if H and H.EnsureEventFrame then
    H.EnsureEventFrame()
  end
end

function mod:StyleMinimap()
  local db = GetDB()
  if not MinimapCluster or not MinimapCluster.MinimapContainer or not Minimap then return end

  local extraTop = db.minimap_icons and 20 or 0
  MinimapCluster:SetSize(MINIMAP_SIZE, 185 + extraTop)
  MinimapCluster.MinimapContainer:SetSize(MINIMAP_SIZE, MINIMAP_SIZE)
  Minimap:SetSize(MinimapCluster.MinimapContainer:GetSize())

  MinimapCluster.MinimapContainer:ClearAllPoints()
  MinimapCluster.MinimapContainer:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5, MINIMAP_CONTAINER_FLAG)

  if not state.containerHooked then
    hooksecurefunc(MinimapCluster.MinimapContainer, "SetPoint", function(frame, _, _, _, _, _, flag)
      if not IsFeatureEnabled() then return end
      if flag == MINIMAP_CONTAINER_FLAG then return end
      RunSetPointGuard("inContainerHook", function()
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", MinimapCluster, "BOTTOM", -1, 1.5, MINIMAP_CONTAINER_FLAG)
      end)
    end)
    state.containerHooked = true
  end

  local zoom = Minimap:GetZoom()
  Minimap:SetZoom(zoom == 0 and 1 or 0)
  Minimap:SetZoom(zoom)

  if not Minimap.backdrop then
    Minimap.backdrop = CreateFrame("Frame", nil, Minimap, "BackdropTemplate")
    Minimap.backdrop:SetPoint("BOTTOMLEFT", Minimap, "BOTTOMLEFT", -1, -1)
    Minimap.backdrop:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", 1, 1)
    ApplyBackdrop(Minimap.backdrop)
  end

  if MinimapBackdrop then
    MinimapBackdrop:SetSize(Minimap:GetSize())
    MinimapBackdrop:SetPoint("TOP", 0, 0)
  end
  if MinimapBorder then MinimapBorder:Hide() end
  if MinimapCluster.BorderTop then MinimapCluster.BorderTop:Hide() end

  if MinimapToggleButton then
    if db.hideMinimapToggleButton then
      if not state.toggleButtonShow then
        state.toggleButtonShow = MinimapToggleButton.Show
      end
      MinimapToggleButton:Hide()
      MinimapToggleButton.Show = function() end
    elseif state.toggleButtonShow then
      MinimapToggleButton.Show = state.toggleButtonShow
      MinimapToggleButton:Show()
    end
  end

  if MinimapZoneTextButton then
    MinimapZoneTextButton:SetSize(110, 20)
    MinimapZoneTextButton:ClearAllPoints()
    MinimapZoneTextButton:SetPoint("TOP", Minimap, "TOP", 0, db.minimap_icons and 42 or 22, ZONE_TEXT_POINT_FLAG)
    if not state.zoneTextPointHooked then
      hooksecurefunc(MinimapZoneTextButton, "SetPoint", function(frame, _, _, _, _, _, flag)
        if flag == ZONE_TEXT_POINT_FLAG then return end
        if not IsFeatureEnabled() then return end
        local rowOffset = (GetDB().minimap_icons and 42) or 22
        RunSetPointGuard("inZoneTextPointHook", function()
          frame:ClearAllPoints()
          frame:SetPoint("TOP", Minimap, "TOP", 0, rowOffset, ZONE_TEXT_POINT_FLAG)
        end)
      end)
      state.zoneTextPointHooked = true
    end
  end

  if MinimapZoneText then
    MinimapZoneText:SetParent(Minimap)
    MinimapZoneText:SetWidth(110)
    MinimapZoneText:ClearAllPoints()
    MinimapZoneText:SetPoint("CENTER", MinimapZoneTextButton, "CENTER", 0, 0)
    MinimapZoneText:SetJustifyH("CENTER")
    ApplyFont(MinimapZoneText, 12)
  end

  if MinimapNorthTag then
    MinimapNorthTag:SetPoint("TOP", Minimap, "TOP", 0, -5)
  end

  if GameTimeFrame and GameTimeTexture then
    if GameTimeFrame.EnableMouse then
      GameTimeFrame:EnableMouse(false)
    end
    if GameTimeFrame.SetAlpha then
      GameTimeFrame:SetAlpha(0)
    end
    GameTimeTexture:Hide()
    if GameTimeFrame.texture and GameTimeFrame.texture.Hide then
      GameTimeFrame.texture:Hide()
    end
    GameTimeFrame:Hide()
    if not state.gameTimeShowHooked then
      hooksecurefunc(GameTimeFrame, "Show", function(frame)
        if not IsFeatureEnabled() then return end
        RunSetPointGuard("inGameTimeShowHook", function()
          if frame.EnableMouse then
            frame:EnableMouse(false)
          end
          if frame.SetAlpha then
            frame:SetAlpha(0)
          end
          if GameTimeTexture and GameTimeTexture.Hide then
            GameTimeTexture:Hide()
          end
          if frame.texture and frame.texture.Hide then
            frame.texture:Hide()
          end
          frame:Hide()
        end)
      end)
      state.gameTimeShowHooked = true
    end
  elseif GameTimeFrame then
    if GameTimeFrame.EnableMouse then
      GameTimeFrame:EnableMouse(false)
    end
    if GameTimeFrame.SetAlpha then
      GameTimeFrame:SetAlpha(0)
    end
    if GameTimeFrame.texture and GameTimeFrame.texture.Hide then
      GameTimeFrame.texture:Hide()
    end
    GameTimeFrame:Hide()
    if not state.gameTimeShowHooked then
      hooksecurefunc(GameTimeFrame, "Show", function(frame)
        if not IsFeatureEnabled() then return end
        RunSetPointGuard("inGameTimeShowHook", function()
          if frame.EnableMouse then
            frame:EnableMouse(false)
          end
          if frame.SetAlpha then
            frame:SetAlpha(0)
          end
          if frame.texture and frame.texture.Hide then
            frame.texture:Hide()
          end
          frame:Hide()
        end)
      end)
      state.gameTimeShowHooked = true
    end
  end

  if MiniMapMailFrame then MiniMapMailFrame:SetPoint("TOPRIGHT", 0, -40) end
  if MinimapZoomIn then
    MinimapZoomIn:SetScale(0.7)
    MinimapZoomIn:SetPoint("BOTTOMRIGHT", -2, 67)
  end
  if MinimapZoomOut then
    MinimapZoomOut:SetScale(0.7)
    MinimapZoomOut:SetPoint("BOTTOMRIGHT", -2, 37)
  end
  if MiniMapTracking then
    MiniMapTracking:SetScale(0.8)
    MiniMapTracking:ClearAllPoints()
    MiniMapTracking:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -45, TRACKING_POINT_FLAG)
    if not state.trackingPointHooked then
      hooksecurefunc(MiniMapTracking, "SetPoint", function(frame, _, _, _, _, _, flag)
        if flag == TRACKING_POINT_FLAG then return end
        RunSetPointGuard("inTrackingHook", function()
          frame:ClearAllPoints()
          frame:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 2, -45, TRACKING_POINT_FLAG)
        end)
      end)
      state.trackingPointHooked = true
    end
  end
  if MiniMapBattlefieldFrame then
    MiniMapBattlefieldFrame:SetScale(0.9)
    MiniMapBattlefieldFrame:ClearAllPoints()
    MiniMapBattlefieldFrame:SetPoint("BOTTOMLEFT", 2, 50)
  end

  self:CreatePerformanceFrame()
  self:CreateIconsFrame()
  self:EnsureSinkFrame()
  EnsureEventFrame()

  ApplyMinimapShapeOverride(db.square_mask and IsFeatureEnabled())

  state.styled = true
end

function mod.CreatePerformanceFrame()
  local H = GetPerformanceFrameInternal()
  if H and H.CreatePerformanceFrame then
    H.CreatePerformanceFrame()
  end
end

function mod.CreateIconsFrame()
  local H = GetIconsFrameInternal()
  if H and H.CreateIconsFrame then
    H.CreateIconsFrame()
  end
end

function mod.EnsureSinkFrame()
  local H = GetSinkFrameInternal()
  if H and H.EnsureSinkFrame then
    H.EnsureSinkFrame()
  end
end

function mod.IsBlacklisted(self, btn, name)
  local H = GetSinkButtonsInternal()
  if H and H.IsBlacklisted then
    return H.IsBlacklisted(self, btn, name)
  end
  return true
end

function mod:LooksLikeMinimapButton(btn)
  local H = GetSinkButtonsInternal()
  if H and H.LooksLikeMinimapButton then
    return H.LooksLikeMinimapButton(self, btn)
  end
  return false
end

function mod.CaptureSinkButton(self, btn)
  local H = GetSinkButtonsInternal()
  if H and H.CaptureSinkButton then
    H.CaptureSinkButton(self, btn)
  end
end

function mod.RestoreSinkButtons()
  local H = GetSinkButtonsInternal()
  if H and H.RestoreSinkButtons then
    H.RestoreSinkButtons()
  end
end

function mod.LayoutSinkButtons()
  local H = GetSinkButtonsInternal()
  if H and H.LayoutSinkButtons then
    H.LayoutSinkButtons()
  end
end

function mod:ScanForAddonButtons(fullScan)
  local H = GetSinkScanInternal()
  if H and H.ScanForAddonButtons then
    H.ScanForAddonButtons(self, fullScan)
  end
end

function mod.ApplyWidgetVisibility()
  local db = GetDB()
  local enabled = IsFeatureEnabled()

  if state.performanceFrame then
    state.performanceFrame:SetShown(enabled and db.minimap_performance)
  end
  if state.iconsFrame then
    state.iconsFrame:SetShown(enabled and db.minimap_icons)
    state.iconsFrame:ClearAllPoints()
    state.iconsFrame:SetPoint("TOP", 0, 22)
  end
  if state.sinkFrame then
    state.sinkFrame:SetShown(enabled and db.sink_addons and db.sink_visible)
    if state.sinkDragHandle then
      state.sinkDragHandle:SetShown(enabled and db.sink_addons and db.sink_visible)
    end
    ApplySinkAnchor()
  end
end

function mod.StyleTimeManagerClockButton()
  local H = GetBlizzardAdaptersInternal()
  if H and H.StyleTimeManagerClockButton then
    H.StyleTimeManagerClockButton()
  end
end

function mod.MoveMinimapLFGButton()
  local H = GetBlizzardAdaptersInternal()
  if H and H.MoveMinimapLFGButton then
    H.MoveMinimapLFGButton()
  end
end

function mod.StyleBattlefieldMinimap()
  local H = GetBlizzardAdaptersInternal()
  if H and H.StyleBattlefieldMinimap then
    H.StyleBattlefieldMinimap()
  end
end

function mod.MoveQuestWatchFrame()
  local H = GetBlizzardAdaptersInternal()
  if H and H.MoveQuestWatchFrame then
    H.MoveQuestWatchFrame()
  end
end

function mod.UpdateMinimapMask()
  local H = GetBlizzardAdaptersInternal()
  if H and H.UpdateMinimapMask then
    H.UpdateMinimapMask()
  end
end

function mod:Apply()
  local db = GetDB()
  local enabled = IsFeatureEnabled()

  if not enabled then
    ApplyMinimapShapeOverride(false)
    StopTickers()
    self:RestoreSinkButtons()
    self:ApplyWidgetVisibility()
    self:UpdateMinimapMask()

    if MinimapToggleButton and state.toggleButtonShow then
      MinimapToggleButton.Show = state.toggleButtonShow
      MinimapToggleButton:Show()
    end
    return
  end

  self:StyleMinimap()
  ApplyMinimapShapeOverride(db.square_mask)

  self:CreatePerformanceFrame()
  self:CreateIconsFrame()
  self:EnsureSinkFrame()
  EnsureEventFrame()

  if state.iconsFrame then
    state.iconsFrame:updateFriendsDisplay()
    state.iconsFrame:updateGuildDisplay()
    state.iconsFrame:updateDurabilityDisplay()
    state.iconsFrame:updateInventoryDisplay()
    if state.iconsFrame.updateTrackingDisplay then
      state.iconsFrame:updateTrackingDisplay()
    end
  end

  if db.sink_addons and db.sink_visible then
    self:ScanForAddonButtons(true)
    SetManagedButtonsShown(true)
  elseif db.sink_addons then
    SetManagedButtonsShown(false)
  else
    self:RestoreSinkButtons()
  end
  if state.sinkFrame and state.sinkFrame.updateTrackingDisplay then
    state.sinkFrame:updateTrackingDisplay()
  end

  if state.performanceFrame then
    state.performanceFrame:updateMsDisplay()
    state.performanceFrame:updateFpsDisplay()
  end

  self:StyleTimeManagerClockButton()
  self:MoveMinimapLFGButton()
  self:MoveQuestWatchFrame()
  self:StyleBattlefieldMinimap()

  self:ApplyWidgetVisibility()
  self:UpdateMinimapMask()
  StartTickers()
end

function mod:ToggleSinkVisibility()
  local db = GetDB()
  if not db.sink_addons then db.sink_addons = true end

  db.sink_visible = not db.sink_visible
  db.sinkEnabled = db.sink_visible

  if db.sink_visible then
    self:ScanForAddonButtons(true)
    SetManagedButtonsShown(true)
  else
    SetManagedButtonsShown(false)
  end
  self:Apply()
end

function mod.IsSinkShown()
  if state.sinkFrame and state.sinkFrame.IsShown then
    return state.sinkFrame:IsShown()
  end
  return false
end

if ETBC.ApplyBus and ETBC.ApplyBus.Register then
  ETBC.ApplyBus:Register("minimapplus", function()
    mod:Apply()
  end)

  ETBC.ApplyBus:Register("general", function()
    mod:Apply()
  end)
end
